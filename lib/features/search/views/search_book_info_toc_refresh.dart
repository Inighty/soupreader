// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoTocRefresh on SearchBookInfoViewState {
  Future<void> _refreshBookshelfToc() async {
    if (_loadingToc) return;
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      await _loadContext();
      return;
    }
    if (!_canFetchOnlineDetail) {
      _showMessage('当前书籍缺少详情链接，无法刷新目录');
      return;
    }

    final source =
        _source ?? _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
    if (source == null) {
      _showMessage('书源不存在或已被删除，无法刷新目录');
      return;
    }

    if (mounted) {
      setState(() {
        _loadingToc = true;
        _tocError = null;
      });
    }

    BookDetail? detail = _detail;
    List<TocItem> remoteToc = const <TocItem>[];
    String? tocRefreshError;

    try {
      final refreshedDetail = await _engine.getBookInfo(
        source,
        _activeResult.bookUrl,
        clearRuntimeVariables: true,
      );
      if (refreshedDetail != null) {
        detail = refreshedDetail;
      }
    } catch (_) {
      // 详情刷新失败不阻断目录刷新流程，保持已有详情字段。
    }

    final primaryTocUrl = (detail?.tocUrl.trim().isNotEmpty == true)
        ? detail!.tocUrl.trim()
        : _activeResult.bookUrl.trim();
    if (primaryTocUrl.isEmpty) {
      tocRefreshError = '目录地址为空，无法刷新目录';
    } else {
      try {
        remoteToc = await _fetchTocWithFallback(
          source: source,
          primaryTocUrl: primaryTocUrl,
          fallbackTocUrl: _activeResult.bookUrl,
        );
        if (remoteToc.isEmpty) {
          tocRefreshError = '目录为空（可能是 ruleToc 不匹配）';
        }
      } catch (e) {
        tocRefreshError = '目录解析失败：${_compactReason(e.toString())}';
      }
    }

    if (remoteToc.isNotEmpty) {
      final chapters = _buildStoredChapters(bookId: id, toc: remoteToc);
      if (chapters.isEmpty) {
        tocRefreshError = '目录解析失败：章节名或章节链接为空';
      } else {
        try {
          await _chapterRepo.clearChaptersForBook(id);
          await _chapterRepo.addChapters(chapters);

          final storedBook = _bookRepo.getBookById(id);
          if (storedBook != null) {
            final maxChapter = chapters.length - 1;
            await _bookRepo.updateBook(
              storedBook.copyWith(
                title: _pickFirstNonEmpty(
                        [detail?.name ?? '', storedBook.title]) ??
                    storedBook.title,
                author: _pickFirstNonEmpty(
                        [detail?.author ?? '', storedBook.author]) ??
                    storedBook.author,
                coverUrl: _pickFirstNonEmpty(
                      [detail?.coverUrl ?? '', storedBook.coverUrl ?? ''],
                    ) ??
                    storedBook.coverUrl,
                intro: _pickFirstNonBlankPreserve(
                      [detail?.intro, storedBook.intro],
                    ) ??
                    storedBook.intro,
                sourceId: source.bookSourceUrl,
                sourceUrl: source.bookSourceUrl,
                bookUrl: _pickFirstNonEmpty([
                      detail?.bookUrl ?? '',
                      _activeResult.bookUrl,
                      storedBook.bookUrl ?? '',
                    ]) ??
                    storedBook.bookUrl,
                latestChapter: _pickFirstNonEmpty([
                      detail?.lastChapter ?? '',
                      remoteToc.last.name,
                      storedBook.latestChapter ?? '',
                    ]) ??
                    storedBook.latestChapter,
                totalChapters: chapters.length,
                currentChapter:
                    storedBook.currentChapter.clamp(0, maxChapter).toInt(),
              ),
            );
          }
        } catch (e) {
          tocRefreshError = '目录写入失败：${_compactReason(e.toString())}';
        }
      }
    }

    final localToc = _loadStoredToc(id);
    if (!mounted) return;
    setState(() {
      _source = source;
      if (detail != null) {
        _detail = detail;
      }
      _toc = localToc;
      _loadingToc = false;
      _tocError = localToc.isEmpty
          ? (tocRefreshError ?? '目录为空（书架缓存中无章节，请先刷新目录）')
          : null;
    });

    if (localToc.isNotEmpty && tocRefreshError == null) {
      unawaited(
          showAppToast(context, message: '目录已刷新（共 ${localToc.length} 章）'));
    } else if (tocRefreshError != null) {
      _showMessage(tocRefreshError);
    }
  }
}
