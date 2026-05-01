import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/theme/source_ui_tokens.dart';
import 'package:soupreader/app/widgets/app_cupertino_page_scaffold.dart';
import 'package:soupreader/app/widgets/app_manage_search_field.dart';
import 'package:soupreader/app/widgets/app_nav_bar_button.dart';
import 'package:soupreader/app/widgets/app_toast.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/keep_screen_on_service.dart';
import 'package:soupreader/core/services/online_import_history_store.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_availability/check_task_service.dart';
import 'package:soupreader/features/source/services/source/host_group_helper.dart';
import 'package:soupreader/features/source/services/source_import/commit_service.dart';
import 'package:soupreader/features/source/services/source_import/export_service.dart';
import 'package:soupreader/features/source/views/list/actions/list_actions.dart';
import 'package:soupreader/features/source/views/list/actions/batch_actions.dart';
import 'package:soupreader/features/source/views/list/actions/group_actions.dart';
import 'package:soupreader/features/source/views/list/import/import_actions.dart';
import 'package:soupreader/features/source/views/list/import/import_dialogs.dart';
import 'package:soupreader/features/source/views/list/actions/navigation_actions.dart';
import 'package:soupreader/features/source/views/list/actions/selection_controller.dart';
import 'package:soupreader/features/source/views/list/actions/settings_helper.dart';
import 'package:soupreader/features/source/views/list/source_list_support.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';
import 'package:soupreader/features/source/views/list/widgets/source_list_widgets.dart';

/// 书源管理页面
class SourceListView extends StatefulWidget {
  const SourceListView({
    super.key,
    this.moveSourcesHandler,
  });

  final SourceMoveSourcesHandler? moveSourcesHandler;

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  static const String _prefImportOnlineHistory = 'source_import_online_history';

  SourceSortMode _sortMode = SourceSortMode.manual;
  bool _sortAscending = true;
  bool _groupSourcesByDomain = false;
  bool _checkTaskKeepScreenOn = false;
  SourceCheckTaskSnapshot? _lastCheckSnapshot;

  late final DatabaseService _db;
  late final SourceRepository _sourceRepo;
  late final SourceImportCommitService _importCommitService;
  late final SourceListSelectionController _selectionController;
  late final Stream<List<BookSource>> _sourceStream;

  final SettingsService _settingsService = SettingsService();
  final KeepScreenOnService _keepScreenOnService = KeepScreenOnService.instance;
  final SourceAvailabilityCheckTaskService _checkTaskService =
      SourceAvailabilityCheckTaskService.instance;
  final SourceImportExportService _importExportService =
      SourceImportExportService();
  final OnlineImportHistoryStore _importHistoryStore =
      OnlineImportHistoryStore();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();
  final GlobalKey _moreMenuKey = GlobalKey();
  final GlobalKey _listViewportKey = GlobalKey();
  final Set<String> _selectedUrls = <String>{};
  final Map<String, String> _hostMap = <String, String>{};
  final Map<String, GlobalKey> _itemKeyByUrl = <String, GlobalKey>{};

  SourceListSettingsHelper get _settingsHelper => SourceListSettingsHelper(
        context: context,
        db: _db,
      );

  SourceListGroupActions get _groupActions => SourceListGroupActions(
        context: context,
        db: _db,
        sourceRepo: _sourceRepo,
      );

  SourceListImportDialogs get _importDialogs => SourceListImportDialogs(
        context: context,
        sourceRepo: _sourceRepo,
        settingsHelper: _settingsHelper,
      );

  SourceListImportActions get _importActions => SourceListImportActions(
        context: context,
        sourceRepo: _sourceRepo,
        importCommitService: _importCommitService,
        importExportService: _importExportService,
        importHistoryStore: _importHistoryStore,
        importDialogs: _importDialogs,
        importHistoryPrefKey: _prefImportOnlineHistory,
        urlController: _urlController,
      );

  SourceListBatchActions get _batchActions => SourceListBatchActions(
        context: context,
        sourceRepo: _sourceRepo,
        importExportService: _importExportService,
        checkTaskService: _checkTaskService,
        settingsHelper: _settingsHelper,
        groupActions: _groupActions,
        moveSourcesHandler: widget.moveSourcesHandler,
      );

  SourceListNavigationActions get _navigationActions =>
      SourceListNavigationActions(
        context: context,
        sourceRepo: _sourceRepo,
        settingsService: _settingsService,
      );

  SourceListActions get _listActions => SourceListActions(
        context: context,
        sourceRepo: _sourceRepo,
        moveSourcesHandler: widget.moveSourcesHandler,
        moreMenuKey: _moreMenuKey,
        sortMode: _sortMode,
        sortAscending: _sortAscending,
        groupSourcesByDomain: _groupSourcesByDomain,
        setSearchQuery: _setSearchQuery,
        getAllSources: _sourceRepo.getAllSources,
        sortModeLabel: _sortModeLabel,
        applySortChange: _applySortChange,
        onOpenGroupManage: _groupActions.showGroupManageSheet,
        onToggleGroupByDomain: _toggleGroupByDomain,
        onImportFile: _importActions.importFromFile,
        onImportUrl: _importActions.importFromUrl,
        onImportQr: _importActions.importFromQrCode,
        onShowHelp: _settingsHelper.showSourceManageHelp,
        onCreateNewSource: _navigationActions.createNewSource,
        onShareSources: _shareSources,
        onConfirmDeleteSource: _confirmDeleteSource,
        onOpenSourceLogin: _navigationActions.openSourceLogin,
        onOpenSourceDebug: _navigationActions.openSourceDebug,
        onOpenSourceScopedSearch: _navigationActions.openSourceScopedSearch,
        onToggleSourceExplore: _navigationActions.toggleSourceExplore,
      );

  bool get _canManualReorder {
    return _sortMode == SourceSortMode.manual && !_groupSourcesByDomain;
  }

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _sourceRepo = SourceRepository(_db);
    _importCommitService = SourceImportCommitService(
      upsertSourceRawJson: _sourceRepo.upsertSourceRawJson,
      loadAllSources: _sourceRepo.getAllSources,
      loadRawJsonByUrl: _sourceRepo.getRawJsonByUrl,
    );
    _selectionController = SourceListSelectionController(
      sourceRepo: _sourceRepo,
      listScrollController: _listScrollController,
      listViewportKey: _listViewportKey,
      selectedUrls: _selectedUrls,
      itemKeyByUrl: _itemKeyByUrl,
      isManualReorderEnabled: () => _canManualReorder,
      isSortAscending: () => _sortAscending,
    );
    _sourceStream = _sourceRepo.watchAllSources();
    _searchController.addListener(_onSearchQueryChanged);
    _lastCheckSnapshot = _checkTaskService.snapshot;
    _checkTaskService.listenable.addListener(_onCheckTaskChanged);
    _syncCheckKeepScreenOn(_lastCheckSnapshot);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settingsHelper.maybeShowSourceManageHelpOnce();
    });
  }

  @override
  void dispose() {
    _checkTaskService.listenable.removeListener(_onCheckTaskChanged);
    _syncCheckKeepScreenOn(null, forceDisable: true);
    _urlController.dispose();
    _searchController
      ..removeListener(_onSearchQueryChanged)
      ..dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _searchController.text.trim().isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _searchController.text.trim().isEmpty) return;
        setState(_searchController.clear);
      },
      child: AppCupertinoPageScaffold(
        title: '书源管理',
        transitionBetweenRoutes: false,
        trailing: AppNavBarButton(
          key: _moreMenuKey,
          onPressed: _listActions.showMainOptions,
          minimumSize: const Size(
            SourceUiTokens.minTapSize,
            SourceUiTokens.minTapSize,
          ),
          child: const Icon(CupertinoIcons.line_horizontal_3),
        ),
        child: StreamBuilder<List<BookSource>>(
          stream: _sourceStream,
          builder: (context, snapshot) {
            final allSources = SourceListSupport.normalizeSources(
              snapshot.data ?? _sourceRepo.getAllSources(),
            );
            SourceListSupport.cleanupSelection(
              allSources: allSources,
              selectedUrls: _selectedUrls,
              itemKeyByUrl: _itemKeyByUrl,
            );
            final visibleSources = SourceListSupport.buildVisibleList(
              allSources: allSources,
              query: _searchController.text,
              sortMode: _sortMode,
              sortAscending: _sortAscending,
              groupSourcesByDomain: _groupSourcesByDomain,
              hostMap: _hostMap,
            );
            final checkSnapshot = _checkTaskService.snapshot;
            final checkIndex =
                SourceListSupport.buildCheckItemIndex(checkSnapshot);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SourceUiTokens.pagePaddingHorizontal,
                    8,
                    SourceUiTokens.pagePaddingHorizontal,
                    10,
                  ),
                  child: _buildNavigationSearchField(),
                ),
                SourceListCheckTaskBanner(
                  snapshot: checkSnapshot,
                  progressText: checkSnapshot == null
                      ? ''
                      : SourceListSupport.buildCheckTaskProgressText(
                          checkSnapshot,
                        ),
                  onStop: () {
                    _checkTaskService.requestStop();
                    setState(() {});
                  },
                ),
                Expanded(
                  child: SourceListContent(
                    visibleSources: visibleSources,
                    selectedUrls: _selectedUrls,
                    itemKeyForUrl: _selectionController.itemKeyForUrl,
                    listViewportKey: _listViewportKey,
                    listScrollController: _listScrollController,
                    canManualReorder: _canManualReorder,
                    groupSourcesByDomain: _groupSourcesByDomain,
                    sortModeIsManual: _sortMode == SourceSortMode.manual,
                    hostOf: _hostOf,
                    checkTaskRunning: checkSnapshot?.running == true,
                    inlineCheckStatus: (source) => SourceListSupport.inlineCheckStatus(
                      source: source,
                      checkTaskService: _checkTaskService,
                      checkIndex: checkIndex,
                    ),
                    inlineCheckMessage: (source) => SourceListSupport.inlineCheckMessage(
                      source: source,
                      checkTaskService: _checkTaskService,
                      checkIndex: checkIndex,
                    ),
                    inlineCheckColor: (status) =>
                        SourceListSupport.inlineCheckColor(context, status),
                    onToggleEnabled: (source) => _sourceRepo.updateSource(
                      source.copyWith(enabled: !source.enabled),
                    ),
                    onToggleExplore: _navigationActions.toggleSourceExplore,
                    onToggleSelection: (url) =>
                        setState(() => _selectionController.toggleSelection(url)),
                    onStartDragSelection: _startDragSelection,
                    onUpdateDragSelection: _updateDragSelectionByGlobal,
                    onAutoScrollForDragSelection: _autoScrollForDragSelection,
                    onEndDragSelection: _endDragSelection,
                    onOpenEditor: _navigationActions.openEditor,
                    onMoveToTop: _listActions.toTop,
                    onShowSourceActions: _listActions.showSourceActions,
                    onConfirmDelete: _confirmDeleteSource,
                    onReorderVisible: _selectionController.onReorderVisible,
                    onSelectAllOrClearVisible: () =>
                        _selectAllOrClearVisible(visibleSources),
                    onInvertVisibleSelection: () =>
                        _invertVisibleSelection(visibleSources),
                    onBatchDeleteSelected: () => _deleteSelected(visibleSources),
                    onShowBatchMoreActions: () =>
                        _showBatchMoreActions(visibleSources),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onCheckTaskChanged() {
    final current = _checkTaskService.snapshot;
    final previous = _lastCheckSnapshot;
    final finished = previous?.running == true && current?.running != true;
    _lastCheckSnapshot = current;
    _syncCheckKeepScreenOn(current);
    if (!mounted) return;
    setState(() {});
    if (!finished || current == null) return;
    _handleInlineCheckFinished();
  }

  void _syncCheckKeepScreenOn(
    SourceCheckTaskSnapshot? snapshot, {
    bool forceDisable = false,
  }) {
    final shouldKeepOn = !forceDisable && snapshot?.running == true;
    if (_checkTaskKeepScreenOn == shouldKeepOn) return;
    _checkTaskKeepScreenOn = shouldKeepOn;
    unawaited(_keepScreenOnService.setEnabled(shouldKeepOn));
  }

  void _handleInlineCheckFinished() {
    final allSources = SourceListSupport.normalizeSources(_sourceRepo.getAllSources());
    final hasInvalidGroup = SourceListSupport.hasInvalidGroup(allSources);
    if (_searchController.text.trim().isEmpty && hasInvalidGroup) {
      setState(() => _searchController.text = '失效');
      unawaited(showAppToast(context, message: '发现有失效书源，已为您自动筛选！'));
    }
  }

  Widget _buildNavigationSearchField() {
    return AppManageSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      placeholder: '请输入关键字搜索书源...',
    );
  }

  void _onSearchQueryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _setSearchQuery(String query) {
    setState(() => _searchController.text = query);
  }

  String _sortModeLabel(SourceSortMode mode) {
    switch (mode) {
      case SourceSortMode.manual:
        return '自定义';
      case SourceSortMode.weight:
        return '搜索权重';
      case SourceSortMode.name:
        return '名称';
      case SourceSortMode.url:
        return 'URL';
      case SourceSortMode.update:
        return '更新时间';
      case SourceSortMode.respond:
        return '响应时间';
      case SourceSortMode.enabled:
        return '是否禁用';
    }
  }

  void _applySortChange(SourceSortMode mode, bool ascending) {
    setState(() {
      _sortMode = mode;
      _sortAscending = ascending;
    });
  }

  void _toggleGroupByDomain() {
    setState(() => _groupSourcesByDomain = !_groupSourcesByDomain);
  }

  String _hostOf(String url) {
    return _hostMap.putIfAbsent(
      url,
      () => SourceHostGroupHelper.groupHost(url),
    );
  }

  void _startDragSelection(List<BookSource> visible, int index) {
    if (!_selectionController.startDragSelection(visible, index)) return;
    setState(() {});
  }

  void _updateDragSelectionByGlobal(
    List<BookSource> visible,
    Offset globalPosition,
  ) {
    if (!_selectionController.updateDragSelectionByGlobal(visible, globalPosition)) {
      return;
    }
    setState(() {});
  }

  void _autoScrollForDragSelection(
    List<BookSource> visible,
    Offset globalPosition,
  ) {
    _selectionController.autoScrollForDragSelection(
      visible,
      globalPosition,
      () => setState(() {}),
    );
  }

  void _endDragSelection() {
    if (!_selectionController.endDragSelection()) return;
    setState(() {});
  }

  void _selectAllOrClearVisible(List<BookSource> visibleSources) {
    setState(() => _selectionController.selectAllOrClearVisible(visibleSources));
  }

  void _invertVisibleSelection(List<BookSource> visibleSources) {
    setState(() => _selectionController.invertVisibleSelection(visibleSources));
  }

  Future<void> _showBatchMoreActions(List<BookSource> visibleSources) {
    return _batchActions.showBatchMoreActions(
      visibleSources: visibleSources,
      selectedUrls: _selectedUrls,
      onSelectInterval: () =>
          setState(() => _selectionController.expandSelectionInterval(visibleSources)),
    );
  }

  Future<void> _deleteSelected(List<BookSource> visibleSources) {
    return _batchActions.deleteSelected(
      allSources: visibleSources,
      selectedUrls: _selectedUrls,
      onSelectionCleared: _clearSelection,
    );
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(_selectedUrls.clear);
  }

  Future<void> _confirmDeleteSource(BookSource source) async {
    setState(() => _selectedUrls.remove(source.bookSourceUrl));
    await _listActions.confirmDeleteSource(source);
  }

  Future<void> _shareSources(List<BookSource> sources) {
    return _batchActions.shareSources(sources);
  }
}
