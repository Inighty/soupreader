// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoShelfActions on SearchBookInfoViewState {
  Future<bool> _refreshLocalBookshelfBook({
    bool force = false,
    bool? splitLongChapter,
    bool showSuccessToast = true,
    String? txtTocRuleRegex,
  }) async {
    if (_loadingToc && !force) return false;
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      await _loadContext();
      return true;
    }

    final storedBook = _bookRepo.getBookById(id);
    if (storedBook == null || !storedBook.isLocal) {
      await _refreshBookshelfToc();
      return true;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _loadingToc = true;
        _error = null;
        _tocError = null;
      });
    }

    String? refreshError;
    try {
      final preferredTxtCharset =
          await _readerCharsetService.getBookCharset(id);
      final refreshResult = await SearchBookInfoRefreshHelper.refreshLocalBook(
        book: storedBook,
        preferredTxtCharset: preferredTxtCharset,
        splitLongChapter:
            splitLongChapter ?? _settingsService.getBookSplitLongChapter(id),
        txtTocRuleRegex: txtTocRuleRegex ?? _resolveBookTxtTocRuleRegex(id),
      );
      await _chapterRepo.clearChaptersForBook(id);
      await _chapterRepo.addChapters(refreshResult.chapters);
      await _bookRepo.updateBook(refreshResult.book);
      final charset = (refreshResult.charset ?? '').trim();
      if (charset.isNotEmpty) {
        await _readerCharsetService.setBookCharset(id, charset);
      }
    } catch (error) {
      refreshError = _compactReason(error.toString(), maxLength: 180);
    }

    final latestBook = _bookRepo.getBookById(id) ?? storedBook;
    final localToc = _loadStoredToc(id);
    if (!mounted) return refreshError == null;

    setState(() {
      _syncDisplayFromStoredBook(latestBook);
      _source = null;
      _toc = localToc;
      _loading = false;
      _loadingToc = false;
      _error = null;
      _tocError =
          localToc.isEmpty ? (refreshError ?? '目录为空（书架缓存中无章节，请先刷新目录）') : null;
    });

    if (localToc.isNotEmpty && refreshError == null && showSuccessToast) {
      unawaited(
          showAppToast(context, message: '目录已刷新（共 ${localToc.length} 章）'));
    } else if (refreshError != null) {
      _showMessage(refreshError);
    }
    return refreshError == null;
  }

  String? _normalizeLocalFilePath(String? rawValue) {
    final raw = (rawValue ?? '').trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return raw;
    if (uri.scheme.toLowerCase() != 'file') return null;
    try {
      final filePath = uri.toFilePath().trim();
      if (filePath.isEmpty) return null;
      return filePath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteFileIfExists(String? filePath) async {
    final normalized = (filePath ?? '').trim();
    if (normalized.isEmpty) return;
    try {
      final file = File(normalized);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.remove_shelf.delete_file',
        message: '移出书架时删除本地文件失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'filePath': normalized},
      );
    }
  }

  Future<void> _deleteLocalBookArtifacts({
    required Book book,
    required bool deleteOriginal,
  }) async {
    final coverPath = _normalizeLocalFilePath(book.coverUrl);
    await _deleteFileIfExists(coverPath);
    if (!deleteOriginal) return;
    final localPath = _normalizeLocalFilePath(book.localPath);
    final originalPath = localPath ?? _normalizeLocalFilePath(book.bookUrl);
    await _deleteFileIfExists(originalPath);
  }

  Future<void> _removeFromShelf({
    required String bookId,
    required bool deleteOriginal,
  }) async {
    final stored = _bookRepo.getBookById(bookId);
    await _bookRepo.deleteBook(bookId);
    if (stored != null && stored.isLocal) {
      await _deleteLocalBookArtifacts(
        book: stored,
        deleteOriginal: deleteOriginal,
      );
    }
  }

  int _resolveReadStartChapter() {
    if (!_inBookshelf) return 0;
    final id = _bookId?.trim() ?? '';
    if (id.isEmpty) return 0;
    final stored = _bookRepo.getBookById(id);
    if (stored == null) return 0;
    final chapterCount = _chapterRepo.getChaptersForBook(id).length;
    final maxIndex = chapterCount > 0
        ? chapterCount - 1
        : math.max(stored.totalChapters - 1, 0);
    return stored.currentChapter.clamp(0, maxIndex).toInt();
  }

  Future<void> _toggleShelf() async {
    if (_shelfBusy) return;
    setState(() => _shelfBusy = true);
    try {
      if (_inBookshelf) {
        final id = _bookId;
        if (id == null || id.trim().isEmpty) return;
        final deleteOriginal = _settingsService.getDeleteBookOriginal();
        await _removeFromShelf(
          bookId: id.trim(),
          deleteOriginal: deleteOriginal,
        );
        if (!mounted) return;
        setState(() {
          _inBookshelf = false;
        });
        return;
      }

      if (!_canFetchOnlineDetail) return;

      final addResult = await _addToShelfLikeLegado();
      if (!mounted) return;
      setState(() {
        _inBookshelf = addResult.success || addResult.alreadyExists;
        if (addResult.bookId != null && addResult.bookId!.trim().isNotEmpty) {
          _bookId = addResult.bookId;
        }
        if (_inBookshelf) {
          final id = _bookId?.trim() ?? '';
          if (id.isNotEmpty) {
            _allowUpdate = _settingsService.getBookCanUpdate(id);
            _splitLongChapter = _settingsService.getBookSplitLongChapter(id);
          }
        }
      });
    } finally {
      if (mounted) {
        setState(() => _shelfBusy = false);
      }
    }
  }
}
