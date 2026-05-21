// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoReaderActions on SearchBookInfoViewState {
  Future<void> _openReader({int initialChapter = 0}) async {
    if (_inBookshelf) {
      final id = _bookId;
      if (id != null && id.trim().isNotEmpty) {
        final stored = _bookRepo.getBookById(id);
        if (stored != null) {
          final localChapters = _chapterRepo.getChaptersForBook(stored.id)
            ..sort((a, b) => a.index.compareTo(b.index));
          if (localChapters.isEmpty) {
            if (!mounted) return;
            setState(() {
              _toc = const <TocItem>[];
              _tocError = '目录为空（书架缓存中无章节，请先刷新目录）';
            });
            _showMessage('目录为空，请先刷新目录');
            return;
          }
          final maxChapter = localChapters.length - 1;
          if (stored.totalChapters != localChapters.length ||
              stored.currentChapter > maxChapter) {
            await _bookRepo.updateBook(
              stored.copyWith(
                totalChapters: localChapters.length,
                currentChapter:
                    stored.currentChapter.clamp(0, maxChapter).toInt(),
              ),
            );
          }
          if (!mounted) return;
          await Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (_) => ReaderView(
                bookId: stored.id,
                bookTitle: stored.title,
                initialChapter: initialChapter.clamp(0, maxChapter),
              ),
            ),
          );
          if (!mounted) return;
          setState(_refreshBookshelfState);
          return;
        }
      }
      if (!mounted) return;
      setState(() => _inBookshelf = false);
    }

    if (_toc.isEmpty) {
      final tip = _loadingToc ? '目录还在加载中，请稍后' : (_tocError ?? '目录为空，无法开始阅读');
      _showMessage(tip);
      return;
    }

    final sessionId = _buildEphemeralSessionId();
    final chapters = _buildEphemeralChapters(sessionId);
    if (chapters.isEmpty) {
      _showMessage('目录为空，无法开始阅读');
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => ReaderView.ephemeral(
          sessionId: sessionId,
          bookTitle: _displayName,
          initialChapter: initialChapter.clamp(0, chapters.length - 1),
          initialBookAuthor: _displayAuthor,
          initialBookCoverUrl: _displayCoverUrl,
          initialSourceUrl: _activeResult.sourceUrl,
          initialSourceName: _displaySourceName,
          initialChapters: chapters,
        ),
      ),
    );

    if (!mounted) return;
    setState(_refreshBookshelfState);
  }

  Future<void> _openToc() async {
    var tocToOpen = _toc;
    if (_inBookshelf && _bookId != null) {
      final localToc = _loadStoredToc(_bookId!.trim());
      tocToOpen = localToc;
      if (mounted) {
        setState(() {
          _toc = localToc;
          _tocError = localToc.isEmpty ? '目录为空（书架缓存中无章节，请先刷新目录）' : null;
        });
      }
    }

    if (tocToOpen.isEmpty) {
      final tip = _loadingToc ? '目录还在加载中，请稍后' : (_tocError ?? '目录为空，无法打开目录');
      _showMessage(tip);
      return;
    }

    List<String> displayTitles;
    try {
      displayTitles = await _buildTocDisplayTitles(tocToOpen);
    } catch (_) {
      displayTitles =
          tocToOpen.map((item) => item.name).toList(growable: false);
    }
    if (!mounted) return;
    final showTxtTocRuleAction = _inBookshelf && _isLocalTxtBook();
    final showSplitLongChapterAction = showTxtTocRuleAction;
    const showUseReplaceAction = true;
    const showLoadWordCountAction = true;
    final showExportBookmarkAction =
        _inBookshelf && (_bookId?.trim().isNotEmpty ?? false);

    final selected = await Navigator.of(context, rootNavigator: true).push<int>(
      CupertinoPageRoute(
        builder: (_) => SearchBookTocView(
          bookTitle: _displayName,
          toc: tocToOpen,
          displayTitles: displayTitles,
          sourceName: _displaySourceName,
          showTxtTocRuleAction: showTxtTocRuleAction,
          showSplitLongChapterAction: showSplitLongChapterAction,
          splitLongChapterEnabled: _splitLongChapter,
          showUseReplaceAction: showUseReplaceAction,
          useReplaceEnabled: _tocUiUseReplace,
          showLoadWordCountAction: showLoadWordCountAction,
          loadWordCountEnabled: _tocUiLoadWordCount,
          showExportBookmarkAction: showExportBookmarkAction,
          onEditTocRule:
              showTxtTocRuleAction ? _handleEditTxtTocRuleFromToc : null,
          onToggleSplitLongChapter: showSplitLongChapterAction
              ? _handleToggleSplitLongChapterFromToc
              : null,
          onToggleUseReplace: _handleToggleUseReplaceFromToc,
          onToggleLoadWordCount: _handleToggleLoadWordCountFromToc,
          onExportBookmark:
              showExportBookmarkAction ? _handleExportBookmarkFromToc : null,
          onExportBookmarkMarkdown: showExportBookmarkAction
              ? _handleExportBookmarkMarkdownFromToc
              : null,
        ),
      ),
    );
    if (selected == null) return;
    await _openReader(initialChapter: selected);
  }

  Future<void> _handleExportBookmarkFromToc() async {
    final feedback = await _exportBookmarksFromToc(markdown: false);
    if (!mounted || feedback == null) return;
    final message = feedback.trim();
    if (message.isEmpty) return;
    _showMessage(message);
  }

  Future<void> _handleExportBookmarkMarkdownFromToc() async {
    final feedback = await _exportBookmarksFromToc(markdown: true);
    if (!mounted || feedback == null) return;
    final message = feedback.trim();
    if (message.isEmpty) return;
    _showMessage(message);
  }

  Future<String?> _exportBookmarksFromToc({required bool markdown}) async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      return '当前书籍不支持导出书签';
    }

    try {
      await _bookmarkRepo.init();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.toc.export_bookmark.init',
        message: '导出失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': id,
          'bookTitle': _displayName,
          'format': markdown ? 'md' : 'json',
        },
      );
      return '导出失败：${_compactReason(error.toString())}';
    }

    final bookmarks = _bookmarkRepo.getBookmarksForBook(id);
    final result = markdown
        ? await _bookmarkExportService.exportMarkdown(
            bookTitle: _displayName,
            bookAuthor: _displayAuthor,
            bookmarks: bookmarks,
          )
        : await _bookmarkExportService.exportJson(
            bookTitle: _displayName,
            bookAuthor: _displayAuthor,
            bookmarks: bookmarks,
          );
    if (result.cancelled) return null;
    if (result.success) {
      if (kIsWeb) {
        final webMessage = result.message?.trim() ?? '';
        if (webMessage.isNotEmpty) return webMessage;
      }
      return '导出成功';
    }
    final message = (result.message ?? '导出失败').trim();
    ExceptionLogService().record(
      node: 'search_book_info.toc.export_bookmark',
      message: '导出失败',
      error: message,
      context: <String, dynamic>{
        'bookId': id,
        'bookTitle': _displayName,
        'format': markdown ? 'md' : 'json',
      },
    );
    return message;
  }
}
