import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/book.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../../source/services/source/cover_loader.dart';
import '../../../app/widgets/source_aware_cover_image.dart';
import '../models/search_scope.dart';
import '../models/search_scope_group_helper.dart';
import '../services/search_cache_service.dart';
import '../services/search_input_hint_helper.dart';
import '../services/search_load_more_helper.dart';
import 'search_book_info_view.dart';
import '../services/search_aggregator.dart';
import 'search_scope_helpers.dart';
import 'search_view_actions.dart';
import 'search_view_body.dart';
import 'search_view_engine.dart';

/// 搜索页面（对齐 legado 核心语义：范围、过滤、可停止、历史词）。
class SearchView extends StatefulWidget {
  final List<String>? sourceUrls;
  final String? initialKeyword;

  const SearchView({
    super.key,
    this.initialKeyword,
  }) : sourceUrls = null;
  const SearchView.scoped({
    super.key,
    required this.sourceUrls,
    this.initialKeyword,
  });

  @override
  State<SearchView> createState() => SearchViewState();
}

class SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _resultScrollController = ScrollController();
  final SettingsService _settingsService = SettingsService();
  final SearchCacheService _cacheService = SearchCacheService();
  late final BookRepository _bookRepo;
  late final SourceRepository _sourceRepo;
  late final BookAddService _addService;
  final LegadoSearchAggregator _aggregator = LegadoSearchAggregator();

  late AppSettings _settings;
  List<String> _historyKeywords = const <String>[];

  List<SearchResult> _results = <SearchResult>[];
  List<SearchDisplayItem> _displayResults = <SearchDisplayItem>[];
  final List<SourceRunIssue> _sourceIssues = <SourceRunIssue>[];
  final Set<CancelToken> _activeCancelTokens = <CancelToken>{};
  bool _isSearching = false;
  String _searchingSource = '';
  String _currentKeyword = '';
  String _currentCacheKey = '';
  int _currentPage = 0;
  bool _hasMore = false;
  List<BookSource> _sessionSources = const <BookSource>[];
  int _completedSources = 0;
  int _searchSessionSeed = 0;
  int _runningSearchSessionId = 0;
  StreamSubscription<List<BookSource>>? _enabledGroupsSub;
  StreamSubscription<List<Book>>? _bookshelfBooksSub;
  bool _enabledGroupsReady = false;
  List<String> _enabledGroups = const <String>[];
  List<Book> _bookshelfBooks = const <Book>[];
  bool _searchHasFocus = false;
  final Map<String, SourceAwareCoverLoadState> _coverLoadStateByItem =
      <String, SourceAwareCoverLoadState>{};

  bool get _showManualLoadMorePanel =>
      SearchLoadMoreHelper.shouldShowManualLoadMore(
        isSearching: _isSearching,
        hasMore: _hasMore,
        resultCount: _displayResults.length,
      );

  bool get _isPrecisionSearchEnabled =>
      normalizeSearchFilterMode(_settings.searchFilterMode) ==
      SearchFilterMode.precise;

  bool get _showInputHelpPanel =>
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: _isSearching,
        hasInputFocus: _searchHasFocus,
        resultCount: _displayResults.length,
        currentKeyword: _searchController.text,
      );

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _bookRepo = BookRepository(db);
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db);
    _searchHasFocus = _searchFocusNode.hasFocus;
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _resultScrollController.addListener(_onResultScroll);
    _settings = _sanitizeSettings(_settingsService.appSettings);
    _applyScopedEntrySearchScope();
    _startEnabledGroupsFlow();
    _startBookshelfFlow();
    unawaited(_prepareLocalState());

    final initialKeyword =
        SearchInputHintHelper.normalizeKeyword(widget.initialKeyword ?? '');
    if (initialKeyword.isNotEmpty) {
      _searchController.text = initialKeyword;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: initialKeyword.length),
      );
    }

    final shouldAutoSubmit =
        SearchInputHintHelper.shouldAutoSubmitInitialKeyword(
      initialKeyword: initialKeyword,
    );
    final shouldRequestFocus = SearchInputHintHelper.shouldRequestFocusOnOpen(
      initialKeyword: initialKeyword,
    );
    if (shouldAutoSubmit || shouldRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (shouldAutoSubmit) {
          _search();
          return;
        }
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    unawaited(_enabledGroupsSub?.cancel());
    unawaited(_bookshelfBooksSub?.cancel());
    _cancelOngoingSearch(updateState: false);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _resultScrollController.removeListener(_onResultScroll);
    _resultScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    final hasFocus = _searchFocusNode.hasFocus;
    if (_searchHasFocus == hasFocus) return;
    if (!mounted) {
      _searchHasFocus = hasFocus;
      return;
    }
    setState(() => _searchHasFocus = hasFocus);
  }

  Future<void> _prepareLocalState() async {
    final history = await _cacheService.loadHistory();
    await _cacheService.purgeExpiredCache(
      retentionDays: _settings.searchCacheRetentionDays,
    );
    if (!mounted) return;
    setState(() => _historyKeywords = history);
  }

  void _startEnabledGroupsFlow() {
    _enabledGroupsSub?.cancel();
    _enabledGroupsSub = _sourceRepo.watchAllSources().listen((allSources) {
      final next = SearchScopeGroupHelper.enabledGroupsFromSources(allSources);
      if (_enabledGroupsReady && listEquals(next, _enabledGroups)) {
        return;
      }
      _enabledGroupsReady = true;
      _enabledGroups = next;
      if (mounted) setState(() {});
    });
  }

  void _startBookshelfFlow() {
    _bookshelfBooksSub?.cancel();
    _bookshelfBooksSub = _bookRepo.watchAllBooks().listen((books) {
      if (!mounted) return;
      setState(() => _bookshelfBooks = books);
    });
  }

  AppSettings _sanitizeSettings(AppSettings settings) =>
      SearchScopeHelpers.sanitizeSettings(settings);

  Future<void> _saveSettings(AppSettings next) async {
    setState(() => _settings = next);
    await _settingsService.saveAppSettings(next);
  }

  List<BookSource> _allSources() => SearchScopeHelpers.allSources(
        repo: _sourceRepo,
        scopedUrls: widget.sourceUrls,
      );

  void _applyScopedEntrySearchScope() {
    final scoped = widget.sourceUrls;
    if (scoped == null || scoped.isEmpty) return;
    final scopedUrls = SearchScopeHelpers.normalizeUrlSet(scoped);
    if (scopedUrls.isEmpty || scopedUrls.length != 1) return;
    final sourceUrl = scopedUrls.first;
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) return;
    final nextScope = SearchScope.fromSource(source);
    if (nextScope == _settings.searchScope) return;
    _settings = _settings.copyWith(searchScope: nextScope);
  }

  ResolvedSearchScope _resolveSearchScope() {
    final all = _allSources();
    return SearchScopeHelpers.resolveSearchScope(
      scopeText: _settings.searchScope,
      allSources: all,
      enabledSources: SearchScopeHelpers.allEnabledSources(all),
    );
  }

  void _handleCoverLoadState(String itemKey, SourceAwareCoverLoadState state) {
    if (!mounted) return;
    if (_coverLoadStateByItem[itemKey] == state) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_coverLoadStateByItem[itemKey] == state) return;
      setState(() => _coverLoadStateByItem[itemKey] = state);
    });
  }

  void _rebuildDisplayResults({String? keyword}) {
    final searchKeyword = keyword ?? _currentKeyword;
    final bookshelfKeys = _addService.buildSearchBookshelfKeys();
    final built = _aggregator.buildDisplayItems(
      searchKeyword: searchKeyword,
      precision: _isPrecisionSearchEnabled,
      isInBookshelf: (item) => _addService.isInBookshelf(
        item,
        bookshelfKeys: bookshelfKeys,
      ),
    );
    _results = _aggregator.rawResults;

    final activeKeys = built.map((item) => item.key).toSet();
    _coverLoadStateByItem.removeWhere((key, _) => !activeKeys.contains(key));
    for (final item in built) {
      final coverUrl = item.displayCoverUrl.trim();
      if (coverUrl.isEmpty) {
        _coverLoadStateByItem[item.key] = SourceAwareCoverLoadState.emptyUrl;
      } else if (_coverLoadStateByItem[item.key] ==
          SourceAwareCoverLoadState.emptyUrl) {
        _coverLoadStateByItem.remove(item.key);
      }
    }

    _displayResults = built;
  }

  bool _isSearchSessionActive(int sessionId) {
    return mounted && _isSearching && _runningSearchSessionId == sessionId;
  }

  int _startSearchSession() {
    _searchSessionSeed++;
    _runningSearchSessionId = _searchSessionSeed;
    return _runningSearchSessionId;
  }

  void _cancelOngoingSearch({bool updateState = true}) {
    _isSearching = false;
    _runningSearchSessionId = 0;
    _searchingSource = '';
    _hasMore = false;
    final tokens = _activeCancelTokens.toList(growable: false);
    _activeCancelTokens.clear();
    for (final token in tokens) {
      if (!token.isCancelled) token.cancel('search canceled');
    }
    if (updateState && mounted) setState(() {});
  }

  void _onResultScroll() {
    if (!_resultScrollController.hasClients) return;
    final position = _resultScrollController.position;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining > 1.0) return;
    if (_isSearching || !_hasMore) return;
    if (_currentKeyword.trim().isEmpty) return;
    if (_displayResults.isEmpty) return;
    unawaited(_loadNextPage());
  }

  Future<void> _continueLoadMoreLikeLegado() async {
    if (!_showManualLoadMorePanel) return;
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isSearching || !_hasMore) return;
    if (_sessionSources.isEmpty) return;
    if (_currentKeyword.trim().isEmpty) return;
    final sessionId = _runningSearchSessionId;
    if (sessionId == 0) return;
    final nextPage = _currentPage + 1;
    setState(() {
      _isSearching = true;
      _completedSources = 0;
      _searchingSource = '';
    });
    final hasMore = await _runSearchPage(
      searchSessionId: sessionId,
      sources: _sessionSources,
      page: nextPage,
    );
    _finishSearchPage(sessionId, hasMore, newPage: nextPage);
  }

  Future<void> _search() async {
    _searchFocusNode.unfocus();
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final resolvedScopeState = _resolveSearchScope();
    if (resolvedScopeState.resolvedScope.normalizedScope !=
        _settings.searchScope) {
      await _saveSettings(
        _settings.copyWith(
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
    await _saveHistoryKeyword(keyword);

    final cacheKey = _cacheService.buildCacheKey(
      keyword: keyword,
      filterMode: normalizeSearchFilterMode(_settings.searchFilterMode),
      scopeSourceUrls: enabledSources.map((item) => item.bookSourceUrl),
    );
    final cached = await _cacheService.readCache(
      key: cacheKey,
      retentionDays: _settings.searchCacheRetentionDays,
    );
    final cachedResults = cached?.results ?? const <SearchResult>[];

    _cancelOngoingSearch(updateState: false);
    final searchSessionId = _startSearchSession();
    _currentKeyword = keyword;
    _currentCacheKey = cacheKey;
    _currentPage = 1;
    _hasMore = true;
    _sessionSources = enabledSources;
    _aggregator.reset();
    _aggregator.ingest(cachedResults);

    setState(() {
      _isSearching = true;
      _coverLoadStateByItem.clear();
      _sourceIssues.clear();
      _completedSources = 0;
      _searchingSource = '';
      _rebuildDisplayResults(keyword: keyword);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_resultScrollController.hasClients) return;
      _resultScrollController.jumpTo(0);
    });

    final hasMore = await _runSearchPage(
      searchSessionId: searchSessionId,
      sources: enabledSources,
      page: _currentPage,
    );
    _finishSearchPage(searchSessionId, hasMore);
    unawaited(_maybePromptEmptyResultLikeLegado());
  }

  void _finishSearchPage(int sessionId, bool hasMore, {int? newPage}) {
    if (!_isSearchSessionActive(sessionId)) return;
    if (newPage != null) _currentPage = newPage;
    if (_results.isNotEmpty && _currentCacheKey.isNotEmpty) {
      unawaited(
          _cacheService.writeCache(key: _currentCacheKey, results: _results));
    }
    setState(() {
      _isSearching = false;
      _searchingSource = '';
      _hasMore = hasMore;
    });
  }

  Future<void> _maybePromptEmptyResultLikeLegado() async {
    if (!mounted || _isSearching || _displayResults.isNotEmpty) return;
    if (_currentKeyword.trim().isEmpty) return;
    final scope = _resolveSearchScope().resolvedScope;
    if (scope.isAll) return;
    final scopeLabel = scope.display();
    if (_isPrecisionSearchEnabled) {
      final confirm = await confirmSearchAction(
        context: context,
        title: '搜索结果为空',
        content: '$scopeLabel 搜索结果为空，是否关闭精准搜索并重试？',
        confirmText: '关闭并重试',
      );
      if (!confirm || !mounted) return;
      await _saveSettings(
        _settings.copyWith(searchFilterMode: SearchFilterMode.normal),
      );
      if (!mounted) return;
      await _search();
      return;
    }
    final confirm = await confirmSearchAction(
      context: context,
      title: '搜索结果为空',
      content: '$scopeLabel 搜索结果为空，是否切换到全部书源并重试？',
      confirmText: '切换并重试',
    );
    if (!confirm || !mounted) return;
    await _saveSettings(_settings.copyWith(searchScope: ''));
    if (!mounted) return;
    await _search();
  }

  Future<bool> _runSearchPage({
    required int searchSessionId,
    required List<BookSource> sources,
    required int page,
  }) async {
    return runSearchPage(
      searchSessionId: searchSessionId,
      sources: sources,
      page: page,
      ctx: SearchRunContext(
        aggregator: _aggregator,
        activeCancelTokens: _activeCancelTokens,
        isSessionActive: _isSearchSessionActive,
        setSearchingSource: (name) {
          if (mounted) setState(() => _searchingSource = name);
        },
        appendIssue: (issue) {
          if (mounted) setState(() => _sourceIssues.add(issue));
        },
        incrementCompleted: () {
          if (mounted) setState(() => _completedSources++);
        },
        applyIngest: () {
          if (mounted) {
            setState(() => _rebuildDisplayResults(keyword: _currentKeyword));
          }
        },
        recordIssueLog: ({
          required source,
          required page,
          required reason,
          statusCode,
          listCount,
          error,
          stackTrace,
        }) =>
            recordSearchIssueLog(
          currentKeyword: _currentKeyword,
          source: source,
          page: page,
          reason: reason,
          statusCode: statusCode,
          listCount: listCount,
          error: error,
          stackTrace: stackTrace,
        ),
        currentKeyword: _currentKeyword,
        filterMode: normalizeSearchFilterMode(_settings.searchFilterMode),
        concurrency: _settings.searchConcurrency,
      ),
    );
  }

  Future<void> _saveHistoryKeyword(String keyword) async {
    final history = await _cacheService.saveHistoryKeyword(keyword);
    if (!mounted) return;
    setState(() => _historyKeywords = history);
  }

  Future<void> _removeHistoryKeyword(String keyword) async {
    final history = await _cacheService.deleteHistoryKeyword(keyword);
    if (!mounted) return;
    setState(() => _historyKeywords = history);
  }

  Future<void> _clearHistory() async {
    final confirmed = await confirmSearchAction(
      context: context,
      title: '清空搜索历史',
      content: '确定清空所有搜索历史吗？',
      confirmText: '清空',
      isDestructive: true,
    );
    if (!confirmed) return;
    await _cacheService.clearHistory();
    if (!mounted) return;
    setState(() => _historyKeywords = const <String>[]);
  }

  Future<void> _openBookInfo(SearchResult result) async {
    try {
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => SearchBookInfoView(result: result),
        ),
      );
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'search.open_book_info',
        message: '打开书籍详情失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'bookName': result.name,
          'bookUrl': result.bookUrl,
          'sourceUrl': result.sourceUrl,
          'sourceName': result.sourceName,
        },
      );
      if (mounted) showSearchMessage(context, '打开详情失败，请稍后重试');
      return;
    }
    if (!mounted) return;
    setState(() => _rebuildDisplayResults(keyword: _currentKeyword));
  }

  bool _shouldAutoSearchOnScopeChanged() {
    return SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
      isSearching: _isSearching,
      hasInputFocus: _searchHasFocus,
      resultCount: _displayResults.length,
      currentKeyword: _searchController.text,
    );
  }

  Future<void> _showSearchSettingsSheet() async {
    final action = await showSearchSettingsSheet(
      context: context,
      precisionSearchEnabled: _isPrecisionSearchEnabled,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case SearchSettingAction.precisionSearch:
        await _togglePrecisionSearchLikeLegado();
      case SearchSettingAction.scope:
        await _openScopePickerLikeLegado();
      case SearchSettingAction.sourceManage:
        await openSourceManageView(context);
      case SearchSettingAction.logs:
        await openSearchAppLogDialog(context);
    }
  }

  Future<void> _togglePrecisionSearchLikeLegado() async {
    final nextMode = togglePrecisionSearchMode(_settings);
    await _saveSettings(_settings.copyWith(searchFilterMode: nextMode));
    if (!mounted) return;
    await _search();
  }

  Future<void> _openScopePickerLikeLegado() async {
    final scopeState = _resolveSearchScope();
    final scopeText = await openSearchScopePicker(
      context: context,
      allSources: scopeState.allSources,
      allEnabledSources: scopeState.allEnabledSources,
    );
    if (scopeText == null) return;
    await _saveSettings(_settings.copyWith(searchScope: scopeText));
    if (!mounted) return;
    if (_shouldAutoSearchOnScopeChanged()) await _search();
  }

  void _showIssueDetailsDialog() {
    if (_sourceIssues.isEmpty) return;
    final mapped = _sourceIssues
        .map((issue) =>
            (sourceName: issue.sourceName, reason: issue.reason))
        .toList(growable: false);
    showSearchMessage(context, formatSearchIssueDigest(mapped));
  }

  Future<void> _openBookshelfBookInfo(Book book) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleHistoryKeywordTap(String keyword) async {
    final normalized = SearchInputHintHelper.normalizeKeyword(keyword);
    if (normalized.isEmpty) return;
    final shouldSubmit = SearchInputHintHelper.shouldSubmitHistoryKeyword(
      currentKeyword: _searchController.text,
      selectedKeyword: normalized,
      hasExactBookshelfTitle: SearchInputHintHelper.hasExactBookTitle(
        _bookshelfBooks,
        normalized,
      ),
    );
    _searchController.text = normalized;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: normalized.length),
    );
    if (shouldSubmit) {
      await _search();
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  List<Book> _bookshelfHintsForInput() {
    return SearchInputHintHelper.filterBookshelfBooks(
      _bookshelfBooks,
      _searchController.text,
    );
  }

  List<String> _historyHintsForInput() {
    return SearchInputHintHelper.filterHistoryKeywords(
      _historyKeywords,
      _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopeState = _resolveSearchScope();
    final totalSources = scopeState.sources.length;
    final hasQueryText =
        SearchInputHintHelper.normalizeKeyword(_searchController.text)
            .isNotEmpty;
    return SearchViewBody(
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      resultScrollController: _resultScrollController,
      isSearching: _isSearching,
      hasMore: _hasMore,
      searchHasFocus: _searchHasFocus,
      searchingSource: _searchingSource,
      completedSources: _completedSources,
      totalSources: totalSources,
      scopeLabel: scopeState.resolvedScope.display(),
      sourceIssueCount: _sourceIssues.length,
      showManualLoadMorePanel: _showManualLoadMorePanel,
      showInputHelpPanel: _showInputHelpPanel,
      displayResults: _displayResults,
      bookshelfHints: _bookshelfHintsForInput(),
      historyHints: _historyHintsForInput(),
      hasQueryText: hasQueryText,
      showCover: _settings.searchShowCover,
      sourceRepo: _sourceRepo,
      onTopBarChanged: (_) {
        if (_isSearching) {
          _cancelOngoingSearch();
          return;
        }
        if (_hasMore) {
          setState(() => _hasMore = false);
          return;
        }
        setState(() {});
      },
      onSubmit: _search,
      onOpenScopePicker: _openScopePickerLikeLegado,
      onCancelButton: () {
        _searchFocusNode.unfocus();
        if (_isSearching) _cancelOngoingSearch();
      },
      onCancelSearch: _cancelOngoingSearch,
      onShowIssueDetails: _showIssueDetailsDialog,
      onContinueLoadMore: () => unawaited(_continueLoadMoreLikeLegado()),
      onClearHistory: _clearHistory,
      onHistoryTap: (k) => unawaited(_handleHistoryKeywordTap(k)),
      onHistoryLongPress: _removeHistoryKeyword,
      onBookshelfTap: (b) => unawaited(_openBookshelfBookInfo(b)),
      onCoverState: _handleCoverLoadState,
      onOpenBookInfo: _openBookInfo,
      onShowSettings: _showSearchSettingsSheet,
    );
  }
}
