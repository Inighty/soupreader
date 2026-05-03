import 'dart:async';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/book.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../import/txt_parser.dart';
import '../../search/services/search_book_info_refresh_helper.dart';
import '../services/reader_charset_service.dart';
import '../services/reader_source_switch_helper.dart';
import 'reader_state.dart';

/// 目录刷新引擎。
///
/// 负责在线/本地书籍的目录重新加载、字符集重解析等逻辑。
class CatalogRefreshEngine {
  CatalogRefreshEngine({
    required this.bookId,
    required this.bookTitle,
    required this.isEphemeral,
    required this.chapter,
    required this.image,
    required this.bookRepo,
    required this.chapterRepo,
    required this.settingsService,
    required this.charsetService,
    required this.catalogUpdateService,
    required this.onLoadChapter,
    required this.onClearContentCaches,
  });

  final String bookId;
  final String bookTitle;
  final bool isEphemeral;
  final ChapterState chapter;
  final ImageCacheState image;
  final BookRepository bookRepo;
  final ChapterRepository chapterRepo;
  final SettingsService settingsService;
  final ReaderCharsetService charsetService;
  final BookshelfCatalogUpdateService catalogUpdateService;
  final Future<void> Function(
    int index, {
    bool restoreOffset,
    double? targetChapterProgress,
  }) onLoadChapter;
  final void Function() onClearContentCaches;

  bool get _isLocalTxt {
    final book = bookRepo.getBookById(bookId);
    if (book == null || !book.isLocal) return false;
    final lower = (book.localPath ?? book.bookUrl ?? '').toLowerCase();
    return lower.endsWith('.txt');
  }

  bool get _isLocal {
    if (isEphemeral) return false;
    return bookRepo.getBookById(bookId)?.isLocal ?? false;
  }

  /// 刷新书籍目录（按本地 / 在线分流）。
  Future<List<Chapter>> refresh() async {
    final book = bookRepo.getBookById(bookId);
    if (book == null) throw StateError('书籍信息不存在');

    if (book.isLocal) {
      return _refreshLocal(book);
    }
    return _refreshOnline(book);
  }

  /// 应用编码设置后重新解析本地书籍。
  Future<void> applyCharset({required String charset}) async {
    final book = bookRepo.getBookById(bookId);
    if (book == null || !book.isLocal) return;

    final normalized =
        ReaderCharsetService.normalizeCharset(charset) ?? charset.trim();
    await charsetService.setBookCharset(bookId, normalized);

    if (!_isLocal) return;

    chapter.update(loading: true);
    try {
      if (_isLocalTxt) {
        final splitLongChapter =
            settingsService.getBookSplitLongChapter(bookId);
        await _reparseLocalTxt(
          book: book,
          charset: normalized,
          splitLongChapter: splitLongChapter,
        );
      } else {
        await _reloadLocalAfterCharset(book: book);
      }
    } finally {
      chapter.update(loading: false);
    }
  }

  Future<List<Chapter>> _refreshOnline(Book book) async {
    final summary = await catalogUpdateService.updateBooks([book]);
    if (summary.failedCount > 0) {
      final reason = _extractFailureReason(summary.failedDetails);
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
    chapter.currentIndex = chapter.currentIndex.clamp(0, maxChapter);
    chapter.currentTitle = updated[chapter.currentIndex].title;
    if (refreshedBook != null) {
      image.bookAuthor = refreshedBook.author;
      image.bookCoverUrl = refreshedBook.coverUrl;
      image.sourceUrl =
          (refreshedBook.sourceUrl ?? refreshedBook.sourceId ?? '').trim();
    }
    chapter.notify();
    return updated;
  }

  Future<List<Chapter>> _refreshLocal(Book book) async {
    final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
      preferredTxtCharset: _isLocalTxt
          ? (charsetService.getBookCharset(bookId) ??
              ReaderCharsetService.defaultCharset)
          : null,
      splitLongChapter: settingsService.getBookSplitLongChapter(bookId),
      txtTocRuleRegex: settingsService.getBookTxtTocRule(bookId),
    );
    return _replaceAndReload(
      refreshed.chapters,
      updatedBook: refreshed.book,
    );
  }

  Future<void> _reparseLocalTxt({
    required Book book,
    required String charset,
    required bool splitLongChapter,
  }) async {
    final localPath = (book.localPath ?? book.bookUrl ?? '').trim();
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
    await _replaceAndReload(
      parsed.chapters,
      persistBook: book,
    );
  }

  Future<void> _reloadLocalAfterCharset({required Book book}) async {
    final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
    );
    await _replaceAndReload(
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
  Future<List<Chapter>> _replaceAndReload(
    List<Chapter> newChapters, {
    Book? updatedBook,
    Book? persistBook,
  }) async {
    if (newChapters.isEmpty) {
      throw StateError('重解析后章节为空');
    }

    final previousTitle = chapter.chapters.isEmpty
        ? chapter.currentTitle
        : chapter
            .chapters[chapter.currentIndex.clamp(0, chapter.maxIndex)].title;
    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
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
    onClearContentCaches();
    chapter.chapters = newChapters;
    chapter.notify();

    await onLoadChapter(
      targetIndex.clamp(0, newChapters.length - 1),
      restoreOffset: true,
    );
    return newChapters;
  }

  String _extractFailureReason(List<dynamic> failedDetails) {
    if (failedDetails.isEmpty) return '未知原因';
    return failedDetails.first.toString();
  }
}
