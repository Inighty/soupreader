import 'dart:async';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../import/txt_parser.dart';
import '../../search/services/search_book_info_refresh_helper.dart';
import '../../source/services/rule_parser_engine.dart';
import '../services/reader_charset_service.dart';
import '../services/reader_content_processor.dart';
import '../services/reader_source_switch_helper.dart';
import 'reader_state.dart';

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
  });

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
  bool hasWebDavProgressConfig() {
    final appSettings = settingsService.appSettings;
    final rootUrl = webDavService.buildRootUrl(appSettings).trim();
    final rootUri = Uri.tryParse(rootUrl);
    if (rootUri == null) return false;
    final scheme = rootUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return webDavService.hasValidConfig(appSettings);
  }

  /// 是否启用了书籍进度同步。
  bool isSyncBookProgressEnabled() {
    return settingsService.appSettings.syncBookProgress;
  }

  // ═══════════════════════════════════════════════════════════════════
  // WebDAV 进度同步
  // ═══════════════════════════════════════════════════════════════════

  /// 上传当前阅读进度到 WebDAV。
  Future<WebDavSyncResult> pushProgressToWebDav() async {
    if (!isSyncBookProgressEnabled() ||
        !hasWebDavProgressConfig() ||
        chapter.chapters.isEmpty) {
      return const WebDavSyncResult(success: false, skipped: true);
    }

    final title = _progressSyncBookTitle();
    final author = _progressSyncBookAuthor();
    try {
      final progress = _buildLocalProgressPayload();
      await webDavService.uploadBookProgress(
        progress: progress,
        settings: settingsService.appSettings,
      );
      return const WebDavSyncResult(success: true);
    } catch (error, stackTrace) {
      final reason = _normalizeErrorMessage(error);
      ExceptionLogService().record(
        node: 'reader.menu.cover_progress.failed',
        message: '上传阅读进度失败《$title》\n$reason',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': bookId,
          'bookTitle': title,
          'bookAuthor': author,
          'sourceUrl': image.sourceUrl,
        },
      );
      return WebDavSyncResult(
        success: false,
        errorMessage: '上传进度失败\n$reason',
      );
    }
  }

  /// 从 WebDAV 拉取阅读进度，返回需要跳转的信息。
  ///
  /// 若远端进度落后于本地，返回 [WebDavPullResult] 并标记
  /// [WebDavPullResult.needsConfirmation] 以让 View 层弹窗确认。
  Future<WebDavPullResult> pullProgressFromWebDav() async {
    if (!isSyncBookProgressEnabled() ||
        !hasWebDavProgressConfig() ||
        chapter.chapters.isEmpty) {
      return const WebDavPullResult(hasData: false);
    }

    final title = _progressSyncBookTitle();
    final author = _progressSyncBookAuthor();
    try {
      final remote = await webDavService.getBookProgress(
        bookTitle: title,
        bookAuthor: author,
        settings: settingsService.appSettings,
      );
      if (remote == null) {
        return const WebDavPullResult(hasData: false);
      }
      return _analyzeRemoteProgress(remote, title: title, author: author);
    } catch (error, stackTrace) {
      final reason = _normalizeErrorMessage(error);
      ExceptionLogService().record(
        node: 'reader.menu.get_progress.failed',
        message: '拉取阅读进度失败《$title》\n$reason',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': bookId,
          'bookTitle': bookTitle,
          'bookAuthor': image.bookAuthor,
          'sourceUrl': image.sourceUrl,
        },
      );
      return WebDavPullResult(
        hasData: false,
        errorMessage: '拉取进度失败\n$reason',
      );
    }
  }

  /// 确认应用远端进度后调用。
  Future<void> applyRemoteProgress(WebDavPullResult result) async {
    if (!result.hasData) return;
    await onLoadChapter(
      result.targetChapterIndex,
      restoreOffset: true,
      targetChapterProgress: result.targetChapterProgress,
    );
  }

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

    _clearContentCacheForChapter(ch.id);
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
    final nextTitle =
        newTitle.trim().isEmpty ? ch.title : newTitle.trim();
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

    _clearContentCacheForChapter(ch.id);
    chapter.chapters[chapterIndex] = updated;
    chapter.notify();
    await onLoadChapter(chapterIndex, restoreOffset: true);
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 目录刷新
  // ═══════════════════════════════════════════════════════════════════

  /// 刷新在线书籍的目录。
  ///
  /// 返回更新后的章节列表；出错时抛出异常。
  Future<List<Chapter>> refreshCatalogFromSource() async {
    final book = bookRepo.getBookById(bookId);
    if (book == null) throw StateError('书籍信息不存在');

    if (book.isLocal) {
      return _refreshLocalCatalog(book);
    }
    return _refreshOnlineCatalog(book);
  }

  /// 应用编码设置后重新解析本地书籍。
  Future<void> applyCharsetSetting({
    required String charset,
  }) async {
    final book = bookRepo.getBookById(bookId);
    if (book == null || !book.isLocal) return;

    final normalized =
        ReaderCharsetService.normalizeCharset(charset) ??
            charset.trim();
    await charsetService.setBookCharset(bookId, normalized);

    if (!isCurrentBookLocal()) return;

    chapter.update(loading: true);
    try {
      if (isCurrentBookLocalTxt()) {
        final splitLongChapter =
            settingsService.getBookSplitLongChapter(bookId);
        await _reparseLocalTxt(
          book: book,
          charset: normalized,
          splitLongChapter: splitLongChapter,
        );
      } else {
        await _reloadLocalCatalogAfterCharset(book: book);
      }
    } finally {
      chapter.update(loading: false);
    }
  }

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
      startDate: _normalizeDateOnly(startDate),
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
  Future<void> applyBookPageAnim(int animIndex) async {
    await _applyBookPageAnim(animIndex);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 书签导出
  // ═══════════════════════════════════════════════════════════════════

  /// 构建进度同步用的书名。
  String progressSyncBookTitle() => _progressSyncBookTitle();

  /// 构建进度同步用的作者名。
  String progressSyncBookAuthor() => _progressSyncBookAuthor();

  // ═══════════════════════════════════════════════════════════════════
  // 私有方法
  // ═══════════════════════════════════════════════════════════════════

  String _progressSyncBookTitle() {
    final titleFromRepo =
        bookRepo.getBookById(bookId)?.title.trim() ?? '';
    if (titleFromRepo.isNotEmpty) return titleFromRepo;
    final title = bookTitle.trim();
    if (title.isNotEmpty) return title;
    return '未知书名';
  }

  String _progressSyncBookAuthor() {
    final authorFromRepo =
        bookRepo.getBookById(bookId)?.author.trim() ?? '';
    if (authorFromRepo.isNotEmpty) return authorFromRepo;
    final author = image.bookAuthor.trim();
    if (author.isNotEmpty) return author;
    return '未知作者';
  }

  WebDavBookProgress _buildLocalProgressPayload() {
    final chapterProgress =
        getChapterProgress().clamp(0.0, 1.0).toDouble();
    final readableCount = chapter.readableCount;
    final safeIndex = readableCount > 0
        ? chapter.currentIndex.clamp(0, readableCount - 1)
        : 0;
    return WebDavBookProgress(
      name: _progressSyncBookTitle(),
      author: _progressSyncBookAuthor(),
      durChapterIndex: safeIndex,
      durChapterPos: (chapterProgress * 10000).round(),
      durChapterTime: DateTime.now().millisecondsSinceEpoch,
      durChapterTitle: chapter.currentTitle,
      chapterProgress: chapterProgress,
      readProgress: getBookProgress().clamp(0.0, 1.0).toDouble(),
      totalChapters: readableCount,
    );
  }

  double _decodeRemoteChapterProgress(WebDavBookProgress remote) {
    final explicit = remote.chapterProgress;
    if (explicit != null) {
      return explicit.clamp(0.0, 1.0).toDouble();
    }
    final pos = remote.durChapterPos;
    if (pos <= 0) return 0.0;
    if (pos <= 10000) {
      return (pos / 10000.0).clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  WebDavPullResult _analyzeRemoteProgress(
    WebDavBookProgress remote, {
    required String title,
    required String author,
  }) {
    final readableCount = chapter.readableCount;
    if (readableCount <= 0) {
      return const WebDavPullResult(hasData: false);
    }
    final maxIndex = readableCount - 1;
    final targetIndex = remote.durChapterIndex;
    if (targetIndex < 0 || targetIndex > maxIndex) {
      return const WebDavPullResult(hasData: false);
    }

    var targetProgress = _decodeRemoteChapterProgress(remote);
    final remotePos = remote.durChapterPos;
    final hasLegacyRawPos =
        remote.chapterProgress == null && remotePos > 10000;
    if (hasLegacyRawPos && targetProgress <= 0) {
      final content =
          (chapter.chapters[targetIndex].content ?? '').trim();
      if (content.isNotEmpty) {
        targetProgress =
            (remotePos / content.length).clamp(0.0, 1.0).toDouble();
      }
    }

    final localIndex =
        chapter.currentIndex.clamp(0, maxIndex);
    final localProgress =
        getChapterProgress().clamp(0.0, 1.0).toDouble();

    final remoteBehind = targetIndex < localIndex ||
        (targetIndex == localIndex && targetProgress < localProgress);

    final delta = (targetProgress - localProgress).abs();
    final isSame =
        targetIndex == localIndex && delta <= 0.0001;

    if (isSame) {
      if (!remoteBehind) {
        _logProgressSynced(remote, title: title, author: author);
      }
      return const WebDavPullResult(hasData: false);
    }

    return WebDavPullResult(
      hasData: true,
      targetChapterIndex: targetIndex,
      targetChapterProgress: targetProgress,
      needsConfirmation: remoteBehind,
      remoteChapterTitle: remote.durChapterTitle,
    );
  }

  void _logProgressSynced(
    WebDavBookProgress remote, {
    required String title,
    required String author,
  }) {
    final syncedTitle = (remote.durChapterTitle ?? '').trim();
    final suffix = syncedTitle.isEmpty ? '' : ' $syncedTitle';
    ExceptionLogService().record(
      node: 'reader.menu.get_progress.synced',
      message: '自动同步阅读进度成功《$title》$suffix',
      context: <String, dynamic>{
        'bookId': bookId,
        'bookTitle': title,
        'bookAuthor': author,
        'chapterIndex': remote.durChapterIndex,
        'chapterTitle': remote.durChapterTitle,
        'sourceUrl': image.sourceUrl,
      },
    );
  }

  Future<List<Chapter>> _refreshOnlineCatalog(Book book) async {
    final summary =
        await catalogUpdateService.updateBooks([book]);
    if (summary.failedCount > 0) {
      final reason =
          _extractCatalogFailureReason(summary.failedDetails);
      ExceptionLogService().record(
        node: 'reader.menu.update_toc.online_failed',
        message: '阅读页在线更新目录失败',
        error: reason,
        context: <String, dynamic>{
          'bookId': bookId,
          'bookTitle': bookTitle,
          'sourceUrl': image.sourceUrl,
          'failedDetails': summary.failedDetails,
        },
      );
      throw StateError('加载目录失败');
    }
    if (summary.updateCandidateCount <= 0) {
      throw StateError('加载目录失败');
    }

    final updated = chapterRepo.getChaptersForBook(bookId);
    if (updated.isEmpty) throw StateError('加载目录失败');

    final maxChapter = updated.length - 1;
    final refreshedBook = bookRepo.getBookById(bookId);

    chapter.chapters = updated;
    chapter.currentIndex =
        chapter.currentIndex.clamp(0, maxChapter);
    chapter.currentTitle = updated[chapter.currentIndex].title;
    if (refreshedBook != null) {
      image.bookAuthor = refreshedBook.author;
      image.bookCoverUrl = refreshedBook.coverUrl;
      image.sourceUrl =
          (refreshedBook.sourceUrl ?? refreshedBook.sourceId ?? '')
              .trim();
    }
    chapter.notify();
    return updated;
  }

  Future<List<Chapter>> _refreshLocalCatalog(Book book) async {
    final refreshed =
        await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
      preferredTxtCharset: isCurrentBookLocalTxt()
          ? (charsetService.getBookCharset(bookId) ??
              ReaderCharsetService.defaultCharset)
          : null,
      splitLongChapter:
          settingsService.getBookSplitLongChapter(bookId),
      txtTocRuleRegex: settingsService.getBookTxtTocRule(bookId),
    );
    return _replaceChaptersAndReload(
      refreshed.chapters,
      updatedBook: refreshed.book,
    );
  }

  Future<void> _reparseLocalTxt({
    required Book book,
    required String charset,
    required bool splitLongChapter,
  }) async {
    final localPath =
        (book.localPath ?? book.bookUrl ?? '').trim();
    if (localPath.isEmpty) {
      throw StateError('缺少本地 TXT 文件路径');
    }

    final parsed = await TxtParser.reparseFromFile(
      filePath: localPath,
      bookId: bookId,
      bookName: book.title,
      forcedCharset: charset,
      splitLongChapter: splitLongChapter,
      tocRuleRegex: settingsService.getBookTxtTocRule(bookId),
    );
    await _replaceChaptersAndReload(
      parsed.chapters,
      persistBook: book,
    );
  }

  Future<void> _reloadLocalCatalogAfterCharset({
    required Book book,
  }) async {
    final refreshed =
        await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
    );
    await _replaceChaptersAndReload(
      refreshed.chapters,
      updatedBook: refreshed.book,
    );
  }

  /// 替换章节列表并重新加载。
  ///
  /// 三个目录刷新方法共用的核心逻辑：
  /// 1. 定位当前阅读位置
  /// 2. 持久化新章节
  /// 3. 更新状态
  /// 4. 重新加载目标章节
  Future<List<Chapter>> _replaceChaptersAndReload(
    List<Chapter> newChapters, {
    Book? updatedBook,
    Book? persistBook,
  }) async {
    if (newChapters.isEmpty) {
      throw StateError('重解析后章节为空');
    }

    final previousTitle = chapter.chapters.isEmpty
        ? chapter.currentTitle
        : chapter.chapters[
                chapter.currentIndex.clamp(0, chapter.maxIndex)]
            .title;
    final targetIndex =
        ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: newChapters,
      currentChapterTitle: previousTitle,
      currentChapterIndex: chapter.currentIndex,
      oldChapterCount: chapter.chapters.length,
    );

    final bookToUpdate = updatedBook ?? persistBook;
    if (!isEphemeral && bookToUpdate != null) {
      await chapterRepo.clearChaptersForBook(bookId);
      await chapterRepo.addChapters(newChapters);
      await bookRepo.updateBook(
        bookToUpdate.copyWith(
          totalChapters: newChapters.length,
          latestChapter: newChapters.last.title,
          currentChapter: targetIndex,
        ),
      );
    }

    if (updatedBook != null) {
      image.bookAuthor = updatedBook.author;
      image.bookCoverUrl = updatedBook.coverUrl;
    }
    _clearContentCaches();
    chapter.chapters = newChapters;
    chapter.notify();

    await onLoadChapter(
      targetIndex.clamp(0, newChapters.length - 1),
      restoreOffset: true,
    );
    return newChapters;
  }

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

  DateTime _normalizeDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  void _clearContentCaches() {
    chapter.cache.clear();
  }

  void _clearContentCacheForChapter(String chapterId) {
    chapter.cache.clearForChapter(chapterId);
  }

  String _normalizeErrorMessage(Object error) {
    final msg = error.toString();
    if (msg.length > 200) return '${msg.substring(0, 200)}…';
    return msg;
  }

  String _extractCatalogFailureReason(
    List<dynamic> failedDetails,
  ) {
    if (failedDetails.isEmpty) return '未知原因';
    return failedDetails.first.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WebDAV 同步结果数据类
// ═══════════════════════════════════════════════════════════════════════

/// WebDAV 上传结果。
class WebDavSyncResult {
  const WebDavSyncResult({
    required this.success,
    this.skipped = false,
    this.errorMessage,
  });

  final bool success;
  final bool skipped;
  final String? errorMessage;
}

/// WebDAV 拉取结果。
class WebDavPullResult {
  const WebDavPullResult({
    required this.hasData,
    this.targetChapterIndex = 0,
    this.targetChapterProgress = 0.0,
    this.needsConfirmation = false,
    this.remoteChapterTitle,
    this.errorMessage,
  });

  final bool hasData;
  final int targetChapterIndex;
  final double targetChapterProgress;

  /// 远端进度落后于本地，需要用户确认是否覆盖。
  final bool needsConfirmation;
  final String? remoteChapterTitle;
  final String? errorMessage;
}
