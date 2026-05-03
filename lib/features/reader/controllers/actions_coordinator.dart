import 'dart:async';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../services/reader_charset_service.dart';
import '../services/reader_content_processor.dart';
import 'actions_catalog_refresh_engine.dart';
import 'actions_webdav_progress_engine.dart';
import 'reader_state.dart';

export 'actions_webdav_progress_engine.dart'
    show WebDavSyncResult, WebDavPullResult;

/// 阅读菜单操作纯逻辑委托。
///
/// 管理所有不需要 BuildContext 的菜单动作：
/// - 书籍格式判断（本地 / TXT / EPUB）
/// - WebDAV 进度同步（上传 / 拉取）
/// - 内容开关（替换规则、重排段落、ruby/h 标签）
/// - 章节内容反转、原文获取
/// - 目录刷新
/// - 模拟阅读
/// - 图片样式
///
/// 需要 BuildContext 的对话框操作留在 View 层。
class ActionsCoordinator {
  ActionsCoordinator({
    required this.bookId,
    required this.bookTitle,
    required this.isEphemeral,
    required this.chapter,
    required this.settings,
    required this.image,
    required this.bookRepo,
    required this.chapterRepo,
    required this.sourceRepo,
    required this.settingsService,
    required this.webDavService,
    required this.charsetService,
    required this.catalogUpdateService,
    required this.ruleEngine,
    required this.onLoadChapter,
    required this.onShowToast,
    required this.getChapterProgress,
    required this.getBookProgress,
  })  : _webDavEngine = WebDavProgressEngine(
          bookId: bookId,
          bookTitle: bookTitle,
          chapter: chapter,
          image: image,
          bookRepo: bookRepo,
          settingsService: settingsService,
          webDavService: webDavService,
          onLoadChapter: onLoadChapter,
          getChapterProgress: getChapterProgress,
          getBookProgress: getBookProgress,
        ),
        _catalogEngine = CatalogRefreshEngine(
          bookId: bookId,
          bookTitle: bookTitle,
          isEphemeral: isEphemeral,
          chapter: chapter,
          image: image,
          bookRepo: bookRepo,
          chapterRepo: chapterRepo,
          settingsService: settingsService,
          charsetService: charsetService,
          catalogUpdateService: catalogUpdateService,
          onLoadChapter: onLoadChapter,
          onClearContentCaches: () => chapter.cache.clear(),
        );

  final String bookId;
  final String bookTitle;
  final bool isEphemeral;

  // ── 状态仓库 ──
  final ChapterState chapter;
  final SettingsState settings;
  final ImageCacheState image;

  // ── 服务 ──
  final BookRepository bookRepo;
  final ChapterRepository chapterRepo;
  final SourceRepository sourceRepo;
  final SettingsService settingsService;
  final WebDavService webDavService;
  final ReaderCharsetService charsetService;
  final BookshelfCatalogUpdateService catalogUpdateService;
  final RuleParserEngine ruleEngine;

  // ── 引擎 ──
  final WebDavProgressEngine _webDavEngine;
  final CatalogRefreshEngine _catalogEngine;

  // ── 回调 ──
  /// 加载指定章节，与 [ReaderCoordinator.loadChapter] 对应。
  final Future<void> Function(
    int index, {
    bool restoreOffset,
    double? targetChapterProgress,
  }) onLoadChapter;

  final void Function(String message) onShowToast;
  final double Function() getChapterProgress;
  final double Function() getBookProgress;

  // ═══════════════════════════════════════════════════════════════════
  // 书籍格式判断
  // ═══════════════════════════════════════════════════════════════════

  /// 当前书籍是否为本地书籍。
  bool isCurrentBookLocal() {
    if (isEphemeral) return false;
    return bookRepo.getBookById(bookId)?.isLocal ?? false;
  }

  /// 当前书籍是否为本地 TXT 文件。
  bool isCurrentBookLocalTxt() {
    if (isEphemeral) return false;
    final book = bookRepo.getBookById(bookId);
    if (book == null || !book.isLocal) return false;
    final lower = (book.localPath ?? book.bookUrl ?? '').toLowerCase();
    return lower.endsWith('.txt');
  }

  /// 当前书籍是否为 EPUB 文件。
  bool isCurrentBookEpub() {
    if (isEphemeral) return false;
    final book = bookRepo.getBookById(bookId);
    if (book == null || !book.isLocal) return false;
    final lower = (book.localPath ?? book.bookUrl ?? '').toLowerCase();
    return lower.endsWith('.epub');
  }

  /// 对 EPUB 书籍默认关闭替换规则。
  bool defaultUseReplaceRule() => !isCurrentBookEpub();

  /// WebDAV 是否配置了有效的进度同步。
  bool hasWebDavProgressConfig() => _webDavEngine.hasValidConfig();

  /// 是否启用了书籍进度同步。
  bool isSyncBookProgressEnabled() => _webDavEngine.isSyncEnabled();

  // ═══════════════════════════════════════════════════════════════════
  // WebDAV 进度同步
  // ═══════════════════════════════════════════════════════════════════

  /// 上传当前阅读进度到 WebDAV。
  Future<WebDavSyncResult> pushProgressToWebDav() => _webDavEngine.push();

  /// 从 WebDAV 拉取阅读进度，返回需要跳转的信息。
  Future<WebDavPullResult> pullProgressFromWebDav() => _webDavEngine.pull();

  /// 确认应用远端进度后调用。
  Future<void> applyRemoteProgress(WebDavPullResult result) =>
      _webDavEngine.applyRemote(result);

  // ═══════════════════════════════════════════════════════════════════
  // 内容开关
  // ═══════════════════════════════════════════════════════════════════

  /// 切换"重排段落"开关。
  Future<void> toggleReSegment() async {
    final next = !settings.reSegment;
    if (!isEphemeral) {
      await settingsService.saveBookReSegment(bookId, next);
    }
    settings.reSegment = next;
    settings.notify();

    if (chapter.chapters.isEmpty) return;
    final targetIndex = chapter.currentIndex.clamp(0, chapter.maxIndex);
    await onLoadChapter(targetIndex, restoreOffset: true);
  }

  /// 切换"替换规则"开关。
  Future<void> toggleReplaceRule() async {
    final next = !settings.useReplaceRule;
    if (!isEphemeral) {
      await settingsService.saveBookUseReplaceRule(bookId, next);
    }
    settings.useReplaceRule = next;
    settings.notify();

    _clearContentCaches();
    if (chapter.chapters.isEmpty) return;
    final targetIndex = chapter.currentIndex.clamp(0, chapter.maxIndex);
    await onLoadChapter(targetIndex, restoreOffset: true);
  }

  /// 切换 EPUB ruby/h 标签清理。
  Future<void> toggleEpubTagCleanup({required bool ruby}) async {
    if (!isCurrentBookEpub()) {
      onShowToast('当前书籍不是 EPUB');
      return;
    }
    final next = ruby ? !settings.delRubyTag : !settings.delHTag;
    if (!isEphemeral) {
      if (ruby) {
        await settingsService.saveBookDelRubyTag(bookId, next);
      } else {
        await settingsService.saveBookDelHTag(bookId, next);
      }
    }
    if (ruby) {
      settings.delRubyTag = next;
    } else {
      settings.delHTag = next;
    }
    settings.notify();

    _clearContentCaches();
    final targetIndex = chapter.currentIndex.clamp(0, chapter.maxIndex);
    await onLoadChapter(targetIndex, restoreOffset: true);
  }

  /// 切换"同名标题移除"开关。
  Future<void> toggleSameTitleRemoved() async {
    if (chapter.chapters.isEmpty) return;
    final idx = chapter.currentIndex.clamp(0, chapter.maxIndex);
    final ch = chapter.chapters[idx];
    final currentlyRemoved =
        chapter.cache.sameTitleRemovedById[ch.id] ?? false;
    final nextEnabled = !currentlyRemoved;
    chapter.cache.sameTitleRemovedById[ch.id] = nextEnabled;

    if (!isEphemeral) {
      await settingsService.saveChapterSameTitleRemoved(
        bookId,
        ch.id,
        nextEnabled,
      );
    }
    await onLoadChapter(chapter.currentIndex, restoreOffset: true);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 章节内容操作
  // ═══════════════════════════════════════════════════════════════════

  /// 反转当前章节内容（对齐 legado）。
  Future<void> reverseCurrentChapterContent() async {
    if (chapter.chapters.isEmpty) return;
    final idx = chapter.currentIndex.clamp(0, chapter.maxIndex);
    final ch = chapter.chapters[idx];
    final rawContent = ch.content ?? '';
    if (rawContent.isEmpty) return;

    final reversed = ReaderContentProcessor.reverseContent(rawContent);
    if (!isEphemeral) {
      await chapterRepo.cacheChapterContent(ch.id, reversed);
    }

    chapter.cache.clearForChapter(ch.id);
    chapter.chapters[idx] = ch.copyWith(
      content: reversed,
      isDownloaded: true,
    );
    chapter.notify();
    await onLoadChapter(idx, restoreOffset: true);
  }

  /// 保存编辑后的章节内容，返回是否有变更。
  Future<bool> applyContentEdit({
    required int chapterIndex,
    required String newTitle,
    required String newContent,
  }) async {
    if (chapterIndex < 0 || chapterIndex >= chapter.chapters.length) {
      return false;
    }
    final ch = chapter.chapters[chapterIndex];
    final nextTitle = newTitle.trim().isEmpty ? ch.title : newTitle.trim();
    final shouldPersist = newContent.isNotEmpty;
    final nextStoredContent = shouldPersist ? newContent : ch.content;
    final nextIsDownloaded = shouldPersist ? true : ch.isDownloaded;
    final hasChanges = nextTitle != ch.title ||
        nextStoredContent != ch.content ||
        nextIsDownloaded != ch.isDownloaded;
    if (!hasChanges) return false;

    final updated = ch.copyWith(
      title: nextTitle,
      content: nextStoredContent,
      isDownloaded: nextIsDownloaded,
    );
    if (!isEphemeral) {
      await chapterRepo.addChapters(<Chapter>[updated]);
    }

    chapter.cache.clearForChapter(ch.id);
    chapter.chapters[chapterIndex] = updated;
    chapter.notify();
    await onLoadChapter(chapterIndex, restoreOffset: true);
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 目录刷新
  // ═══════════════════════════════════════════════════════════════════

  /// 刷新在线书籍的目录。
  Future<List<Chapter>> refreshCatalogFromSource() => _catalogEngine.refresh();

  /// 应用编码设置后重新解析本地书籍。
  Future<void> applyCharsetSetting({required String charset}) =>
      _catalogEngine.applyCharset(charset: charset);

  // ═══════════════════════════════════════════════════════════════════
  // 模拟阅读
  // ═══════════════════════════════════════════════════════════════════

  /// 应用模拟阅读配置。
  Future<void> applySimulatedReading({
    required bool enabled,
    required int startChapter,
    required int dailyChapters,
    required DateTime startDate,
  }) async {
    await settingsService.saveBookSimulatedReadingConfig(
      bookId,
      enabled: enabled,
      startChapter: startChapter,
      dailyChapters: dailyChapters,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
    );

    _clearContentCaches();

    if (chapter.readableCount <= 0) {
      chapter.update(
        index: 0,
        title: '',
        content: '',
      );
      return;
    }

    final targetIndex =
        chapter.currentIndex.clamp(0, chapter.readableCount - 1);
    await onLoadChapter(targetIndex, restoreOffset: true);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 图片样式
  // ═══════════════════════════════════════════════════════════════════

  static const List<String> legacyImageStyles = [
    'DEFAULT',
    'FULL',
    'TEXT',
    'SINGLE',
  ];

  /// 应用图片样式设置。
  Future<void> applyImageStyle(String style) async {
    final normalized = _normalizeLegacyImageStyle(style);
    if (!isEphemeral) {
      await settingsService.saveBookImageStyle(bookId, normalized);
    }
    settings.imageStyle = normalized;
    settings.notify();

    if (normalized == 'SINGLE') {
      await _applyBookPageAnim(0);
    }
    await onLoadChapter(
      chapter.currentIndex,
      restoreOffset: true,
    );
  }

  /// 应用书籍翻页动画覆盖。
  Future<void> applyBookPageAnim(int animIndex) => _applyBookPageAnim(animIndex);

  // ═══════════════════════════════════════════════════════════════════
  // 书签导出
  // ═══════════════════════════════════════════════════════════════════

  /// 构建进度同步用的书名。
  String progressSyncBookTitle() => _webDavEngine.bookTitleForSync();

  /// 构建进度同步用的作者名。
  String progressSyncBookAuthor() => _webDavEngine.bookAuthorForSync();

  // ═══════════════════════════════════════════════════════════════════
  // 私有方法
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _applyBookPageAnim(int animIndex) async {
    if (!isEphemeral) {
      await settingsService.saveBookPageAnim(bookId, animIndex);
    }
    settings.bookPageAnimOverride = animIndex;
    settings.notify();
  }

  String _normalizeLegacyImageStyle(String style) {
    final normalized = style.trim().toUpperCase();
    if (legacyImageStyles.contains(normalized)) return normalized;
    return legacyImageStyles.first;
  }

  void _clearContentCaches() => chapter.cache.clear();
}
