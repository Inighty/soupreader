import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/book.dart';
import 'bookshelf_catalog_update_service.dart';

typedef CacheDownloadProgressListener = void Function(
  CacheDownloadProgress progress,
);

typedef CacheDownloadStartIndexResolver = int Function(
  Book book,
  int maxIndex,
);

class CacheDownloadProgress {
  final String bookId;
  final int bookIndex;
  final int totalBooks;
  final String bookTitle;
  final int requestedChapters;
  final int downloadedChapters;
  final int skippedChapters;
  final int failedChapters;
  final int overallRequestedChapters;
  final int overallDownloadedChapters;
  final int overallSkippedChapters;
  final int overallFailedChapters;

  const CacheDownloadProgress({
    required this.bookId,
    required this.bookIndex,
    required this.totalBooks,
    required this.bookTitle,
    required this.requestedChapters,
    required this.downloadedChapters,
    required this.skippedChapters,
    required this.failedChapters,
    required this.overallRequestedChapters,
    required this.overallDownloadedChapters,
    required this.overallSkippedChapters,
    required this.overallFailedChapters,
  });

  int get completedChapters =>
      downloadedChapters + skippedChapters + failedChapters;
}

class CacheDownloadBookResult {
  final String bookId;
  final String bookTitle;
  final int requestedChapters;
  final int downloadedChapters;
  final int skippedChapters;
  final int failedChapters;
  final String? note;

  const CacheDownloadBookResult({
    required this.bookId,
    required this.bookTitle,
    required this.requestedChapters,
    required this.downloadedChapters,
    required this.skippedChapters,
    required this.failedChapters,
    this.note,
  });
}

class CacheDownloadSummary {
  final int requestedBooks;
  final int candidateBooks;
  final int processedBooks;
  final int requestedChapters;
  final int downloadedChapters;
  final int skippedChapters;
  final int failedChapters;
  final bool stoppedByUser;
  final List<CacheDownloadBookResult> bookResults;

  const CacheDownloadSummary({
    required this.requestedBooks,
    required this.candidateBooks,
    required this.processedBooks,
    required this.requestedChapters,
    required this.downloadedChapters,
    required this.skippedChapters,
    required this.failedChapters,
    required this.stoppedByUser,
    required this.bookResults,
  });
}

/// 书架“缓存/导出”页下载任务（对齐 legado `menu_download/menu_download_after/menu_download_all`）。
class CacheDownloadTaskService {
  final RuleParserEngine _ruleEngine;
  final SourceRepository _sourceRepo;
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;
  final BookshelfCatalogUpdateService _catalogUpdater;

  bool _running = false;
  bool _stopRequested = false;
  CancelToken? _activeCancelToken;

  CacheDownloadTaskService({
    DatabaseService? database,
    RuleParserEngine? ruleEngine,
    SourceRepository? sourceRepo,
    BookRepository? bookRepo,
    ChapterRepository? chapterRepo,
    BookshelfCatalogUpdateService? catalogUpdater,
  }) : this._(
          database ?? DatabaseService(),
          ruleEngine: ruleEngine,
          sourceRepo: sourceRepo,
          bookRepo: bookRepo,
          chapterRepo: chapterRepo,
          catalogUpdater: catalogUpdater,
        );

  CacheDownloadTaskService._(
    DatabaseService db, {
    RuleParserEngine? ruleEngine,
    SourceRepository? sourceRepo,
    BookRepository? bookRepo,
    ChapterRepository? chapterRepo,
    BookshelfCatalogUpdateService? catalogUpdater,
  })  : _ruleEngine = ruleEngine ?? RuleParserEngine(),
        _sourceRepo = sourceRepo ?? SourceRepository(db),
        _bookRepo = bookRepo ?? BookRepository(db),
        _chapterRepo = chapterRepo ?? ChapterRepository(db),
        _catalogUpdater =
            catalogUpdater ?? BookshelfCatalogUpdateService(database: db);

  bool get isRunning => _running;

  void stop() {
    _stopRequested = true;
    _activeCancelToken?.cancel('cache_download_stopped');
  }

  Future<CacheDownloadSummary> startDownloadFromCurrentChapter(
    Iterable<Book> books, {
    CacheDownloadProgressListener? onProgress,
  }) async {
    return _startDownload(
      books,
      onProgress: onProgress,
      resolveStartIndex: (book, maxIndex) =>
          book.currentChapter.clamp(0, maxIndex).toInt(),
    );
  }

  Future<CacheDownloadSummary> startDownloadAllChapters(
    Iterable<Book> books, {
    CacheDownloadProgressListener? onProgress,
  }) async {
    return _startDownload(
      books,
      onProgress: onProgress,
      resolveStartIndex: (_, __) => 0,
    );
  }

  Future<CacheDownloadSummary> _startDownload(
    Iterable<Book> books, {
    required CacheDownloadStartIndexResolver resolveStartIndex,
    CacheDownloadProgressListener? onProgress,
  }) async {
    if (_running) {
      throw StateError('缓存下载任务进行中');
    }

    _running = true;
    _stopRequested = false;

    try {
      final requestedBooks = books.toList(growable: false);
      final candidates =
          requestedBooks.where((book) => !book.isLocal).toList(growable: false);
      final bookResults = <CacheDownloadBookResult>[];

      var overallRequested = 0;
      var overallDownloaded = 0;
      var overallSkipped = 0;
      var overallFailed = 0;

      for (var i = 0; i < candidates.length; i += 1) {
        if (_stopRequested) break;

        final inputBook = candidates[i];
        final latestBook = _bookRepo.getBookById(inputBook.id) ?? inputBook;
        final source = _resolveSource(latestBook);
        if (source == null) {
          bookResults.add(
            CacheDownloadBookResult(
              bookId: latestBook.id,
              bookTitle: latestBook.title,
              requestedChapters: 0,
              downloadedChapters: 0,
              skippedChapters: 0,
              failedChapters: 0,
              note: '书源缺失，已跳过',
            ),
          );
          continue;
        }

        final chapters = await _ensureChapters(latestBook);
        if (_stopRequested) break;
        if (chapters.isEmpty) {
          bookResults.add(
            CacheDownloadBookResult(
              bookId: latestBook.id,
              bookTitle: latestBook.title,
              requestedChapters: 0,
              downloadedChapters: 0,
              skippedChapters: 0,
              failedChapters: 0,
              note: '目录为空，已跳过',
            ),
          );
          continue;
        }

        final maxIndex = chapters.length - 1;
        final startIndex =
            resolveStartIndex(latestBook, maxIndex).clamp(0, maxIndex).toInt();
        final requestedCount = math.max(0, chapters.length - startIndex);
        overallRequested += requestedCount;

        var downloaded = 0;
        var skipped = 0;
        var failed = 0;

        onProgress?.call(
          CacheDownloadProgress(
            bookId: latestBook.id,
            bookIndex: i,
            totalBooks: candidates.length,
            bookTitle: latestBook.title,
            requestedChapters: requestedCount,
            downloadedChapters: downloaded,
            skippedChapters: skipped,
            failedChapters: failed,
            overallRequestedChapters: overallRequested,
            overallDownloadedChapters: overallDownloaded,
            overallSkippedChapters: overallSkipped,
            overallFailedChapters: overallFailed,
          ),
        );

        for (var chapterIndex = startIndex;
            chapterIndex < chapters.length;
            chapterIndex += 1) {
          if (_stopRequested) break;
          final chapter = chapters[chapterIndex];
          final chapterContent = (chapter.content ?? '').trim();
          if (chapter.isDownloaded && chapterContent.isNotEmpty) {
            skipped += 1;
            overallSkipped += 1;
            onProgress?.call(
              CacheDownloadProgress(
                bookId: latestBook.id,
                bookIndex: i,
                totalBooks: candidates.length,
                bookTitle: latestBook.title,
                requestedChapters: requestedCount,
                downloadedChapters: downloaded,
                skippedChapters: skipped,
                failedChapters: failed,
                overallRequestedChapters: overallRequested,
                overallDownloadedChapters: overallDownloaded,
                overallSkippedChapters: overallSkipped,
                overallFailedChapters: overallFailed,
              ),
            );
            continue;
          }

          final chapterUrl = (chapter.url ?? '').trim();
          if (chapterUrl.isEmpty) {
            failed += 1;
            overallFailed += 1;
            _recordFailure(
              node: 'bookshelf.cache.download.empty_chapter_url',
              message: '缓存章节失败：章节链接为空',
              book: latestBook,
              chapter: chapter,
            );
            onProgress?.call(
              CacheDownloadProgress(
                bookId: latestBook.id,
                bookIndex: i,
                totalBooks: candidates.length,
                bookTitle: latestBook.title,
                requestedChapters: requestedCount,
                downloadedChapters: downloaded,
                skippedChapters: skipped,
                failedChapters: failed,
                overallRequestedChapters: overallRequested,
                overallDownloadedChapters: overallDownloaded,
                overallSkippedChapters: overallSkipped,
                overallFailedChapters: overallFailed,
              ),
            );
            continue;
          }

          try {
            final token = CancelToken();
            _activeCancelToken = token;
            final content = await _ruleEngine.getContent(
              source,
              chapterUrl,
              clearRuntimeVariables: true,
              cancelToken: token,
            );
            if (_stopRequested) break;

            final trimmed = content.trim();
            if (trimmed.isEmpty) {
              failed += 1;
              overallFailed += 1;
              _recordFailure(
                node: 'bookshelf.cache.download.empty_content',
                message: '缓存章节失败：正文为空',
                book: latestBook,
                chapter: chapter,
              );
            } else {
              await _chapterRepo.cacheChapterContent(chapter.id, content);
              downloaded += 1;
              overallDownloaded += 1;
            }
          } catch (error, stackTrace) {
            if (_stopRequested || _isCancelError(error)) {
              break;
            }
            failed += 1;
            overallFailed += 1;
            _recordFailure(
              node: 'bookshelf.cache.download.fetch_failed',
              message: '缓存章节失败',
              book: latestBook,
              chapter: chapter,
              error: error,
              stackTrace: stackTrace,
            );
          } finally {
            _activeCancelToken = null;
          }

          onProgress?.call(
            CacheDownloadProgress(
              bookId: latestBook.id,
              bookIndex: i,
              totalBooks: candidates.length,
              bookTitle: latestBook.title,
              requestedChapters: requestedCount,
              downloadedChapters: downloaded,
              skippedChapters: skipped,
              failedChapters: failed,
              overallRequestedChapters: overallRequested,
              overallDownloadedChapters: overallDownloaded,
              overallSkippedChapters: overallSkipped,
              overallFailedChapters: overallFailed,
            ),
          );
        }

        bookResults.add(
          CacheDownloadBookResult(
            bookId: latestBook.id,
            bookTitle: latestBook.title,
            requestedChapters: requestedCount,
            downloadedChapters: downloaded,
            skippedChapters: skipped,
            failedChapters: failed,
            note: null,
          ),
        );
      }

      return CacheDownloadSummary(
        requestedBooks: requestedBooks.length,
        candidateBooks: candidates.length,
        processedBooks: bookResults.length,
        requestedChapters: overallRequested,
        downloadedChapters: overallDownloaded,
        skippedChapters: overallSkipped,
        failedChapters: overallFailed,
        stoppedByUser: _stopRequested,
        bookResults: bookResults,
      );
    } finally {
      _activeCancelToken = null;
      _stopRequested = false;
      _running = false;
    }
  }

  Future<List<Chapter>> _ensureChapters(Book book) async {
    final existing = _chapterRepo.getChaptersForBook(book.id);
    if (existing.isNotEmpty || book.isLocal) {
      return existing;
    }

    final summary = await _catalogUpdater.updateBooks([book]);
    if (summary.failedCount > 0) {
      _recordFailure(
        node: 'bookshelf.cache.download.refresh_toc_failed',
        message: summary.failedDetails.join('；'),
        book: book,
        chapter: null,
      );
    }
    return _chapterRepo.getChaptersForBook(book.id);
  }

  BookSource? _resolveSource(Book book) {
    final sourceCandidates = <String>[
      (book.sourceUrl ?? '').trim(),
      (book.sourceId ?? '').trim(),
    ];
    for (final sourceUrl in sourceCandidates) {
      if (sourceUrl.isEmpty) continue;
      final source = _sourceRepo.getSourceByUrl(sourceUrl);
      if (source != null) return source;
    }
    return null;
  }

  bool _isCancelError(Object error) {
    return error is DioException && error.type == DioExceptionType.cancel;
  }

  void _recordFailure({
    required String node,
    required String message,
    required Book book,
    required Chapter? chapter,
    Object? error,
    StackTrace? stackTrace,
  }) {
    ExceptionLogService().record(
      node: node,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'bookId': book.id,
        'bookTitle': book.title,
        'bookUrl': book.bookUrl,
        'chapterId': chapter?.id,
        'chapterIndex': chapter?.index,
        'chapterTitle': chapter?.title,
        'chapterUrl': chapter?.url,
      },
    );
  }
}
