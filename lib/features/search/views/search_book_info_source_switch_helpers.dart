// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoSourceSwitchHelpers on SearchBookInfoViewState {
  SearchResult _copyResultWithSource(SearchResult value, BookSource source) {
    return SearchResult(
      name: value.name,
      author: value.author,
      coverUrl: value.coverUrl,
      intro: value.intro,
      kind: value.kind,
      lastChapter: value.lastChapter,
      updateTime: value.updateTime,
      wordCount: value.wordCount,
      bookUrl: value.bookUrl,
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
    );
  }

  int _normalizeChangeSourceDelaySeconds(int seconds) {
    return seconds.clamp(0, 9999).toInt();
  }

  Future<void> _handleChangeSourceDelayChanged(int seconds) async {
    final normalized = _normalizeChangeSourceDelaySeconds(seconds);
    _changeSourceDelaySeconds = normalized;
    await _settingsService.saveBatchChangeSourceDelay(normalized);
  }

  List<Chapter> _loadStoredChapters(String bookId) {
    final chapters = _chapterRepo
        .getChaptersForBook(bookId)
        .toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
    return chapters;
  }

  String _resolveSwitchSourceChapterTitle({
    required Book previousBook,
    required List<Chapter> previousChapters,
  }) {
    if (previousChapters.isEmpty) {
      return _pickFirstNonEmpty(
            <String>[
              previousBook.latestChapter ?? '',
              _activeResult.lastChapter,
            ],
          ) ??
          '';
    }
    final safeIndex = previousBook.currentChapter
        .clamp(0, previousChapters.length - 1)
        .toInt();
    return previousChapters[safeIndex].title;
  }

  Future<bool> _migrateBookshelfBookAfterSourceSwitch({
    required Book previousBook,
    required List<Chapter> previousChapters,
  }) async {
    final source =
        _source ?? _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
    if (source == null) return false;

    final targetBookId = _addService.buildBookId(_activeResult)?.trim() ?? '';
    if (targetBookId.isEmpty) return false;

    final targetChapters =
        _buildStoredChapters(bookId: targetBookId, toc: _toc);
    if (targetChapters.isEmpty) return false;

    final currentChapterTitle = _resolveSwitchSourceChapterTitle(
      previousBook: previousBook,
      previousChapters: previousChapters,
    );
    final targetChapterIndex =
        ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: targetChapters,
      currentChapterTitle: currentChapterTitle,
      currentChapterIndex: previousBook.currentChapter,
      oldChapterCount: previousChapters.length,
    ).clamp(0, targetChapters.length - 1).toInt();

    final resolvedBookUrl = _resolveBookUrl().trim();
    final migratedBook = previousBook.copyWith(
      id: targetBookId,
      title: _displayName,
      author: _displayAuthor,
      coverUrl: _displayCoverUrl,
      intro: _displayIntro,
      sourceId: source.bookSourceUrl,
      sourceUrl: source.bookSourceUrl,
      bookUrl: resolvedBookUrl.isEmpty ? previousBook.bookUrl : resolvedBookUrl,
      latestChapter: _pickFirstNonEmpty(<String>[
        _detail?.lastChapter ?? '',
        targetChapters.last.title,
        previousBook.latestChapter ?? '',
      ]),
      totalChapters: targetChapters.length,
      currentChapter: targetChapterIndex,
    );

    final previousBookId = previousBook.id.trim();
    final sameBookId = previousBookId == targetBookId;
    if (!sameBookId && _bookRepo.hasBook(targetBookId)) {
      await _bookRepo.deleteBook(targetBookId);
    }
    if (sameBookId) {
      await _bookRepo.updateBook(migratedBook);
    } else {
      await _bookRepo.addBook(migratedBook);
    }
    await _chapterRepo.clearChaptersForBook(targetBookId);
    await _chapterRepo.addChapters(targetChapters);
    if (!sameBookId && previousBookId.isNotEmpty) {
      await _bookRepo.deleteBook(previousBookId);
    }

    if (!mounted) return true;
    final refreshedToc = _loadStoredToc(targetBookId);
    setState(() {
      _bookId = targetBookId;
      _inBookshelf = true;
      _syncDisplayFromStoredBook(migratedBook);
      _toc = refreshedToc;
      _tocError = refreshedToc.isEmpty ? '目录为空（书架缓存中无章节，请先刷新目录）' : null;
    });
    return true;
  }
}
