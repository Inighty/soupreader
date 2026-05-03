import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/book_source.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../source/services/source/explore_kinds_service.dart';
import '../services/discovery_filter_helper.dart';
import 'discovery_explore_results_view.dart';
import 'discovery_search_header.dart';
import 'discovery_source_actions.dart';
import 'discovery_source_item_card.dart';
import 'discovery_source_menu.dart';
import 'discovery_view_helpers.dart';

/// 发现页（对标 legado ExploreFragment）：
/// - 展示支持发现的书源列表
/// - 点击书源展开/收起发现入口
/// - 点击入口进入二级发现书单页
class DiscoveryView extends StatefulWidget {
  final ValueListenable<int>? compressSignal;

  const DiscoveryView({
    super.key,
    this.compressSignal,
  });

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  late final SourceRepository _sourceRepo;
  late final SourceExploreKindsService _exploreKindsService;
  final SettingsService _settingsService = SettingsService();
  StreamSubscription<List<BookSource>>? _sourceSub;
  String? _initError;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<BookSource> _allSources = <BookSource>[];
  int? _lastExternalCompressVersion;

  String? _expandedSourceUrl;
  final Set<String> _loadingKindsSources = <String>{};
  final Map<String, List<SourceExploreKind>> _sourceKindsCache =
      <String, List<SourceExploreKind>>{};

  @override
  void initState() {
    super.initState();
    try {
      final db = DatabaseService();
      _sourceRepo = SourceRepository(db);
      _exploreKindsService = SourceExploreKindsService(databaseService: db);

      _allSources = _sourceRepo.getAllSources();
      _searchController.addListener(_onQueryChanged);
      _searchFocusNode.addListener(_onSearchFocusChanged);
      _lastExternalCompressVersion = widget.compressSignal?.value;
      widget.compressSignal?.addListener(_onExternalCompressSignal);
      _sourceSub = _sourceRepo.watchAllSources().listen((sources) {
        if (!mounted) return;
        setState(() {
          _allSources = sources;
          if (_expandedSourceUrl != null &&
              !_allSources.any((s) => s.bookSourceUrl == _expandedSourceUrl)) {
            _expandedSourceUrl = null;
          }
        });
      });
    } catch (error, stackTrace) {
      _initError = '发现页初始化异常: $error';
      debugPrint('[discovery] init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      ExceptionLogService().record(
        node: 'discovery.init',
        message: '发现页初始化失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void didUpdateWidget(covariant DiscoveryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compressSignal == widget.compressSignal) return;
    oldWidget.compressSignal?.removeListener(_onExternalCompressSignal);
    _lastExternalCompressVersion = widget.compressSignal?.value;
    widget.compressSignal?.addListener(_onExternalCompressSignal);
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    widget.compressSignal?.removeListener(_onExternalCompressSignal);
    _searchController
      ..removeListener(_onQueryChanged)
      ..dispose();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onExternalCompressSignal() {
    final version = widget.compressSignal?.value;
    if (version == null) return;
    if (_lastExternalCompressVersion == version) return;
    _lastExternalCompressVersion = version;
    _compressExplore();
  }

  void _onQueryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<BookSource> _eligibleSources(List<BookSource> input) =>
      filterDiscoveryEligibleSources(input);

  List<String> _buildGroups(List<BookSource> sources) =>
      collectDiscoveryGroups(sources);

  void _setQuery(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
  }

  void _clearQuery() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  Future<void> _showGroupFilterMenu() async {
    final groups = _buildGroups(_eligibleSources(_allSources));
    const allToken = '__all__';
    final items = <AppActionListItem<String>>[
      const AppActionListItem<String>(
        value: allToken,
        icon: CupertinoIcons.square_grid_2x2,
        label: '全部',
      ),
      ...groups.map(
        (group) => AppActionListItem<String>(
          value: group,
          icon: CupertinoIcons.tag,
          label: group,
        ),
      ),
    ];
    final selected = await showAppActionListSheet<String>(
      context: context,
      title: '选择分组',
      showCancel: true,
      items: items,
    );
    if (selected == null || !mounted) return;
    if (selected == allToken) {
      _setQuery('');
      return;
    }
    _setQuery('group:$selected');
  }

  void _compressExplore() {
    if (_expandedSourceUrl != null) {
      setState(() => _expandedSourceUrl = null);
      return;
    }
    if (!_scrollController.hasClients) return;
    if (_settingsService.appSettings.appearanceMode == AppAppearanceMode.eInk) {
      _scrollController.jumpTo(0);
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleSource(BookSource source) async {
    HapticFeedback.selectionClick();
    final sourceUrl = source.bookSourceUrl;
    if (_expandedSourceUrl == sourceUrl) {
      setState(() => _expandedSourceUrl = null);
      return;
    }

    setState(() => _expandedSourceUrl = sourceUrl);
    await _loadKinds(source, forceRefresh: false);
  }

  Future<void> _loadKinds(
    BookSource source, {
    required bool forceRefresh,
  }) async {
    final sourceUrl = source.bookSourceUrl;

    if (!forceRefresh && _sourceKindsCache.containsKey(sourceUrl)) {
      return;
    }

    setState(() => _loadingKindsSources.add(sourceUrl));
    try {
      final kinds = await _exploreKindsService.exploreKinds(
        source,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _sourceKindsCache[sourceUrl] = kinds;
        _loadingKindsSources.remove(sourceUrl);
      });
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'discovery.load_kinds',
        message: '加载发现入口失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': source.bookSourceName,
          'forceRefresh': forceRefresh,
        },
      );
      if (!mounted) return;
      setState(() {
        _loadingKindsSources.remove(sourceUrl);
        _sourceKindsCache[sourceUrl] = <SourceExploreKind>[
          SourceExploreKind(
            title: 'ERROR:发现入口解析失败',
            url: '$e\n$st',
          ),
        ];
      });
    }
  }

  Future<void> _openExploreKind(
    BookSource source,
    SourceExploreKind kind,
  ) async {
    final rawUrl = kind.url?.trim() ?? '';
    if (rawUrl.isEmpty) return;

    final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
    if (title.startsWith('ERROR:')) {
      _showMessage(rawUrl, title: 'ERROR');
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => DiscoveryExploreResultsView(
          source: source,
          exploreName: title,
          exploreUrl: rawUrl,
        ),
      ),
    );
  }

  Future<void> _showSourceActions(BookSource source) async {
    final selected = await showDiscoverySourceActionsMenu(
      context: context,
      source: source,
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case DiscoverySourceMenuAction.edit:
        await openDiscoverySourceEditor(
          context: context,
          sourceRepo: _sourceRepo,
          sourceUrl: source.bookSourceUrl,
        );
      case DiscoverySourceMenuAction.moveToTop:
        await moveDiscoverySourceToTop(
          sourceRepo: _sourceRepo,
          sourceUrl: source.bookSourceUrl,
        );
      case DiscoverySourceMenuAction.login:
        await openDiscoverySourceLogin(
          context: context,
          sourceRepo: _sourceRepo,
          source: source,
          showMessage: _showMessage,
        );
      case DiscoverySourceMenuAction.search:
        await searchInDiscoverySource(
          context: context,
          settingsService: _settingsService,
          source: source,
        );
      case DiscoverySourceMenuAction.refresh:
        await _refreshSourceKinds(source);
      case DiscoverySourceMenuAction.delete:
        await confirmDeleteDiscoverySource(
          context: context,
          sourceRepo: _sourceRepo,
          source: source,
        );
    }
  }

  Future<void> _refreshSourceKinds(BookSource source) async {
    final ok = await clearDiscoverySourceKindsCache(
      exploreKindsService: _exploreKindsService,
      source: source,
      showMessage: _showMessage,
    );
    if (!ok || !mounted) return;

    setState(() {
      _sourceKindsCache.remove(source.bookSourceUrl);
    });

    if (_expandedSourceUrl == source.bookSourceUrl) {
      await _loadKinds(source, forceRefresh: true);
    }
  }

  void _showMessage(String message, {String title = '提示'}) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) return _buildInitErrorPage();

    final eligible = _eligibleSources(_allSources);
    final visible = DiscoveryFilterHelper.applyQueryFilter(
        eligible, _searchController.text);
    final query = _searchController.text.trim();
    final showEmptyMessage = DiscoveryFilterHelper.shouldShowEmptyMessage(
      visibleCount: visible.length,
      query: query,
    );

    return AppCupertinoPageScaffold(
      title: '发现',
      trailing: AppNavBarButton(
        onPressed: _showGroupFilterMenu,
        child: const Icon(CupertinoIcons.slider_horizontal_3, size: 22),
      ),
      child: _buildBody(
        eligible: eligible,
        visible: visible,
        query: query,
        showEmptyMessage: showEmptyMessage,
      ),
    );
  }

  Widget _buildInitErrorPage() {
    return AppCupertinoPageScaffold(
      title: '发现',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _initError ?? '初始化失败',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<BookSource> eligible,
    required List<BookSource> visible,
    required String query,
    required bool showEmptyMessage,
  }) {
    final header = _buildSearchHeader(
      visibleCount: visible.length,
      query: query,
    );

    return Column(
      children: [
        header,
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final source = visible[index];
                  final url = source.bookSourceUrl;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DiscoverySourceItemCard(
                      source: source,
                      expanded: _expandedSourceUrl == url,
                      loadingKinds: _loadingKindsSources.contains(url),
                      kinds: _sourceKindsCache[url] ??
                          const <SourceExploreKind>[],
                      onToggle: () => _toggleSource(source),
                      onLongPress: () => _showSourceActions(source),
                      onOpenKind: (kind) => _openExploreKind(source, kind),
                    ),
                  );
                },
              ),
              if (showEmptyMessage)
                Positioned.fill(
                  child: DiscoveryEmptyState(
                    eligibleCount: eligible.length,
                    query: query,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader({
    required int visibleCount,
    required String query,
  }) {
    final activeGroup = resolveDiscoveryActiveGroup(query);

    return DiscoverySearchHeader(
      controller: _searchController,
      searchFocusNode: _searchFocusNode,
      query: query,
      visibleCount: visibleCount,
      onClear: _clearQuery,
      activeFilterChip: activeGroup == null
          ? null
          : DiscoveryGroupFilterChip(activeGroup: activeGroup),
    );
  }
}
