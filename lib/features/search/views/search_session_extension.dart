// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart' show SearchResult;
import '../../source/services/source/cover_loader.dart';
import 'search_view.dart';
import 'search_view_actions.dart';
import 'search_view_engine.dart';
import 'search_view_session_helpers.dart';

/// 搜索会话/分页拉取/历史词维护扩展，把 [SearchViewState] 中的大量
/// 方法以 extension 形式抽离主类，便于主文件瘦身。
extension SearchSessionExtension on SearchViewState {
  bool isSearchSessionActive(int sessionId) {
    return mounted && isSearching && runningSearchSessionId == sessionId;
  }

  int startSearchSession() {
    searchSessionSeed++;
    runningSearchSessionId = searchSessionSeed;
    return runningSearchSessionId;
  }

  void cancelOngoingSearch({bool updateState = true}) {
    isSearching = false;
    runningSearchSessionId = 0;
    searchingSource = '';
    hasMore = false;
    final tokens = activeCancelTokens.toList(growable: false);
    activeCancelTokens.clear();
    for (final token in tokens) {
      if (!token.isCancelled) token.cancel('search canceled');
    }
    if (updateState && mounted) setState(() {});
  }

  void onResultScroll() {
    if (!resultScrollController.hasClients) return;
    final position = resultScrollController.position;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining > 1.0) return;
    if (isSearching || !hasMore) return;
    if (currentKeyword.trim().isEmpty) return;
    if (displayResults.isEmpty) return;
    unawaited(loadNextPage());
  }

  Future<void> continueLoadMore() async {
    if (!showManualLoadMorePanel) return;
    await loadNextPage();
  }

  Future<void> loadNextPage() async {
    if (isSearching || !hasMore) return;
    if (sessionSources.isEmpty) return;
    if (currentKeyword.trim().isEmpty) return;
    final sessionId = runningSearchSessionId;
    if (sessionId == 0) return;
    final nextPage = currentPage + 1;
    setState(() {
      isSearching = true;
      completedSources = 0;
      searchingSource = '';
    });
    final pageHasMore = await runOnePage(
      searchSessionId: sessionId,
      sources: sessionSources,
      page: nextPage,
    );
    finishSearchPage(sessionId, pageHasMore, newPage: nextPage);
  }

  Future<void> doSearch() async {
    searchFocusNode.unfocus();
    final keyword = searchController.text.trim();
    if (keyword.isEmpty) return;

    final resolvedScopeState = resolveSearchScopeState();
    if (resolvedScopeState.resolvedScope.normalizedScope !=
        settings.searchScope) {
      await saveSettings(
        settings.copyWith(
          searchScope: resolvedScopeState.resolvedScope.normalizedScope,
        ),
      );
      if (!mounted) return;
    }

    final enabledSources = resolvedScopeState.sources;
    if (enabledSources.isEmpty) {
      showSearchMessage(context, '当前搜索范围没有启用书源，请先调整“搜索范围”。');
      return;
    }

    SourceCoverLoader.instance.clearMemoryCache();
    await saveHistoryKeyword(keyword);

    final cacheKey = cacheService.buildCacheKey(
      keyword: keyword,
      filterMode: normalizeSearchFilterMode(settings.searchFilterMode),
      scopeSourceUrls: enabledSources.map((item) => item.bookSourceUrl),
    );
    final cached = await cacheService.readCache(
      key: cacheKey,
      retentionDays: settings.searchCacheRetentionDays,
    );
    final cachedResults = cached?.results ?? const <SearchResult>[];

    cancelOngoingSearch(updateState: false);
    final searchSessionId = startSearchSession();
    currentKeyword = keyword;
    currentCacheKey = cacheKey;
    currentPage = 1;
    hasMore = true;
    sessionSources = enabledSources;
    aggregator.reset();
    aggregator.ingest(cachedResults);

    setState(() {
      isSearching = true;
      coverLoadStateByItem.clear();
      sourceIssues.clear();
      completedSources = 0;
      searchingSource = '';
      rebuildDisplayResults(keyword: keyword);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!resultScrollController.hasClients) return;
      resultScrollController.jumpTo(0);
    });

    final pageHasMore = await runOnePage(
      searchSessionId: searchSessionId,
      sources: enabledSources,
      page: currentPage,
    );
    finishSearchPage(searchSessionId, pageHasMore);
    unawaited(maybePromptEmptyResult());
  }

  void finishSearchPage(int sessionId, bool nextHasMore, {int? newPage}) {
    if (!isSearchSessionActive(sessionId)) return;
    if (newPage != null) currentPage = newPage;
    if (results.isNotEmpty && currentCacheKey.isNotEmpty) {
      unawaited(
          cacheService.writeCache(key: currentCacheKey, results: results));
    }
    setState(() {
      isSearching = false;
      searchingSource = '';
      hasMore = nextHasMore;
    });
  }

  Future<void> maybePromptEmptyResult() async {
    if (!mounted || isSearching || displayResults.isNotEmpty) return;
    if (currentKeyword.trim().isEmpty) return;
    final scope = resolveSearchScopeState().resolvedScope;
    if (scope.isAll) return;
    final scopeLabel = scope.display();
    if (isPrecisionSearchEnabled) {
      final confirm = await confirmSearchAction(
        context: context,
        title: '搜索结果为空',
        content: '$scopeLabel 搜索结果为空，是否关闭精准搜索并重试？',
        confirmText: '关闭并重试',
      );
      if (!confirm || !mounted) return;
      await saveSettings(
        settings.copyWith(searchFilterMode: SearchFilterMode.normal),
      );
      if (!mounted) return;
      await doSearch();
      return;
    }
    final confirm = await confirmSearchAction(
      context: context,
      title: '搜索结果为空',
      content: '$scopeLabel 搜索结果为空，是否切换到全部书源并重试？',
      confirmText: '切换并重试',
    );
    if (!confirm || !mounted) return;
    await saveSettings(settings.copyWith(searchScope: ''));
    if (!mounted) return;
    await doSearch();
  }

  Future<bool> runOnePage({
    required int searchSessionId,
    required List<BookSource> sources,
    required int page,
  }) {
    return runSearchPage(
      searchSessionId: searchSessionId,
      sources: sources,
      page: page,
      ctx: buildSearchRunContext(
        aggregator: aggregator,
        activeCancelTokens: activeCancelTokens,
        isSessionActive: isSearchSessionActive,
        setSearchingSource: (name) {
          if (mounted) setState(() => searchingSource = name);
        },
        appendIssue: (issue) {
          if (mounted) setState(() => sourceIssues.add(issue));
        },
        incrementCompleted: () {
          if (mounted) setState(() => completedSources++);
        },
        applyIngest: () {
          if (mounted) {
            setState(() => rebuildDisplayResults(keyword: currentKeyword));
          }
        },
        currentKeyword: currentKeyword,
        filterMode: normalizeSearchFilterMode(settings.searchFilterMode),
        concurrency: settings.searchConcurrency,
      ),
    );
  }

  Future<void> saveHistoryKeyword(String keyword) async {
    final history = await cacheService.saveHistoryKeyword(keyword);
    if (!mounted) return;
    setState(() => historyKeywords = history);
  }

  Future<void> removeHistoryKeyword(String keyword) async {
    final history = await cacheService.deleteHistoryKeyword(keyword);
    if (!mounted) return;
    setState(() => historyKeywords = history);
  }

  Future<void> clearHistory() async {
    final confirmed = await confirmSearchAction(
      context: context,
      title: '清空搜索历史',
      content: '确定清空所有搜索历史吗？',
      confirmText: '清空',
      isDestructive: true,
    );
    if (!confirmed) return;
    await cacheService.clearHistory();
    if (!mounted) return;
    setState(() => historyKeywords = const <String>[]);
  }
}
