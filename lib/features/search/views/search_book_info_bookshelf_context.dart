// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoBookshelfContext on SearchBookInfoViewState {
  List<TocItem> _loadStoredToc(String bookId) {
    final chapters = _chapterRepo.getChaptersForBook(bookId)
      ..sort((a, b) => a.index.compareTo(b.index));
    return chapters
        .map(
          (chapter) => TocItem(
            index: chapter.index,
            name: chapter.title,
            url: (chapter.url ?? '').trim(),
            wordCount: _resolveStoredChapterWordCount(chapter.content),
          ),
        )
        .toList(growable: false);
  }

  Book? _resolveCachedBookshelfBook() {
    final explicit = widget.bookshelfBook;
    if (explicit != null) {
      final preferredId = (_bookId ?? '').trim();
      if (preferredId.isNotEmpty) {
        final byPreferredId = _bookRepo.getBookById(preferredId);
        if (byPreferredId != null) return byPreferredId;
      }
      return _bookRepo.getBookById(explicit.id) ?? explicit;
    }

    final id = (_bookId ?? '').trim();
    if (id.isNotEmpty) {
      final byId = _bookRepo.getBookById(id);
      if (byId != null) return byId;
    }

    final targetName = _activeResult.name.trim();
    final targetAuthor = _activeResult.author.trim();
    final targetBookUrl = _activeResult.bookUrl.trim();

    if (targetName.isEmpty && targetAuthor.isEmpty && targetBookUrl.isEmpty) {
      return null;
    }

    for (final item in _bookRepo.getAllBooks()) {
      if (targetName.isNotEmpty &&
          targetAuthor.isNotEmpty &&
          item.title.trim() == targetName &&
          item.author.trim() == targetAuthor) {
        return item;
      }
      if (targetBookUrl.isNotEmpty &&
          (item.bookUrl ?? '').trim() == targetBookUrl) {
        return item;
      }
    }
    return null;
  }

  BookSource? _resolveCachedBookSource(Book shelfBook) {
    final sourceUrl = (shelfBook.sourceUrl ?? shelfBook.sourceId ?? '').trim();
    if (sourceUrl.isNotEmpty) {
      final source = _sourceRepo.getSourceByUrl(sourceUrl);
      if (source != null) return source;
    }
    return _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
  }

  bool _applyCachedBookshelfContext({
    required Book? shelfBook,
    required List<TocItem> cachedToc,
  }) {
    if (shelfBook == null || cachedToc.isEmpty) return false;
    if (!mounted) return true;

    _refreshBookshelfState();
    setState(() {
      _source = _resolveCachedBookSource(shelfBook);
      _detail = _buildFallbackDetail(shelfBook);
      _toc = cachedToc;
      _loading = false;
      _loadingToc = false;
      _error = null;
      _tocError = null;
    });
    return true;
  }

  String? _resolveStoredChapterWordCount(String? content) {
    final words = (content ?? '').length;
    if (words <= 0) return null;
    if (words > 10000) {
      final value = (words / 10000.0)
          .toStringAsFixed(1)
          .replaceFirst(RegExp(r'\.0$'), '');
      return '$value万字';
    }
    return '$words字';
  }

  List<Chapter> _buildStoredChapters({
    required String bookId,
    required List<TocItem> toc,
  }) {
    final previousByUrl = <String, Chapter>{};
    for (final chapter in _chapterRepo.getChaptersForBook(bookId)) {
      final url = (chapter.url ?? '').trim();
      if (url.isEmpty) continue;
      previousByUrl[url] = chapter;
    }

    final chapters = <Chapter>[];
    final seen = <String>{};
    for (final item in toc) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      if (!seen.add(url)) continue;

      final previous = previousByUrl[url];
      final index = chapters.length;
      chapters.add(
        Chapter(
          id: SearchBookInfoViewState._uuid.v5(
            Namespace.url.value,
            '$bookId|$index|$url',
          ),
          bookId: bookId,
          title: title,
          url: url,
          index: index,
          isDownloaded: previous?.isDownloaded ?? false,
          content: previous?.content,
        ),
      );
    }
    return chapters;
  }

  Future<_BookshelfTocCacheResult> _cacheFetchedBookshelfToc({
    required String bookId,
    required List<TocItem> remoteToc,
  }) async {
    if (remoteToc.isEmpty) {
      return (
        toc: const <TocItem>[],
        error: '目录为空（书架缓存中无章节，请先刷新目录）',
      );
    }
    final chapters = _buildStoredChapters(bookId: bookId, toc: remoteToc);
    if (chapters.isEmpty) {
      ExceptionLogService().record(
        node: 'search_book_info.load_context.cache_bookshelf_toc',
        message: '目录落库失败',
        error: '章节为空',
        context: <String, dynamic>{
          'bookId': bookId,
          'remoteTocCount': remoteToc.length,
        },
      );
      return (
        toc: remoteToc,
        error: '目录解析失败：章节名或章节链接为空',
      );
    }
    try {
      await _chapterRepo.clearChaptersForBook(bookId);
      await _chapterRepo.addChapters(chapters);
      final stored = _loadStoredToc(bookId);
      return (toc: stored.isEmpty ? remoteToc : stored, error: null);
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'search_book_info.load_context.cache_bookshelf_toc',
        message: '目录落库失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'bookId': bookId,
          'remoteTocCount': remoteToc.length,
          'chapterCount': chapters.length,
        },
      );
      return (
        toc: remoteToc,
        error: '目录写入失败：${_compactReason(e.toString())}',
      );
    }
  }

  BookDetail _buildFallbackDetail(Book book) {
    return BookDetail(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: book.intro ?? '',
      kind: '',
      lastChapter: (book.latestChapter ?? '').trim(),
      updateTime: '',
      wordCount: '',
      tocUrl: '',
      bookUrl: (book.bookUrl ?? '').trim(),
    );
  }

  Future<List<TocItem>> _fetchTocWithFallback({
    required BookSource source,
    required String primaryTocUrl,
    required String fallbackTocUrl,
  }) async {
    var toc = await _engine.getToc(
      source,
      primaryTocUrl,
      clearRuntimeVariables: false,
    );
    if (toc.isNotEmpty) return toc;

    final normalizedPrimary = primaryTocUrl.trim();
    final normalizedFallback = fallbackTocUrl.trim();
    if (normalizedFallback.isEmpty || normalizedFallback == normalizedPrimary) {
      return toc;
    }

    toc = await _engine.getToc(
      source,
      normalizedFallback,
      clearRuntimeVariables: false,
    );
    return toc;
  }

  void _refreshBookshelfState() {
    if (_isBookshelfEntry) {
      final preferredId = _bookId?.trim() ?? '';
      final fallbackId = widget.bookshelfBook!.id.trim();
      final id = preferredId.isNotEmpty ? preferredId : fallbackId;
      _bookId = id;
      _inBookshelf = _bookRepo.hasBook(id);
      return;
    }

    _bookId = _addService.buildBookId(_activeResult);
    _inBookshelf = _addService.isInBookshelf(_activeResult);
  }

  void _restoreBookMenuSwitches() {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) return;
    _allowUpdate = _settingsService.getBookCanUpdate(id);
    _splitLongChapter = _settingsService.getBookSplitLongChapter(id);
  }
}
