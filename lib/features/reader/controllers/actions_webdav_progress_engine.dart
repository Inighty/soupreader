import 'dart:async';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import 'reader_state.dart';

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

/// WebDAV 阅读进度同步引擎。
///
/// 把上传 / 拉取 / 应用远端进度的实现从 [ActionsCoordinator] 抽离出来，
/// 让协调器只保留薄壳委托。
class WebDavProgressEngine {
  WebDavProgressEngine({
    required this.bookId,
    required this.bookTitle,
    required this.chapter,
    required this.image,
    required this.bookRepo,
    required this.settingsService,
    required this.webDavService,
    required this.onLoadChapter,
    required this.getChapterProgress,
    required this.getBookProgress,
  });

  final String bookId;
  final String bookTitle;
  final ChapterState chapter;
  final ImageCacheState image;
  final BookRepository bookRepo;
  final SettingsService settingsService;
  final WebDavService webDavService;
  final Future<void> Function(
    int index, {
    bool restoreOffset,
    double? targetChapterProgress,
  }) onLoadChapter;
  final double Function() getChapterProgress;
  final double Function() getBookProgress;

  /// WebDAV 是否配置了有效的进度同步。
  bool hasValidConfig() {
    final appSettings = settingsService.appSettings;
    final rootUrl = webDavService.buildRootUrl(appSettings).trim();
    final rootUri = Uri.tryParse(rootUrl);
    if (rootUri == null) return false;
    final scheme = rootUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return webDavService.hasValidConfig(appSettings);
  }

  /// 是否启用了书籍进度同步。
  bool isSyncEnabled() => settingsService.appSettings.syncBookProgress;

  String bookTitleForSync() {
    final titleFromRepo = bookRepo.getBookById(bookId)?.title.trim() ?? '';
    if (titleFromRepo.isNotEmpty) return titleFromRepo;
    final title = bookTitle.trim();
    if (title.isNotEmpty) return title;
    return '未知书名';
  }

  String bookAuthorForSync() {
    final authorFromRepo = bookRepo.getBookById(bookId)?.author.trim() ?? '';
    if (authorFromRepo.isNotEmpty) return authorFromRepo;
    final author = image.bookAuthor.trim();
    if (author.isNotEmpty) return author;
    return '未知作者';
  }

  /// 上传当前阅读进度到 WebDAV。
  Future<WebDavSyncResult> push() async {
    if (!isSyncEnabled() ||
        !hasValidConfig() ||
        chapter.chapters.isEmpty) {
      return const WebDavSyncResult(success: false, skipped: true);
    }

    final title = bookTitleForSync();
    final author = bookAuthorForSync();
    try {
      final progress = _buildLocalPayload();
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

  /// 从 WebDAV 拉取阅读进度。
  Future<WebDavPullResult> pull() async {
    if (!isSyncEnabled() ||
        !hasValidConfig() ||
        chapter.chapters.isEmpty) {
      return const WebDavPullResult(hasData: false);
    }

    final title = bookTitleForSync();
    final author = bookAuthorForSync();
    try {
      final remote = await webDavService.getBookProgress(
        bookTitle: title,
        bookAuthor: author,
        settings: settingsService.appSettings,
      );
      if (remote == null) {
        return const WebDavPullResult(hasData: false);
      }
      return _analyzeRemote(remote, title: title, author: author);
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
  Future<void> applyRemote(WebDavPullResult result) async {
    if (!result.hasData) return;
    await onLoadChapter(
      result.targetChapterIndex,
      restoreOffset: true,
      targetChapterProgress: result.targetChapterProgress,
    );
  }

  WebDavBookProgress _buildLocalPayload() {
    final chapterProgress = getChapterProgress().clamp(0.0, 1.0).toDouble();
    final readableCount = chapter.readableCount;
    final safeIndex = readableCount > 0
        ? chapter.currentIndex.clamp(0, readableCount - 1)
        : 0;
    return WebDavBookProgress(
      name: bookTitleForSync(),
      author: bookAuthorForSync(),
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

  WebDavPullResult _analyzeRemote(
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
      final content = (chapter.chapters[targetIndex].content ?? '').trim();
      if (content.isNotEmpty) {
        targetProgress =
            (remotePos / content.length).clamp(0.0, 1.0).toDouble();
      }
    }

    final localIndex = chapter.currentIndex.clamp(0, maxIndex);
    final localProgress = getChapterProgress().clamp(0.0, 1.0).toDouble();

    final remoteBehind = targetIndex < localIndex ||
        (targetIndex == localIndex && targetProgress < localProgress);

    final delta = (targetProgress - localProgress).abs();
    final isSame = targetIndex == localIndex && delta <= 0.0001;

    if (isSame) {
      if (!remoteBehind) {
        _logSynced(remote, title: title, author: author);
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

  void _logSynced(
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

  String _normalizeErrorMessage(Object error) {
    final msg = error.toString();
    if (msg.length > 200) return '${msg.substring(0, 200)}…';
    return msg;
  }
}
