import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import '../../../core/utils/chinese_script_converter.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../services/reader_charset_service.dart';
import '../widgets/auto_pager.dart';
import '../widgets/page_factory.dart';
import '../services/reader_content_processor.dart';
import '../utils/chapter_progress_utils.dart';
import 'actions_coordinator.dart';
import 'image_coordinator.dart';
import 'input_coordinator.dart';
import 'reader_bookmark_controller.dart';
import 'scroll_coordinator.dart';
import 'source_switch_coordinator.dart';
import 'reader_read_aloud_controller.dart';
import 'reader_settings_controller.dart';
import 'reader_state.dart';

/// 阅读器逻辑委托。
///
/// 接收 UI 事件 → 操作状态分组（ChangeNotifier）→ UI 自动刷新。
/// 不持有任何 Widget/BuildContext 引用。需要 UI 操作时通过
/// [postFrameCallback] 回调。
class ReaderCoordinator {
  ReaderCoordinator({
    required this.bookId,
    required this.bookTitle,
    required this.isEphemeral,
    required this.chapter,
    required this.ui,
    required this.settings,
    required this.scroll,
    required this.paged,
    required this.image,
    required this.settingsCtrl,
    required this.readAloudCtrl,
    required this.bookmarkCtrl,
    required this.postFrameCallback,
    this.getPagedContentSize,
  });

  final String bookId;
  final String bookTitle;
  final bool isEphemeral;

  // ── 数据仓库 ──
  final ChapterState chapter;
  final UiState ui;
  final SettingsState settings;
  final ScrollModeState scroll;
  final PagedModeState paged;
  final ImageCacheState image;

  // ── 子 Controller ──
  final ReaderSettingsController settingsCtrl;
  final ReaderReadAloudController readAloudCtrl;

  /// View 层使用的公开别名。
  ReaderReadAloudController get readAloudController => readAloudCtrl;
  final ReaderBookmarkController bookmarkCtrl;

  /// 安全地在下一帧执行 UI 操作（替代 WidgetsBinding.addPostFrameCallback）
  final void Function(VoidCallback callback) postFrameCallback;

  /// 由 View 层提供，返回分页模式内容区域的实际尺寸。
  /// 如果为 null 则使用默认尺寸估算。
  final Size? Function()? getPagedContentSize;

  // ── Services ──
  late final ChapterRepository _chapterRepo;
  late final BookRepository _bookRepo;

  /// 公开 BookRepository 以供 View 层导航使用。
  BookRepository get bookRepo => _bookRepo;
  late final SourceRepository _sourceRepo;
  late final SettingsService _settingsService;
  late final WebDavService _webDavService;
  late final BookshelfCatalogUpdateService _catalogUpdateService;
  final RuleParserEngine _ruleEngine = RuleParserEngine();
  final ChineseScriptConverter _chineseConverter =
      ChineseScriptConverter.instance;

  // ── 子 Coordinator ──
  late final ActionsCoordinator actionsCoordinator;
  late final InputCoordinator inputCoordinator;
  late final ImageCoordinator imageCoordinator;
  SourceSwitchCoordinator? sourceSwitchCoordinator;
  late final ScrollCoordinator scrollCoordinator;

  // ═══════════════════════════════════════════════════════════════════
  // 初始化
  // ═══════════════════════════════════════════════════════════════════

  Future<void> init({
    required int initialChapter,
    List<Chapter>? initialChapters,
    String? sourceUrl,
    String? sourceName,
    String? bookAuthor,
    String? bookCoverUrl,
  }) async {
    _initServices();
    _initSubCoordinators();
    _initAutoPager();

    // 初始化设置
    final rawSettings = _settingsService.readingSettings;
    settings.update(settingsCtrl.readSettingsWithExclusions(rawSettings));

    // 加载章节
    if (initialChapters != null && initialChapters.isNotEmpty) {
      chapter.chapters = initialChapters.toList(growable: false)
        ..sort((a, b) => a.index.compareTo(b.index));
    } else {
      chapter.chapters = _chapterRepo.getChaptersForBook(bookId);
    }

    // 初始化书籍信息
    final book = _bookRepo.getBookById(bookId);
    image.sourceUrl = sourceUrl ?? book?.sourceUrl ?? book?.sourceId;
    image.sourceName = sourceName;
    image.bookAuthor = bookAuthor ?? book?.author ?? '';
    image.bookCoverUrl = bookCoverUrl ?? book?.coverUrl;

    // 恢复图片尺寸快照
    unawaited(imageCoordinator.restoreImageSizeSnapshot());

    // 加载初始章节
    chapter.currentIndex = initialChapter.clamp(0, chapter.maxIndex);
    try {
      if (chapter.chapters.isNotEmpty) {
        await loadChapter(chapter.currentIndex, restoreOffset: true);
      }
    } catch (e) {
      debugPrint('[coordinator] init loadChapter error: $e');
    } finally {
      // 无论成功失败，都要解除 UI 加载门控，避免界面永远停在 spinner。
      chapter.update(initialized: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 初始化工厂方法
  // ═══════════════════════════════════════════════════════════════════

  void _initServices() {
    final db = DatabaseService();
    _chapterRepo = ChapterRepository(db);
    _bookRepo = BookRepository(db);
    _sourceRepo = SourceRepository(db);
    _settingsService = SettingsService();
    _webDavService = WebDavService();
    _catalogUpdateService = BookshelfCatalogUpdateService(
      engine: _ruleEngine,
      sourceRepo: _sourceRepo,
      bookRepo: _bookRepo,
      chapterRepo: _chapterRepo,
    );
  }

  void _initSubCoordinators() {
    actionsCoordinator = ActionsCoordinator(
      bookId: bookId,
      bookTitle: bookTitle,
      isEphemeral: isEphemeral,
      chapter: chapter,
      settings: settings,
      image: image,
      bookRepo: _bookRepo,
      chapterRepo: _chapterRepo,
      sourceRepo: _sourceRepo,
      settingsService: _settingsService,
      webDavService: _webDavService,
      charsetService: ReaderCharsetService(),
      catalogUpdateService: _catalogUpdateService,
      ruleEngine: _ruleEngine,
      onLoadChapter: (index, {
        bool restoreOffset = false,
        double? targetChapterProgress,
      }) =>
          loadChapter(
            index,
            restoreOffset: restoreOffset,
            targetChapterProgress: targetChapterProgress,
          ),
      onShowToast: ui.showToast,
      getChapterProgress: getChapterProgress,
      getBookProgress: getBookProgress,
    );

    scrollCoordinator = ScrollCoordinator(
      scroll: scroll,
      chapter: chapter,
      settings: settings,
      buildSegment: _buildScrollSegment,
      onChapterChanged: () =>
          bookmarkCtrl.updateStatus(chapter.currentIndex),
      onSaveProgress: _saveProgress,
      getBookProgress: getBookProgress,
      getCurrentTime: getCurrentTime,
    );

    inputCoordinator = InputCoordinator(
      chapter: chapter,
      ui: ui,
      settings: settings,
      paged: paged,
      scroll: scroll,
      onToggleMenu: toggleMenu,
      onShowAutoReadPanel: () => ui.toggleAutoReadPanel(true),
      onNextChapter: nextChapter,
      onPreviousChapter: previousChapter,
      onScrollPage: ({required bool up}) =>
          scrollCoordinator.scrollPage(up: up),
      onShowToast: ui.showToast,
      onAddBookmark: () {
        unawaited(bookmarkCtrl.addAtCurrentPosition(
          bookAuthor: image.bookAuthor,
          chapterIndex: chapter.currentIndex,
          chapterTitle: chapter.currentTitle,
          chapterProgress: getChapterProgress(),
          currentContent: chapter.currentContent,
        ));
      },
      onShowChapterList: () => ui.toggleMenu(false),
      onSearchContent: () {
        ui.toggleMenu(false);
        ui.toggleSearchMenu(true);
      },
      onEditContent: () => ui.toggleMenu(false),
      onToggleReplaceRule: () =>
          unawaited(actionsCoordinator.toggleReplaceRule()),
      onSyncProgress: () =>
          unawaited(actionsCoordinator.pullProgressFromWebDav()),
      onReadAloudPrev: () =>
          unawaited(readAloudCtrl.previousParagraph()),
      onReadAloudNext: () =>
          unawaited(readAloudCtrl.nextParagraph()),
      onReadAloudToggle: () =>
          unawaited(readAloudCtrl.togglePauseResume()),
      onScreenOffTimerStart: () =>
          settingsCtrl.screenOffTimerStart(settings.settings),
      isAutoPagerRunning: () => ui.autoPager.isRunning,
      clickActions: ClickAction.defaultZoneConfig,
    );

    imageCoordinator = ImageCoordinator(
      bookId: bookId,
      isEphemeral: isEphemeral,
      image: image,
      settingsService: _settingsService,
      ruleEngine: _ruleEngine,
      resolveCurrentSource: () {
        final url = (image.sourceUrl ?? '').trim();
        if (url.isEmpty) return null;
        return _sourceRepo.getSourceByUrl(url);
      },
      recentFetchDuration: () => chapter.recentFetchDuration,
    );

    if (!isEphemeral) {
      sourceSwitchCoordinator = SourceSwitchCoordinator(
        bookId: bookId,
        chapter: chapter,
        image: image,
        sourceRepo: _sourceRepo,
        ruleEngine: _ruleEngine,
        settingsService: _settingsService,
        onSourceSwitched: (newSourceUrl) async {
          chapter.chapters =
              _chapterRepo.getChaptersForBook(bookId);
          chapter.notify();
        },
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 章节加载
  // ═══════════════════════════════════════════════════════════════════

  /// 加载指定章节。核心流程，从旧 _loadChapter 迁移。
  Future<void> loadChapter(
    int index, {
    bool restoreOffset = false,
    bool goToLastPage = false,
    double? targetChapterProgress,
  }) async {
    final count = chapter.readableCount;
    if (index < 0 || index >= count) return;
    final clamped = index.clamp(0, count - 1);

    chapter.update(loading: true);

    try {
      final ch = chapter.chapters[clamped];
      final content = await _fetchContent(ch);
      final processed = _processChapterContent(
        chapterId: ch.id,
        rawTitle: ch.title,
        rawContent: content,
      );

      // 更新章节状态 → ChapterState.notifyListeners → UI 刷新
      chapter.update(
        index: clamped,
        title: processed.title,
        content: processed.content,
        loading: false,
      );

      // 同步子系统
      readAloudCtrl.syncChapterContext(
        chapterIndex: clamped,
        chapterTitle: processed.title,
        content: processed.content,
      );
      bookmarkCtrl.updateStatus(clamped);

      // 根据翻页模式触发后续渲染
      if (settings.settings.pageTurnMode == PageTurnMode.scroll) {
        // 滚动模式：构建 segments 窗口
        unawaited(scrollCoordinator.initializeSegments(
          centerIndex: clamped,
          restoreOffset: restoreOffset,
          goToLastPage: goToLastPage,
          targetChapterProgress: targetChapterProgress,
        ));
      } else {
        // 分页模式：下一帧执行分页
        postFrameCallback(() {
          _paginateAndJump(
            chapterIndex: clamped,
            goToLastPage: goToLastPage,
            restoreOffset: restoreOffset,
            targetProgress: targetChapterProgress,
          );
        });
      }

      // 异步预取邻近章节
      unawaited(_prefetchNeighbors(clamped));

      // 保存进度
      if (!isEphemeral && !restoreOffset) {
        unawaited(_saveProgress());
      }
    } catch (e) {
      chapter.update(loading: false);
      debugPrint('[coordinator] loadChapter error: $e');
    }
  }

  void nextChapter() {
    if (chapter.currentIndex < chapter.maxIndex) {
      unawaited(loadChapter(chapter.currentIndex + 1));
    }
  }

  void previousChapter() {
    if (chapter.currentIndex > 0) {
      unawaited(loadChapter(chapter.currentIndex - 1, goToLastPage: true));
    }
  }

  /// 由 ReaderView 在 PagedReaderWidget 首次 mount + layout 后主动调用，
  /// 触发首屏分页，避免 init 流程中 postFrameCallback 与 widget mount 之间的
  /// 时序竞速导致首次进入空白。
  void requestRepaginate({bool restoreOffset = true}) {
    if (chapter.chapters.isEmpty) return;
    if (settings.settings.pageTurnMode == PageTurnMode.scroll) {
      unawaited(scrollCoordinator.initializeSegments(
        centerIndex: chapter.currentIndex,
        restoreOffset: restoreOffset,
      ));
    } else {
      _paginateAndJump(
        chapterIndex: chapter.currentIndex,
        goToLastPage: false,
        restoreOffset: restoreOffset,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 内容处理
  // ═══════════════════════════════════════════════════════════════════

  ({String title, String content}) _processChapterContent({
    required String chapterId,
    required String rawTitle,
    required String rawContent,
  }) {
    var title = _convertChinese(rawTitle);
    var content = rawContent;

    if (settings.settings.cleanChapterTitle) {
      content = ReaderContentProcessor.removeDuplicateTitle(content, title)
          .content;
    }
    if (settings.delRubyTag) {
      content = ReaderContentProcessor.removeRubyTags(content);
    }
    if (settings.delHTag) {
      content = ReaderContentProcessor.removeHtmlHeaderTags(content);
    }
    content = _convertChinese(content);
    content = ReaderContentProcessor.formatContentLikeLegado(content);

    return (title: title, content: content);
  }

  String _convertChinese(String text) {
    switch (settings.settings.chineseConverterType) {
      case ChineseConverterType.traditionalToSimplified:
        return _chineseConverter.traditionalToSimplified(text);
      case ChineseConverterType.simplifiedToTraditional:
        return _chineseConverter.simplifiedToTraditional(text);
      default:
        return text;
    }
  }

  Future<String> _fetchContent(Chapter ch) async {
    final existing = ch.content;
    if (existing != null && existing.isNotEmpty) return existing;

    final url = (ch.url ?? '').trim();
    if (url.isEmpty) return '';

    final sourceUrl = image.sourceUrl ?? '';
    if (sourceUrl.isEmpty) return '';

    try {
      final source = _sourceRepo.getSourceByUrl(sourceUrl);
      if (source == null) return '';
      final content = await _ruleEngine.getContent(source, url);
      return content;
    } catch (e) {
      debugPrint('[coordinator] fetchContent error: $e');
      return '';
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 分页
  // ═══════════════════════════════════════════════════════════════════

  void _paginateAndJump({
    required int chapterIndex,
    required bool goToLastPage,
    required bool restoreOffset,
    double? targetProgress,
  }) {
    // 设置布局参数（依赖 PagedReaderWidget 已 mount + layout）。
    // 如 RenderBox 尚未就绪（首次进入阅读器时 chapter.update(initialized=true)
    // 与 postFrameCallback 触发时序竞速），延迟一帧重试，避免分页用 fallback
    // 尺寸算出的页数与最终布局不一致。
    final contentSize = getPagedContentSize?.call();
    if (contentSize == null) {
      postFrameCallback(() {
        _paginateAndJump(
          chapterIndex: chapterIndex,
          goToLastPage: goToLastPage,
          restoreOffset: restoreOffset,
          targetProgress: targetProgress,
        );
      });
      return;
    }

    // 构建 ChapterData 并注入 PageFactory。
    // 当前章节优先使用 chapter.currentContent（已经过处理的内容），
    // 避免 Chapter.content 尚未回写时出现空白页。
    final chapterDataList = List.generate(chapter.chapters.length, (i) {
      final ch = chapter.chapters[i];
      final content = (i == chapterIndex)
          ? chapter.currentContent        // 当前章：用处理后内容
          : (ch.content ?? '');           // 邻章：用缓存内容（或空）
      return ChapterData(title: ch.title, content: content);
    });
    paged.pageFactory.setChapters(chapterDataList, chapterIndex);

    final s = settings.settings;
    final contentW = contentSize.width - s.paddingLeft - s.paddingRight;
    final contentH = contentSize.height - s.paddingTop - s.paddingBottom;
    if (contentW > 50 && contentH > 100) {
      paged.pageFactory.setLayoutParams(
        contentHeight: contentH,
        contentWidth: contentW,
        fontSize: s.fontSize,
        lineHeight: s.lineHeight,
        letterSpacing: s.letterSpacing,
        paragraphSpacing: s.paragraphSpacing,
        fontFamily: settings.customFontFamily,
        paragraphIndent: s.paragraphIndent,
        underline: s.underline,
        showTitle: s.titleMode != 2,
        legacyImageStyle: settings.imageStyle,
      );
    }

    // 触发分页
    paged.pageFactory.paginateAll();
    paged.pageFactory.jumpToChapter(chapterIndex, goToLastPage: goToLastPage);

    if ((restoreOffset || targetProgress != null) && !goToLastPage) {
      final progress = targetProgress ??
          _settingsService.getChapterPageProgress(
            bookId,
            chapterIndex: chapterIndex,
          );
      final total = paged.pageFactory.totalPages;
      if (total > 0) {
        final target = ChapterProgressUtils.pageIndexFromProgress(
          progress: progress,
          totalPages: total,
        );
        if (target != paged.pageFactory.currentPageIndex) {
          paged.pageFactory.jumpToPage(target);
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 设置
  // ═══════════════════════════════════════════════════════════════════

  void updateSettings(ReadingSettings newSettings, {bool persist = true}) {
    final old = settings.settings;
    final normalized = settingsCtrl.readSettingsWithExclusions(newSettings);
    settings.update(normalized);
    unawaited(settingsCtrl.syncBrightness(old, normalized));
    if (persist) {
      unawaited(_settingsService.saveReadingSettings(normalized));
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 菜单
  // ═══════════════════════════════════════════════════════════════════

  void toggleMenu() => ui.toggleMenu(!ui.showMenu);
  void closeMenu() {
    if (ui.showMenu) ui.toggleMenu(false);
    if (ui.showSearchMenu) ui.toggleSearchMenu(false);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 进度
  // ═══════════════════════════════════════════════════════════════════

  double getChapterProgress() {
    if (settings.settings.pageTurnMode != PageTurnMode.scroll) {
      return ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: paged.pageFactory.currentPageIndex,
        totalPages: paged.pageFactory.totalPages,
      );
    }
    return scroll.currentChapterProgress;
  }

  double getBookProgress() {
    final total = chapter.readableCount;
    if (total <= 0) return 0;
    return ((chapter.currentIndex + getChapterProgress()) / total)
        .clamp(0.0, 1.0);
  }

  String getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════
  // 内部
  // ═══════════════════════════════════════════════════════════════════

  Future<ScrollSegment> _buildScrollSegment(
    int chapterIndex, {
    bool showLoading = false,
  }) async {
    final count = chapter.readableCount;
    if (chapterIndex < 0 || chapterIndex >= count) {
      return ScrollSegment(
        chapterIndex: chapterIndex,
        chapterId: '',
        title: '',
        content: '',
        estimatedHeight: 100,
      );
    }
    final ch = chapter.chapters[chapterIndex];
    final rawContent = await _fetchContent(ch);
    final processed = _processChapterContent(
      chapterId: ch.id,
      rawTitle: ch.title,
      rawContent: rawContent,
    );

    // 粗略估算高度：每行约 20px，每行约 30 个字符
    final lineCount = processed.content.length / 30;
    final estimated = (lineCount * 20).clamp(100.0, 50000.0);

    return ScrollSegment(
      chapterIndex: chapterIndex,
      chapterId: ch.id,
      title: processed.title,
      content: processed.content,
      estimatedHeight: estimated,
    );
  }

  Future<void> _prefetchNeighbors(int centerIndex) async {
    // 预取前后各一章
    for (final offset in [-1, 1]) {
      final idx = centerIndex + offset;
      if (idx < 0 || idx >= chapter.readableCount) continue;
      final ch = chapter.chapters[idx];
      if (ch.content != null && ch.content!.isNotEmpty) continue;
      try {
        await _fetchContent(ch);
      } catch (_) {}
    }
  }

  Future<void> _saveProgress() async {
    try {
      await _bookRepo.updateReadProgress(
        bookId,
        currentChapter: chapter.currentIndex,
        readProgress: getChapterProgress(),
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════
  // 自动翻页
  // ═══════════════════════════════════════════════════════════════════

  void _initAutoPager() {
    final autoPager = ui.autoPager;
    autoPager.setScrollController(scroll.controller);
    autoPager.setOnNextPage(() {
      inputCoordinator.handleAutoPagerTick(
        hasNextChapter: chapter.currentIndex < chapter.maxIndex,
        onStopAtBoundary: _stopAutoPagerAtBoundary,
      );
    });
    final isScroll =
        settings.settings.pageTurnMode == PageTurnMode.scroll;
    autoPager.setMode(
      isScroll ? AutoPagerMode.scroll : AutoPagerMode.page,
    );
    autoPager.setSpeed(settings.settings.autoReadSpeed);
  }

  /// 切换自动翻页开/关。
  Future<void> toggleAutoPage() async {
    final autoPager = ui.autoPager;
    if (!autoPager.isRunning && !autoPager.isPaused) {
      if (readAloudCtrl.snapshot.isRunning) {
        await readAloudCtrl.stop();
      }
      autoPager.start();
      ui.toggleAutoReadPanel(true);
      return;
    }
    ui.autoPagerPausedByMenu = false;
    autoPager.stop();
    if (ui.showAutoReadPanel) {
      ui.toggleAutoReadPanel(false);
    }
  }

  void _stopAutoPagerAtBoundary() {
    ui.autoPager.stop();
    if (ui.showAutoReadPanel) {
      ui.toggleAutoReadPanel(false);
    }
  }

  void dispose() {
    sourceSwitchCoordinator?.dispose();
    ui.autoPager.dispose();
    imageCoordinator.dispose();
    settingsCtrl.dispose();
    readAloudCtrl.dispose();
    bookmarkCtrl.dispose();
    scroll.dispose();
  }
}
