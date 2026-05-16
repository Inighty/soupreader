import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/book.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../../../app/widgets/source_aware_cover_image.dart';
import '../models/search_scope.dart';
import '../models/search_scope_group_helper.dart';
import '../services/search_cache_service.dart';
import '../services/search_input_hint_helper.dart';
import '../services/search_load_more_helper.dart';
import 'search_book_info_view.dart';
import '../services/search_aggregator.dart';
import 'search_scope_helpers.dart';
import 'search_session_extension.dart';
import 'search_view_actions.dart';
import 'search_view_body.dart';
import 'search_view_session_helpers.dart';

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
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final ScrollController resultScrollController = ScrollController();
  final SettingsService settingsService = SettingsService();
  final SearchCacheService cacheService = SearchCacheService();
  late final BookRepository bookRepo;
  late final SourceRepository sourceRepo;
  late final BookAddService addService;
  final LegadoSearchAggregator aggregator = LegadoSearchAggregator();

  late AppSettings settings;
  List<String> historyKeywords = const <String>[];

  List<SearchResult> results = <SearchResult>[];
  List<SearchDisplayItem> displayResults = <SearchDisplayItem>[];
  final List<SourceRunIssue> sourceIssues = <SourceRunIssue>[];
  final Set<CancelToken> activeCancelTokens = <CancelToken>{};
  bool isSearching = false;
  String searchingSource = '';
  String currentKeyword = '';
  String currentCacheKey = '';
  int currentPage = 0;
  bool hasMore = false;
  List<BookSource> sessionSources = const <BookSource>[];
  int completedSources = 0;
  int searchSessionSeed = 0;
  int runningSearchSessionId = 0;
  StreamSubscription<List<BookSource>>? enabledGroupsSub;
  StreamSubscription<List<Book>>? bookshelfBooksSub;
  bool enabledGroupsReady = false;
  List<String> enabledGroups = const <String>[];
  List<Book> bookshelfBooks = const <Book>[];
  bool searchHasFocus = false;
  final Map<String, SourceAwareCoverLoadState> coverLoadStateByItem =
      <String, SourceAwareCoverLoadState>{};

  bool get showManualLoadMorePanel =>
      SearchLoadMoreHelper.shouldShowManualLoadMore(
        isSearching: isSearching,
        hasMore: hasMore,
        resultCount: displayResults.length,
      );

  bool get isPrecisionSearchEnabled =>
      normalizeSearchFilterMode(settings.searchFilterMode) ==
      SearchFilterMode.precise;

  bool get showInputHelpPanel =>
      SearchInputHintHelper.shouldShowInputHelpPanel(
        isSearching: isSearching,
        hasInputFocus: searchHasFocus,
        resultCount: displayResults.length,
        currentKeyword: searchController.text,
      );

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    bookRepo = BookRepository(db);
    sourceRepo = SourceRepository(db);
    addService = BookAddService(database: db);
    searchHasFocus = searchFocusNode.hasFocus;
    searchFocusNode.addListener(onSearchFocusChanged);
    resultScrollController.addListener(onResultScroll);
    settings = sanitizeAppSettings(settingsService.appSettings);
    applyScopedEntrySearchScope();
    startEnabledGroupsFlow();
    startBookshelfFlow();
    unawaited(prepareLocalState());

    final initialKeyword =
        SearchInputHintHelper.normalizeKeyword(widget.initialKeyword ?? '');
    if (initialKeyword.isNotEmpty) {
      searchController.text = initialKeyword;
      searchController.selection = TextSelection.fromPosition(
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
          doSearch();
          return;
        }
        searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    unawaited(enabledGroupsSub?.cancel());
    unawaited(bookshelfBooksSub?.cancel());
    cancelOngoingSearch(updateState: false);
    searchFocusNode.removeListener(onSearchFocusChanged);
    searchFocusNode.dispose();
    resultScrollController.removeListener(onResultScroll);
    resultScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void onSearchFocusChanged() {
    final hasFocus = searchFocusNode.hasFocus;
    if (searchHasFocus == hasFocus) return;
    if (!mounted) {
      searchHasFocus = hasFocus;
      return;
    }
    setState(() => searchHasFocus = hasFocus);
  }

  Future<void> prepareLocalState() async {
    final history = await cacheService.loadHistory();
    await cacheService.purgeExpiredCache(
      retentionDays: settings.searchCacheRetentionDays,
    );
    if (!mounted) return;
    setState(() => historyKeywords = history);
  }

  void startEnabledGroupsFlow() {
    enabledGroupsSub?.cancel();
    enabledGroupsSub = sourceRepo.watchAllSources().listen((allSources) {
      final next = SearchScopeGroupHelper.enabledGroupsFromSources(allSources);
      if (enabledGroupsReady && listEquals(next, enabledGroups)) {
        return;
      }
      enabledGroupsReady = true;
      enabledGroups = next;
      if (mounted) setState(() {});
    });
  }

  void startBookshelfFlow() {
    bookshelfBooksSub?.cancel();
    bookshelfBooksSub = bookRepo.watchAllBooks().listen((books) {
      if (!mounted) return;
      setState(() => bookshelfBooks = books);
    });
  }

  AppSettings sanitizeAppSettings(AppSettings settings) =>
      SearchScopeHelpers.sanitizeSettings(settings);

  Future<void> saveSettings(AppSettings next) async {
    setState(() => settings = next);
    await settingsService.saveAppSettings(next);
  }

  List<BookSource> allSourcesList() => SearchScopeHelpers.allSources(
        repo: sourceRepo,
        scopedUrls: widget.sourceUrls,
      );

  void applyScopedEntrySearchScope() {
    final scoped = widget.sourceUrls;
    if (scoped == null || scoped.isEmpty) return;
    final scopedUrls = SearchScopeHelpers.normalizeUrlSet(scoped);
    if (scopedUrls.isEmpty || scopedUrls.length != 1) return;
    final sourceUrl = scopedUrls.first;
    final source = sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) return;
    final nextScope = SearchScope.fromSource(source);
    if (nextScope == settings.searchScope) return;
    settings = settings.copyWith(searchScope: nextScope);
  }

  ResolvedSearchScope resolveSearchScopeState() {
    final all = allSourcesList();
    return SearchScopeHelpers.resolveSearchScope(
      scopeText: settings.searchScope,
      allSources: all,
      enabledSources: SearchScopeHelpers.allEnabledSources(all),
    );
  }

  void handleCoverLoadState(String itemKey, SourceAwareCoverLoadState state) {
    if (!mounted) return;
    if (coverLoadStateByItem[itemKey] == state) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (coverLoadStateByItem[itemKey] == state) return;
      setState(() => coverLoadStateByItem[itemKey] = state);
    });
  }

  void rebuildDisplayResults({String? keyword}) {
    final searchKeyword = keyword ?? currentKeyword;
    final bookshelfKeys = addService.buildSearchBookshelfKeys();
    final built = aggregator.buildDisplayItems(
      searchKeyword: searchKeyword,
      precision: isPrecisionSearchEnabled,
      isInBookshelf: (item) => addService.isInBookshelf(
        item,
        bookshelfKeys: bookshelfKeys,
      ),
    );
    results = aggregator.rawResults;

    final activeKeys = built.map((item) => item.key).toSet();
    coverLoadStateByItem.removeWhere((key, _) => !activeKeys.contains(key));
    for (final item in built) {
      final coverUrl = item.displayCoverUrl.trim();
      if (coverUrl.isEmpty) {
        coverLoadStateByItem[item.key] = SourceAwareCoverLoadState.emptyUrl;
      } else if (coverLoadStateByItem[item.key] ==
          SourceAwareCoverLoadState.emptyUrl) {
        coverLoadStateByItem.remove(item.key);
      }
    }

    displayResults = built;
  }

  Future<void> openBookInfo(SearchResult result) async {
    final ok = await openSearchBookInfo(context: context, result: result);
    if (!ok || !mounted) return;
    setState(() => rebuildDisplayResults(keyword: currentKeyword));
  }

  bool shouldAutoSearchOnScopeChanged() {
    return SearchInputHintHelper.shouldAutoSearchOnScopeChanged(
      isSearching: isSearching,
      hasInputFocus: searchHasFocus,
      resultCount: displayResults.length,
      currentKeyword: searchController.text,
    );
  }

  Future<void> showSettingsSheet() async {
    final action = await showSearchSettingsSheet(
      context: context,
      precisionSearchEnabled: isPrecisionSearchEnabled,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case SearchSettingAction.precisionSearch:
        await togglePrecisionSearch();
      case SearchSettingAction.scope:
        await openScopePicker();
      case SearchSettingAction.sourceManage:
        await openSourceManageView(context);
      case SearchSettingAction.logs:
        await openSearchAppLogDialog(context);
    }
  }

  Future<void> togglePrecisionSearch() async {
    final nextMode = togglePrecisionSearchMode(settings);
    await saveSettings(settings.copyWith(searchFilterMode: nextMode));
    if (!mounted) return;
    await doSearch();
  }

  Future<void> openScopePicker() async {
    final scopeState = resolveSearchScopeState();
    final scopeText = await openSearchScopePicker(
      context: context,
      allSources: scopeState.allSources,
      allEnabledSources: scopeState.allEnabledSources,
    );
    if (scopeText == null) return;
    await saveSettings(settings.copyWith(searchScope: scopeText));
    if (!mounted) return;
    if (shouldAutoSearchOnScopeChanged()) await doSearch();
  }

  void showIssueDetailsDialog() {
    if (sourceIssues.isEmpty) return;
    final mapped = sourceIssues
        .map((issue) =>
            (sourceName: issue.sourceName, reason: issue.reason))
        .toList(growable: false);
    showSearchMessage(context, formatSearchIssueDigest(mapped));
  }

  Future<void> openBookshelfBookInfo(Book book) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> handleHistoryKeywordTap(String keyword) async {
    final normalized = SearchInputHintHelper.normalizeKeyword(keyword);
    if (normalized.isEmpty) return;
    final shouldSubmit = SearchInputHintHelper.shouldSubmitHistoryKeyword(
      currentKeyword: searchController.text,
      selectedKeyword: normalized,
      hasExactBookshelfTitle: SearchInputHintHelper.hasExactBookTitle(
        bookshelfBooks,
        normalized,
      ),
    );
    searchController.text = normalized;
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: normalized.length),
    );
    if (shouldSubmit) {
      await doSearch();
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  List<Book> bookshelfHintsForInput() {
    return SearchInputHintHelper.filterBookshelfBooks(
      bookshelfBooks,
      searchController.text,
    );
  }

  List<String> historyHintsForInput() {
    return SearchInputHintHelper.filterHistoryKeywords(
      historyKeywords,
      searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopeState = resolveSearchScopeState();
    final totalSources = scopeState.sources.length;
    final hasQueryText =
        SearchInputHintHelper.normalizeKeyword(searchController.text)
            .isNotEmpty;
    return SearchViewBody(
      searchController: searchController,
      searchFocusNode: searchFocusNode,
      resultScrollController: resultScrollController,
      isSearching: isSearching,
      hasMore: hasMore,
      searchHasFocus: searchHasFocus,
      searchingSource: searchingSource,
      completedSources: completedSources,
      totalSources: totalSources,
      scopeLabel: scopeState.resolvedScope.display(),
      sourceIssueCount: sourceIssues.length,
      showManualLoadMorePanel: showManualLoadMorePanel,
      showInputHelpPanel: showInputHelpPanel,
      displayResults: displayResults,
      bookshelfHints: bookshelfHintsForInput(),
      historyHints: historyHintsForInput(),
      hasQueryText: hasQueryText,
      showCover: settings.searchShowCover,
      sourceRepo: sourceRepo,
      onTopBarChanged: (_) {
        if (isSearching) {
          cancelOngoingSearch();
          return;
        }
        if (hasMore) {
          setState(() => hasMore = false);
          return;
        }
        setState(() {});
      },
      onSubmit: doSearch,
      onOpenScopePicker: openScopePicker,
      onCancelButton: () {
        searchFocusNode.unfocus();
        if (isSearching) cancelOngoingSearch();
      },
      onCancelSearch: cancelOngoingSearch,
      onShowIssueDetails: showIssueDetailsDialog,
      onContinueLoadMore: () => unawaited(continueLoadMore()),
      onClearHistory: clearHistory,
      onHistoryTap: (k) => unawaited(handleHistoryKeywordTap(k)),
      onHistoryLongPress: removeHistoryKeyword,
      onBookshelfTap: (b) => unawaited(openBookshelfBookInfo(b)),
      onCoverState: handleCoverLoadState,
      onOpenBookInfo: openBookInfo,
      onShowSettings: showSettingsSheet,
    );
  }
}
