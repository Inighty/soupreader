import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/utils/legado_json.dart';
import '../../../core/services/qr_scan_service.dart';
import '../models/rss_source.dart';
import '../services/rss_source_import_commit_service.dart';
import '../services/rss_source_import_export_service.dart';
import '../services/rss_source_import_selection_helper.dart';
import '../services/rss_source_manage_helper.dart';
import 'rss_group_manage_view.dart';
import 'rss_source_edit_view.dart';
import 'rss_source_manage_actions.dart';
import 'rss_source_manage_dialogs.dart';
import 'rss_source_manage_import_dialog.dart';
import 'rss_source_manage_online_input.dart';
import 'rss_source_manage_types.dart';
import 'rss_source_manage_widgets.dart';
import 'rss_subscription_view.dart';

class RssSourceManageView extends StatefulWidget {
  const RssSourceManageView({
    super.key,
    this.repository,
  });

  final RssSourceRepository? repository;

  @override
  State<RssSourceManageView> createState() => _RssSourceManageViewState();
}

class _RssSourceManageViewState extends State<RssSourceManageView> {
  static const String _onlineImportHistoryKey = 'rssSourceRecordKey';
  late final RssSourceRepository _repo;
  late final RssSourceImportExportService _importExportService;
  late final RssSourceImportCommitService _importCommitService;
  final TextEditingController _queryController = TextEditingController();
  final GlobalKey _groupMenuKey = GlobalKey();
  final GlobalKey _mainMenuKey = GlobalKey();
  final Set<String> _selectedSourceUrls = <String>{};
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
    _importExportService = RssSourceImportExportService();
    _importCommitService = RssSourceImportCommitService(
      upsertSourceRawJson: _repo.upsertSourceRawJson,
      loadAllSources: _repo.getAllSources,
      loadRawJsonByUrl: _repo.getRawJsonByUrl,
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String get _query => _queryController.text.trim();

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '订阅源管理',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: _openSubscriptions,
            child: const Icon(CupertinoIcons.dot_radiowaves_left_right),
          ),
          AppNavBarButton(
            key: _groupMenuKey,
            onPressed: _openGroupMenuSheet,
            child: const Icon(CupertinoIcons.folder),
          ),
          AppNavBarButton(
            key: _mainMenuKey,
            onPressed: _openMainOptions,
            child: const Icon(CupertinoIcons.ellipsis_circle),
          ),
        ],
      ),
      child: StreamBuilder<List<RssSource>>(
        stream: _repo.watchAllSources(),
        builder: (context, snapshot) {
          final allSources = snapshot.data ?? _repo.getAllSources();
          _cleanupSelection(allSources);
          final intent = RssSourceManageHelper.parseQueryIntent(_query);
          final visible = RssSourceManageHelper.applyQueryIntent(
            allSources,
            intent,
          );
          final selectedCount = _selectedSources(visible).length;

          return Column(
            children: [
              Padding(
                padding: AppManageSearchField.outerPadding,
                child: AppManageSearchField(
                  controller: _queryController,
                  placeholder: '搜索订阅源',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isEmpty ? '全部源' : '筛选：${intent.rawQuery}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              CupertinoColors.secondaryLabel.resolveFrom(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} 条',
                      style: TextStyle(
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? RssSourceManageEmptyState(
                        noData: _repo.size == 0,
                        onAdd: _openAddSource,
                        onClearQuery: () => _setQuery(''),
                      )
                    : RssSourceManageList(
                        sources: visible,
                        selectedSourceUrls: _selectedSourceUrls,
                        onToggleSelection: _toggleSelection,
                        onUpdateEnabled: _updateEnabled,
                        onEditSource: _openEditSource,
                        onShowSourceActions: _showSourceActions,
                      ),
              ),
              RssSourceManageSelectionBar(
                selectedCount: selectedCount,
                totalCount: visible.length,
                onToggleAll: () => _toggleAllVisibleSelection(
                  visibleSources: visible,
                  allSelected:
                      visible.isNotEmpty && selectedCount >= visible.length,
                ),
                onInvert: () => _invertVisibleSelection(visible),
                onShowMore: () => _showSelectionMoreActions(visible),
              ),
            ],
          );
        },
      ),
    );
  }

  void _cleanupSelection(List<RssSource> allSources) {
    if (_selectedSourceUrls.isEmpty) return;
    final allUrls = allSources
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    _selectedSourceUrls.removeWhere((url) => !allUrls.contains(url));
  }

  void _toggleSelection(String sourceUrl) {
    final normalized = sourceUrl.trim();
    if (normalized.isEmpty) return;
    setState(() {
      if (_selectedSourceUrls.contains(normalized)) {
        _selectedSourceUrls.remove(normalized);
      } else {
        _selectedSourceUrls.add(normalized);
      }
    });
  }

  List<RssSource> _selectedSources(List<RssSource> visibleSources) {
    return visibleSources
        .where(
          (source) => _selectedSourceUrls.contains(source.sourceUrl.trim()),
        )
        .toList(growable: false);
  }

  void _toggleAllVisibleSelection({
    required List<RssSource> visibleSources,
    required bool allSelected,
  }) {
    if (visibleSources.isEmpty) return;
    setState(() {
      if (allSelected) {
        for (final source in visibleSources) {
          _selectedSourceUrls.remove(source.sourceUrl.trim());
        }
      } else {
        for (final source in visibleSources) {
          final sourceUrl = source.sourceUrl.trim();
          if (sourceUrl.isNotEmpty) _selectedSourceUrls.add(sourceUrl);
        }
      }
    });
  }

  void _invertVisibleSelection(List<RssSource> visibleSources) {
    if (visibleSources.isEmpty) return;
    setState(() {
      for (final source in visibleSources) {
        final sourceUrl = source.sourceUrl.trim();
        if (sourceUrl.isEmpty) continue;
        if (_selectedSourceUrls.contains(sourceUrl)) {
          _selectedSourceUrls.remove(sourceUrl);
        } else {
          _selectedSourceUrls.add(sourceUrl);
        }
      }
    });
  }

  Future<void> _showSelectionMoreActions(List<RssSource> visibleSources) async {
    if (!mounted) return;
    final selected = await showRssSelectionMoreActions(context);
    if (selected == null || !mounted) return;
    await dispatchRssSelectionAction(
      context: context,
      repo: _repo,
      importExportService: _importExportService,
      action: selected,
      selectedSources: _selectedSources(visibleSources),
      visibleSources: visibleSources,
      selectedSourceUrls: _selectedSourceUrls,
      notifySelectionChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _setQuery(String value) {
    _queryController.text = value;
    _queryController.selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
  }

  Future<void> _openAddSource() async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(builder: (_) => const RssSourceEditView()),
    );
  }

  Future<void> _openSubscriptions() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssSubscriptionView(repository: _repo),
      ),
    );
  }

  Future<void> _openEditSource(RssSource source) async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => RssSourceEditView(sourceUrl: source.sourceUrl),
      ),
    );
  }

  Future<void> _openGroupMenuSheet() async {
    final groups = _repo.allGroups();
    if (!mounted) return;
    final selected = await showRssGroupMenu(
      context: context,
      anchorKey: _groupMenuKey,
      groups: groups,
    );
    if (!mounted || selected == null) return;
    if (selected.openManage) {
      _openGroupManageSheet();
      return;
    }
    final query = selected.query?.trim() ?? '';
    if (query.isEmpty) return;
    _setQuery(query);
  }

  Future<void> _openGroupManageSheet() async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: SizedBox(
          height: math.min(MediaQuery.of(sheetContext).size.height * 0.78, 560),
          child: RssGroupManageView(repository: _repo, embedded: true),
        ),
      ),
    );
  }

  Future<void> _openMainOptions() async {
    if (!mounted) return;
    final selected = await showRssMainMenu(
      context: context,
      anchorKey: _mainMenuKey,
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case RssSourceMainMenuAction.create:
        _openAddSource();
      case RssSourceMainMenuAction.importFile:
        _importFromLocalFile();
      case RssSourceMainMenuAction.importUrl:
        _importFromOnlineInput();
      case RssSourceMainMenuAction.importQr:
        _importFromQrCode();
      case RssSourceMainMenuAction.importDefault:
        _importDefaultSources();
    }
  }

  Future<void> _importFromLocalFile() async {
    final result = await _importExportService.importFromFile();
    await _commitImportResult(result);
  }

  Future<void> _importFromOnlineInput() async {
    final rawInput = await showRssOnlineImportInputSheet(
      context: context,
      loadHistory: () =>
          _onlineImportHistoryStore.load(_onlineImportHistoryKey),
      saveHistory: (next) =>
          _onlineImportHistoryStore.save(_onlineImportHistoryKey, next),
    );
    final normalizedInput = rawInput?.trim();
    if (normalizedInput == null || normalizedInput.isEmpty) return;
    if (_isHttpUrl(normalizedInput)) {
      await _onlineImportHistoryStore.push(
          _onlineImportHistoryKey, normalizedInput);
    }
    final result = await _importExportService.importFromText(normalizedInput);
    await _commitImportResult(result);
  }

  Future<void> _importFromQrCode() async {
    final text = await QrScanService.scanText(context, title: '二维码导入');
    final normalizedInput = text?.trim();
    if (normalizedInput == null || normalizedInput.isEmpty) return;
    final result = await _importExportService.importFromText(normalizedInput);
    await _commitImportResult(result);
  }

  Future<void> _importDefaultSources() async {
    final result = await _importExportService.importFromDefaultAsset();
    if (!result.success) {
      _showImportError(result);
      return;
    }
    try {
      await _repo.deleteDefault();
      for (final source in result.sources) {
        final normalizedUrl = source.sourceUrl.trim();
        if (normalizedUrl.isEmpty) continue;
        final normalizedSource = source.copyWith(sourceUrl: normalizedUrl);
        final rawJson = result.rawJsonForSourceUrl(normalizedUrl) ??
            LegadoJson.encode(normalizedSource.toJson());
        await _repo.upsertSourceRawJson(rawJson: rawJson);
      }
    } catch (error) {
      if (mounted) await showRssMessage(context, '导入失败: $error');
    }
  }

  bool _isHttpUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    final scheme = parsed.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<void> _commitImportResult(RssSourceImportResult result) async {
    if (!result.success) {
      if (!result.cancelled) _showImportError(result);
      return;
    }
    final candidates = RssSourceImportSelectionHelper.buildCandidates(
      result: result,
      localMap: {
        for (final source in _repo.getAllSources()) source.sourceUrl: source
      },
    );
    if (candidates.isEmpty) {
      if (mounted) await showRssMessage(context, '没有可导入的订阅源');
      return;
    }
    if (!mounted) return;
    final decision = await showRssImportSelectionDialog(
      context: context,
      candidates: candidates,
    );
    if (decision == null) return;
    final plan = RssSourceImportSelectionHelper.buildCommitPlan(
      candidates: decision.candidates,
      policy: decision.policy,
    );
    if (plan.imported <= 0) return;
    final commitResult = await _importCommitService.commit(plan.items);
    if (commitResult.imported <= 0) return;
  }

  void _showImportError(RssSourceImportResult result) {
    if (!mounted) return;
    unawaited(showRssMessage(context, formatRssImportError(result)));
  }

  Future<void> _showSourceActions(RssSource source) async {
    if (!mounted) return;
    final selected = await showRssSourceItemActions(
      context: context,
      source: source,
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case RssSourceItemAction.moveToTop:
        await moveRssSourceToTop(repo: _repo, source: source);
      case RssSourceItemAction.moveToBottom:
        await moveRssSourceToBottom(repo: _repo, source: source);
      case RssSourceItemAction.delete:
        await _deleteSource(source);
    }
  }

  Future<void> _updateEnabled(RssSource source, bool value) async {
    final updated = source.copyWith(enabled: value);
    await _repo.updateSource(updated);
  }

  Future<void> _deleteSource(RssSource source) async {
    if (!mounted) return;
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isNotEmpty && _selectedSourceUrls.contains(sourceUrl)) {
      setState(() => _selectedSourceUrls.remove(sourceUrl));
    }
    final confirmed = await confirmRssSourceDelete(
      context: context,
      source: source,
    );
    if (!confirmed) return;
    await deleteRssSource(repo: _repo, source: source);
  }
}
