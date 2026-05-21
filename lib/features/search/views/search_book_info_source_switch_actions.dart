// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoSourceSwitchActions on SearchBookInfoViewState {
  Future<void> _switchSource() async {
    if (_switchingSource) return;

    if (!_canFetchOnlineDetail) {
      _showMessage('当前书籍缺少详情链接，无法换源');
      return;
    }

    final keyword = _displayName.trim();
    final authorKeyword = _displayAuthor.trim();
    if (keyword.isEmpty) {
      _showMessage('书名为空，无法换源');
      return;
    }

    final enabledSources = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled)
        .toList(growable: false);
    if (enabledSources.isEmpty) {
      _showMessage('没有可用书源');
      return;
    }
    final orderedSources = enabledSources
        .asMap()
        .entries
        .toList(growable: false)
      ..sort((a, b) {
        final orderCompare = a.value.customOrder.compareTo(b.value.customOrder);
        if (orderCompare != 0) return orderCompare;
        return a.key.compareTo(b.key);
      });
    final sortedEnabledSources =
        orderedSources.map((entry) => entry.value).toList(growable: false);

    setState(() => _switchingSource = true);
    final searchDelaySeconds = _normalizeChangeSourceDelaySeconds(
      _changeSourceDelaySeconds,
    );
    final searchResults = <SearchResult>[];
    for (var index = 0; index < sortedEnabledSources.length; index++) {
      final source = sortedEnabledSources[index];
      if (index > 0 && searchDelaySeconds > 0) {
        await Future<void>.delayed(Duration(seconds: searchDelaySeconds));
      }
      try {
        final list = await _engine.search(
          source,
          keyword,
          filter: (name, author) {
            if (name != keyword) return false;
            if (authorKeyword.isEmpty) return true;
            return author.contains(authorKeyword);
          },
        );
        for (final item in list) {
          searchResults.add(_copyResultWithSource(item, source));
        }
      } catch (_) {
        // 单源失败隔离，不中断全局候选搜集。
      }
    }

    final currentBook = Book(
      id: _bookId ?? _buildEphemeralSessionId(),
      title: _displayName,
      author: _displayAuthor,
      sourceId: _activeResult.sourceUrl,
      sourceUrl: _activeResult.sourceUrl,
      bookUrl: _activeResult.bookUrl,
      latestChapter: _pickFirstNonEmpty([
        _detail?.lastChapter ?? '',
        _activeResult.lastChapter,
      ]),
      totalChapters: _toc.length,
      currentChapter: 0,
      readProgress: 0,
      isLocal: false,
    );

    final candidates = ReaderSourceSwitchHelper.buildCandidates(
      currentBook: currentBook,
      enabledSources: sortedEnabledSources,
      searchResults: searchResults,
    );

    if (!mounted) return;
    setState(() => _switchingSource = false);

    if (candidates.isEmpty) {
      _showMessage('未找到可切换的匹配书源');
      return;
    }

    final selected = await showSourceSwitchCandidateSheet(
      context: context,
      keyword: keyword,
      candidates: candidates,
      loadTocEnabled: false,
      changeSourceDelaySeconds: _changeSourceDelaySeconds,
      onChangeSourceDelayChanged: _handleChangeSourceDelayChanged,
    );
    if (selected == null) return;
    await _applySourceCandidate(selected);
  }

  Future<void> _applySourceCandidate(
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final previousResult = _activeResult;
    final previousBookId = (_bookId ?? '').trim();
    final previousBook = (_inBookshelf && previousBookId.isNotEmpty)
        ? _bookRepo.getBookById(previousBookId)
        : null;
    final previousChapters = previousBook == null
        ? const <Chapter>[]
        : _loadStoredChapters(previousBook.id);
    final nextResult = _copyResultWithSource(candidate.book, candidate.source);

    if (_normalize(nextResult.sourceUrl) ==
            _normalize(previousResult.sourceUrl) &&
        _normalize(nextResult.bookUrl) == _normalize(previousResult.bookUrl)) {
      _showMessage('已是当前书源');
      return;
    }

    setState(() {
      _activeResult = nextResult;
      _detail = null;
      _toc = const <TocItem>[];
      _error = null;
      _tocError = null;
      _loading = true;
      _loadingToc = true;
    });

    final loaded = await _loadContext(silent: true, forceRemote: true);
    if (!loaded) {
      if (!mounted) return;
      setState(() {
        _activeResult = previousResult;
        if (previousBookId.isNotEmpty) {
          _bookId = previousBookId;
          _inBookshelf = _bookRepo.hasBook(previousBookId);
        }
      });
      await _loadContext(forceRemote: true);
      _showMessage('换源失败，已回退到原书源');
      return;
    }

    if (previousBook != null) {
      final migrated = await _migrateBookshelfBookAfterSourceSwitch(
        previousBook: previousBook,
        previousChapters: previousChapters,
      );
      if (!migrated) {
        if (!mounted) return;
        setState(() {
          _activeResult = previousResult;
          _bookId = previousBookId;
          _inBookshelf = _bookRepo.hasBook(previousBookId);
        });
        await _loadContext(forceRemote: true);
        _showMessage('换源失败，已回退到原书源');
        return;
      }
    }

    _removeSessionCacheEntry(_buildSessionCacheKeyForResult(previousResult));
    if (!mounted) return;
    unawaited(showAppToast(context,
        message: '已切换到：${candidate.source.bookSourceName}'));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}
