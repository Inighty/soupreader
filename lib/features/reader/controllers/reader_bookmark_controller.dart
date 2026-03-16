import 'package:flutter/foundation.dart';

import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../services/reader_bookmark_export_service.dart';

/// Manages bookmark state for the current reading session.
///
/// Responsibilities:
/// - Init / query / add / remove bookmarks through [BookmarkRepository].
/// - Track whether a bookmark exists at the current chapter.
/// - Export bookmarks (JSON / Markdown) via [ReaderBookmarkExportService].
///
/// UI-only concerns (dialogs, toasts) remain in the View layer.
class ReaderBookmarkController extends ChangeNotifier {
  ReaderBookmarkController({
    required String bookId,
    required String bookTitle,
  })  : _bookId = bookId,
        _bookTitle = bookTitle;

  // ── Dependencies ──

  final BookmarkRepository _repo = BookmarkRepository();
  final ReaderBookmarkExportService _exportService =
      ReaderBookmarkExportService();

  final String _bookId;
  final String _bookTitle;

  // ── State ──

  bool _hasBookmarkAtCurrent = false;

  /// Whether a bookmark exists at the current chapter.
  bool get hasBookmarkAtCurrent => _hasBookmarkAtCurrent;

  /// All bookmarks for the current book.
  List<BookmarkEntity> get bookmarks => _repo.getBookmarksForBook(_bookId);

  // ── Lifecycle ──

  /// Must be called once before using any repo method.
  Future<void> init() async {
    try {
      await _repo.init();
    } catch (_) {
      // Bookmark subsystem failure should not block the reader.
    }
  }

  // ── Queries ──

  /// Refresh [hasBookmarkAtCurrent] for the given [chapterIndex].
  void updateStatus(int chapterIndex) {
    bool has = false;
    try {
      has = _repo.hasBookmark(_bookId, chapterIndex);
    } catch (_) {
      has = false;
    }
    if (_hasBookmarkAtCurrent == has) return;
    _hasBookmarkAtCurrent = has;
    notifyListeners();
  }

  /// Decode a persisted chapter-pos integer back to a 0.0–1.0 progress.
  double decodeChapterProgress(int chapterPos) =>
      (chapterPos / 10000.0).clamp(0.0, 1.0).toDouble();

  /// Encode a 0.0–1.0 chapter progress to the integer format stored in the
  /// database.
  int encodeChapterPos(double progress) =>
      (progress.clamp(0.0, 1.0) * 10000).round();

  // ── Mutations ──

  /// Add a new bookmark and refresh the status flag.
  Future<void> add({
    required String bookAuthor,
    required int chapterIndex,
    required String chapterTitle,
    required int chapterPos,
    required String content,
  }) async {
    await _repo.addBookmark(
      bookId: _bookId,
      bookName: _bookTitle,
      bookAuthor: bookAuthor,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      chapterPos: chapterPos,
      content: content,
    );
    updateStatus(chapterIndex);
  }

  /// 快捷添加当前阅读位置的书签。
  Future<void> addAtCurrentPosition({
    required String bookAuthor,
    required int chapterIndex,
    required String chapterTitle,
    required double chapterProgress,
    required String currentContent,
  }) async {
    await add(
      bookAuthor: bookAuthor,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      chapterPos: encodeChapterPos(chapterProgress),
      content: currentContent.length > 200
          ? currentContent.substring(0, 200)
          : currentContent,
    );
  }

  /// Remove a bookmark by its entity ID and refresh status.
  Future<void> remove(String id, int chapterIndex) async {
    await _repo.removeBookmark(id);
    updateStatus(chapterIndex);
  }

  // ── Export ──

  /// Export all bookmarks for this book.
  ///
  /// Returns a success/failure result with an optional output path.
  Future<ReaderBookmarkExportResult> export({
    required String bookAuthor,
    required bool markdown,
  }) async {
    final all = _repo.getBookmarksForBook(_bookId);
    if (markdown) {
      return _exportService.exportMarkdown(
        bookTitle: _bookTitle,
        bookAuthor: bookAuthor,
        bookmarks: all,
      );
    }
    return _exportService.exportJson(
      bookTitle: _bookTitle,
      bookAuthor: bookAuthor,
      bookmarks: all,
    );
  }

  /// Compose a bookmark preview string from user input.
  static String composePreview({
    required String bookText,
    required String note,
  }) {
    final trimmedText = bookText.trim();
    final trimmedNote = note.trim();
    if (trimmedText.isEmpty) return trimmedNote;
    if (trimmedNote.isEmpty) return trimmedText;
    return '$trimmedText\n\n笔记：$trimmedNote';
  }
}
