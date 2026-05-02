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
import '../utils/chapter_progress_utils.dart';
import '../widgets/auto_pager.dart';
import 'actions_coordinator.dart';
import 'image_coordinator.dart';
import 'input_coordinator.dart';
import 'reader_bookmark_controller.dart';
import 'reader_coordinator_helpers.dart';
import 'reader_sub_coordinator_builder.dart';
import 'scroll_coordinator.dart';
import 'source_switch_coordinator.dart';
import 'reader_read_aloud_controller.dart';
import 'reader_settings_controller.dart';
import 'reader_state.dart';

/// 阅读器逻辑委托。接收 UI 事件 → 操作状态分组（ChangeNotifier）→ UI 自动刷新。
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

  final void Function(VoidCallback callback) postFrameCallback;

  /// 由 View 层提供，返回分页模式内容区域的实际尺寸。
  final Size? Function()? getPagedContentSize;

  // ── Services ──
  late final ChapterRepository _chapterRepo;
  late final BookRepository _bookRepo;
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
    final bundle = buildReaderSubCoordinators(
      bookId: bookId,
      bookTitle: bookTitle,
      isEphemeral: isEphemeral,
      chapter: chapter,
      ui: ui,
      settings: settings,
      scroll: scroll,
      paged: paged,
      image: image,
      readAloudCtrl: readAloudCtrl,
      bookmarkCtrl: bookmarkCtrl,
      settingsCtrl: settingsCtrl,
      bookRepo: _bookRepo,
      chapterRepo: _chapterRepo,
      sourceRepo: _sourceRepo,
      settingsService: _settingsService,
      webDavService: _webDavService,
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
      onToggleMenu: toggleMenu,
      onNextChapter: nextChapter,
      onPreviousChapter: previousChapter,
      getChapterProgress: getChapterProgress,
      getBookProgress: getBookProgress,
      getCurrentTime: getCurrentTime,
      buildSegment: _buildScrollSegment,
      onSaveProgress: _saveProgress,
    );
    actionsCoordinator = bundle.actions;
    scrollCoordinator = bundle.scroll;
    inputCoordinator = bundle.input;
    imageCoordinator = bundle.image;
    sourceSwitchCoordinator = bundle.sourceSwitch;
  }

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

  ({String title, String content}) _processChapterContent({
    required String chapterId,
    required String rawTitle,
    required String rawContent,
  }) =>
      processReaderChapterContent(
        settings: settings,
        chineseConverter: _chineseConverter,
        chapterId: chapterId,
        rawTitle: rawTitle,
        rawContent: rawContent,
      );

  Future<String> _fetchContent(Chapter ch) => fetchReaderChapterContent(
        chapter: ch,
        sourceUrlHint: image.sourceUrl,
        sourceRepo: _sourceRepo,
        ruleEngine: _ruleEngine,
      );

  void _paginateAndJump({
    required int chapterIndex,
    required bool goToLastPage,
    required bool restoreOffset,
    double? targetProgress,
  }) {
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
    paginateAndJumpReaderPages(
      pageFactory: paged.pageFactory,
      contentSize: contentSize,
      settings: settings,
      chapter: chapter,
      chapterIndex: chapterIndex,
      goToLastPage: goToLastPage,
      restoreOffset: restoreOffset,
      targetProgress: targetProgress,
      readChapterPageProgress: () => _settingsService.getChapterPageProgress(
        bookId,
        chapterIndex: chapterIndex,
      ),
    );
  }

  void updateSettings(ReadingSettings newSettings, {bool persist = true}) {
    final old = settings.settings;
    final normalized = settingsCtrl.readSettingsWithExclusions(newSettings);
    settings.update(normalized);
    unawaited(settingsCtrl.syncBrightness(old, normalized));
    if (persist) {
      unawaited(_settingsService.saveReadingSettings(normalized));
    }
    // 翻页模式切换：分页 ↔ 滚动 之间彼此的内容容器（PageFactory / segments）
    // 是各自维护的，不会自动填充。切换时需要主动触发对应模式的首次构建，
    // 否则切过去会显示空白。
    if (old.pageTurnMode != normalized.pageTurnMode) {
      postFrameCallback(() => requestRepaginate(restoreOffset: true));
    }
  }

  void toggleMenu() => ui.toggleMenu(!ui.showMenu);
  void closeMenu() {
    if (ui.showMenu) ui.toggleMenu(false);
    if (ui.showSearchMenu) ui.toggleSearchMenu(false);
  }

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
    return ScrollSegment(
      chapterIndex: chapterIndex,
      chapterId: ch.id,
      title: processed.title,
      content: processed.content,
      estimatedHeight: estimateScrollSegmentHeight(processed.content),
    );
  }

  Future<void> _prefetchNeighbors(int centerIndex) =>
      prefetchReaderNeighborChapters(
        chapter: chapter,
        fetch: _fetchContent,
        centerIndex: centerIndex,
      );

  Future<void> _saveProgress() => saveReaderBookProgress(
        bookRepo: _bookRepo,
        bookId: bookId,
        chapterIndex: chapter.currentIndex,
        chapterProgress: getChapterProgress(),
      );

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
