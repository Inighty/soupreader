// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoContextModels on SearchBookInfoViewState {
  List<Chapter> _buildChaptersFromCurrentToc(String bookId) {
    final seen = <String>{};
    final chapters = <Chapter>[];
    for (final item in _toc) {
      final title = item.name.trim();
      final url = item.url.trim();
      if (title.isEmpty || url.isEmpty) continue;
      if (!seen.add(url)) continue;
      final id = SearchBookInfoViewState._uuid.v5(
        Namespace.url.value,
        '$bookId|${chapters.length}|$url',
      );
      chapters.add(
        Chapter(
          id: id,
          bookId: bookId,
          title: title,
          url: url,
          index: chapters.length,
        ),
      );
    }
    return chapters;
  }

  List<Chapter> _buildEphemeralChapters(String sessionId) {
    return _buildChaptersFromCurrentToc(sessionId);
  }

  Book _buildShelfBook({
    required String bookId,
    required BookSource source,
    required int chapterCount,
  }) {
    final resolvedBookUrl = _pickFirstNonEmpty([
      _detail?.bookUrl ?? '',
      _activeResult.bookUrl,
    ]);
    return Book(
      id: bookId,
      title: _displayName,
      author: _displayAuthor,
      coverUrl: _displayCoverUrl,
      intro: _displayIntro,
      sourceId: source.bookSourceUrl,
      sourceUrl: source.bookSourceUrl,
      bookUrl: resolvedBookUrl,
      latestChapter: _pickFirstNonEmpty([
        _detail?.lastChapter ?? '',
        _activeResult.lastChapter,
      ]),
      totalChapters: chapterCount,
      currentChapter: 0,
      readProgress: 0,
      lastReadTime: null,
      addedTime: DateTime.now(),
      isLocal: false,
      localPath: null,
    );
  }

  Future<BookAddResult> _addToShelfLikeLegado() async {
    try {
      final source =
          _source ?? _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
      if (source == null) {
        return BookAddResult.error('书源不存在或已被删除');
      }
      final bookId = _addService.buildBookId(_activeResult);
      if (bookId == null) {
        return BookAddResult.error('书源不存在或已被删除');
      }
      if (_bookRepo.hasBook(bookId)) {
        return BookAddResult.alreadyExists(bookId);
      }

      final chapters = _buildChaptersFromCurrentToc(bookId);
      final book = _buildShelfBook(
        bookId: bookId,
        source: source,
        chapterCount: chapters.length,
      );
      await _bookRepo.addBook(book);
      if (chapters.isNotEmpty) {
        await _chapterRepo.addChapters(chapters);
      }

      final storedChapterCount =
          await _chapterRepo.countChaptersForBook(bookId);
      if (storedChapterCount != book.totalChapters) {
        await _bookRepo.updateBook(
          book.copyWith(totalChapters: storedChapterCount),
        );
      }
      return BookAddResult.success(bookId);
    } catch (error) {
      return BookAddResult.error('导入失败: ${_compactReason(error.toString())}');
    }
  }
}
