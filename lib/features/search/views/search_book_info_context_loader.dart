// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoContextLoader on SearchBookInfoViewState {
  Future<bool> _loadContext({
    bool silent = false,
    bool forceRemote = false,
  }) async {
    _refreshBookshelfState();
    _restoreBookMenuSwitches();
    _tocUiUseReplace = _settingsService.getTocUiUseReplace();
    _tocUiLoadWordCount = _settingsService.getTocUiLoadWordCount();
    final cacheKey = _buildSessionCacheKey();
    final sessionCache = forceRemote ? null : _readSessionCacheEntry(cacheKey);

    if (!silent && mounted) {
      if (sessionCache != null) {
        setState(() {
          _source = _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
          _detail = sessionCache.detail;
          _toc = sessionCache.toc;
          _loading = false;
          _loadingToc = false;
          _error = null;
          _tocError = null;
        });
      } else {
        setState(() {
          _loading = true;
          _loadingToc = true;
          _error = null;
          _tocError = null;
        });
      }
    }

    if (!forceRemote &&
        !_inBookshelf &&
        sessionCache != null &&
        sessionCache.toc.isNotEmpty) {
      return true;
    }

    final shelfBook = _resolveCachedBookshelfBook();
    final canReuseShelfCache =
        shelfBook != null && _matchesActiveResult(shelfBook);
    final cachedShelfToc = (shelfBook == null || !canReuseShelfCache)
        ? const <TocItem>[]
        : _loadStoredToc(shelfBook.id);

    // 对齐 legado：进入详情优先复用书架已缓存目录，避免每次进页都发网络请求。
    if (canReuseShelfCache &&
        _applyCachedBookshelfContext(
          shelfBook: shelfBook,
          cachedToc: cachedShelfToc,
        )) {
      if (mounted) {
        _writeSessionCacheEntry(
          key: cacheKey,
          detail: _detail,
          toc: _toc,
        );
      }
      return true;
    }

    if (shelfBook != null && canReuseShelfCache && !_canFetchOnlineDetail) {
      final sourceUrl =
          (shelfBook.sourceUrl ?? shelfBook.sourceId ?? '').trim();
      final source =
          sourceUrl.isEmpty ? null : _sourceRepo.getSourceByUrl(sourceUrl);
      final toc = cachedShelfToc;

      if (!mounted) return false;
      _refreshBookshelfState();
      setState(() {
        _source = source;
        _detail = _buildFallbackDetail(shelfBook);
        _toc = toc;
        _loading = false;
        _loadingToc = false;
        _error = '该书缺少详情链接，已降级为书架缓存信息模式';
        _tocError = toc.isEmpty ? '目录为空（书架缓存中无章节）' : null;
      });
      _writeSessionCacheEntry(
        key: cacheKey,
        detail: _detail,
        toc: _toc,
      );
      return false;
    }

    final source = _sourceRepo.getSourceByUrl(_activeResult.sourceUrl);
    if (source == null) {
      if (!mounted) return false;
      _refreshBookshelfState();

      final fallbackBookId = _bookId?.trim() ?? '';
      final fallbackDetail =
          shelfBook != null ? _buildFallbackDetail(shelfBook) : null;
      final fallbackToc = shelfBook != null
          ? cachedShelfToc
          : (_inBookshelf && fallbackBookId.isNotEmpty)
              ? _loadStoredToc(fallbackBookId)
              : const <TocItem>[];
      setState(() {
        _source = null;
        _detail = fallbackDetail;
        _toc = fallbackToc;
        _loading = false;
        _loadingToc = false;
        _error = shelfBook != null ? '书源不存在或已被删除，已展示书架缓存信息' : '书源不存在或已被删除';
        _tocError = fallbackToc.isEmpty ? '无法获取目录' : null;
      });
      _writeSessionCacheEntry(
        key: cacheKey,
        detail: _detail,
        toc: _toc,
      );
      return false;
    }

    BookDetail? detail;
    String? detailError;
    try {
      detail = await _engine.getBookInfo(
        source,
        _activeResult.bookUrl,
        clearRuntimeVariables: true,
      );
      if (detail == null) {
        detailError = '详情解析失败：未获取到可用字段';
      }
    } catch (e) {
      detailError = '详情解析失败：${_compactReason(e.toString())}';
    }

    final primaryTocUrl = (detail?.tocUrl.trim().isNotEmpty == true)
        ? detail!.tocUrl.trim()
        : _activeResult.bookUrl.trim();

    List<TocItem> toc = const <TocItem>[];
    String? tocError;
    try {
      toc = await _fetchTocWithFallback(
        source: source,
        primaryTocUrl: primaryTocUrl,
        fallbackTocUrl: _activeResult.bookUrl,
      );
      if (toc.isEmpty) {
        tocError = '目录为空（可能是 ruleToc 不匹配）';
      }
    } catch (e) {
      tocError = '目录解析失败：${_compactReason(e.toString())}';
    }

    if (!mounted) return false;

    _refreshBookshelfState();
    var resolvedToc = toc;
    var resolvedTocError = tocError;
    final shouldUseStoredBookshelfToc = _inBookshelf &&
        _bookId != null &&
        _bookId!.trim().isNotEmpty &&
        (shelfBook == null || canReuseShelfCache || !_isBookshelfEntry);
    if (shouldUseStoredBookshelfToc) {
      final id = _bookId!.trim();
      final localToc = _loadStoredToc(id);
      if (localToc.isNotEmpty) {
        resolvedToc = localToc;
        resolvedTocError = null;
      } else {
        final cacheResult = await _cacheFetchedBookshelfToc(
          bookId: id,
          remoteToc: toc,
        );
        resolvedToc = cacheResult.toc;
        resolvedTocError = resolvedToc.isEmpty
            ? (cacheResult.error ?? tocError)
            : cacheResult.error;
      }
    } else if (resolvedToc.isNotEmpty) {
      resolvedTocError = null;
    }
    final resolvedDetail =
        detail ?? (shelfBook != null ? _buildFallbackDetail(shelfBook) : null);
    setState(() {
      _source = source;
      _detail = resolvedDetail;
      _toc = resolvedToc;
      _loading = false;
      _loadingToc = false;
      _error = detailError;
      _tocError = resolvedToc.isEmpty ? resolvedTocError : null;
    });
    _writeSessionCacheEntry(
      key: cacheKey,
      detail: resolvedDetail,
      toc: resolvedToc,
    );

    return detailError == null;
  }
}
