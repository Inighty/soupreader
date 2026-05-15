import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_blocking_progress.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../../../core/utils/legado_json.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../models/replace_rule.dart';
import '../services/replace_rule_import_export_service.dart';
import 'replace_rule_edit_view.dart';
import 'replace_rule_import_types.dart';
import 'replace_rule_list_group_sheet.dart';
import 'replace_rule_list_import_dialog.dart';
import 'replace_rule_list_import_helpers.dart';
import 'replace_rule_list_menus.dart';
import 'replace_rule_list_message_dialogs.dart';
import 'replace_rule_list_online_import.dart';
import 'replace_rule_list_selection_actions.dart';
import 'replace_rule_list_widgets.dart';



class ReplaceRuleListView extends StatefulWidget {
  const ReplaceRuleListView({super.key});

  @override
  State<ReplaceRuleListView> createState() => _ReplaceRuleListViewState();
}

enum ReplaceRuleTopMenuAction {
  create,
  importFile,
  importUrl,
  importQr,
  help,
}

class _ReplaceRuleListViewState extends State<ReplaceRuleListView> {
  static const String _onlineImportHistoryKey = 'replaceRuleRecordKey';
  static const String _groupFilterAll = '';
  static const String _groupFilterNoGroup = '__no_group__';
  static const String _noGroupLabel = '未分组';
  static final RegExp _groupSplitPattern = RegExp(r'[,;，；]');

  late final ReplaceRuleRepository _repo;
  final GlobalKey _moreMenuKey = GlobalKey();
  final ReplaceRuleImportExportService _io = ReplaceRuleImportExportService();
  final TextEditingController _searchController = TextEditingController();
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  String _activeGroupQuery = _groupFilterAll;
  String _searchQuery = '';
  bool _changed = false;
  bool _dataInited = false;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _importingQr = false;
  bool _exportingSelection = false;
  bool _enablingSelection = false;
  bool _disablingSelection = false;
  bool _toppingSelection = false;
  bool _bottomingSelection = false;
  bool _deletingSelection = false;
  bool _selectionMode = false;
  final Set<int> _selectedRuleIds = <int>{};

  bool get _selectionUpdating =>
      _enablingSelection ||
      _disablingSelection ||
      _toppingSelection ||
      _bottomingSelection;

  bool get _selectionActionBusy =>
      _exportingSelection || _selectionUpdating || _deletingSelection;

  bool get _menuBusy =>
      _importingLocal ||
      _importingOnline ||
      _importingQr ||
      _exportingSelection ||
      _selectionUpdating ||
      _deletingSelection;

  @override
  void initState() {
    super.initState();
    _repo = ReplaceRuleRepository(DatabaseService());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_changed) setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReplaceRule>>(
      stream: _repo.watchAllRules(),
      builder: (context, snapshot) {
        final allRules = List<ReplaceRule>.from(
          snapshot.data ?? _repo.getAllRules(),
        )..sort((a, b) => a.order.compareTo(b.order));
        if (_dataInited && snapshot.hasData) _markChanged();
        _dataInited = true;
        _syncSelectionWithRules(allRules);

        final groups = _buildGroups(allRules);
        final activeGroupQuery = _resolveActiveGroupQuery(groups);
        // 对齐 legado：当搜索关键字非空时，优先走搜索分支（含 `group:` 与“未分组”语义）。
        final normalizedSearchQuery = _searchQuery.trim();
        final rules = normalizedSearchQuery.isEmpty
            ? _filterRulesByGroupQuery(allRules, activeGroupQuery)
            : _filterRulesBySearchQueryLikeLegado(
                allRules,
                normalizedSearchQuery,
              );
        final selectedCount = _selectedCountIn(rules);
        final totalCount = rules.length;
        final hasSelection = selectedCount > 0;
        final allSelected = totalCount > 0 && selectedCount == totalCount;
        final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
        final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);

        return PopScope<bool>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) Navigator.of(context).pop(_changed);
          },
          child: AppCupertinoPageScaffold(
          title: '文本替换规则',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNavBarButton(
                onPressed:
                    _menuBusy ? null : () => _showGroupFilterOptions(allRules),
                child: const Icon(CupertinoIcons.square_grid_2x2),
              ),
              AppNavBarButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: _menuBusy || (!_selectionMode && allRules.isEmpty)
                    ? null
                    : () => _toggleSelectionMode(allRules),
                child: Text(
                  _selectionMode ? '完成' : '多选',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              AppNavBarButton(
                key: _moreMenuKey,
                onPressed: _selectionMode
                    ? (hasSelection && !_menuBusy
                        ? () => _showSelectionMoreMenu(rules)
                        : null)
                    : (_menuBusy ? null : _showMoreMenu),
                child: _selectionMode
                    ? (_selectionActionBusy
                        ? const CupertinoActivityIndicator(radius: 9)
                        : Icon(
                            CupertinoIcons.ellipsis_circle,
                            color: hasSelection ? enabledColor : disabledColor,
                          ))
                    : (_menuBusy
                        ? const CupertinoActivityIndicator(radius: 9)
                        : const Icon(CupertinoIcons.ellipsis)),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: AppManageSearchField(
                  controller: _searchController,
                  placeholder: '替换净化搜索',
                  onChanged: _onSearchQueryChanged,
                ),
              ),
              Expanded(
                child: rules.isEmpty ? _empty() : _buildList(rules),
              ),
              if (_selectionMode)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                    decoration: BoxDecoration(
                      color:
                          CupertinoColors.systemGroupedBackground.resolveFrom(
                        context,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: CupertinoColors.systemGrey4.resolveFrom(context),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            minimumSize: const Size(30, 30),
                            alignment: Alignment.centerLeft,
                            onPressed: totalCount == 0
                                ? null
                                : () => _toggleSelectAllRules(rules),
                            child: Text(
                              allSelected
                                  ? '取消全选（$selectedCount/$totalCount）'
                                  : '全选（$selectedCount/$totalCount）',
                              style: TextStyle(
                                fontSize: 13,
                                color: totalCount == 0
                                    ? disabledColor
                                    : enabledColor,
                              ),
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(30, 30),
                          onPressed: totalCount == 0
                              ? null
                              : () => _revertSelection(rules),
                          child: Text(
                            '反选',
                            style: TextStyle(
                              fontSize: 13,
                              color: totalCount == 0
                                  ? disabledColor
                                  : enabledColor,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(30, 30),
                          onPressed: hasSelection && !_menuBusy
                              ? () => _confirmDeleteSelectedRules(rules)
                              : null,
                          child: _deletingSelection
                              ? const CupertinoActivityIndicator(radius: 9)
                              : Text(
                                  '删除',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: hasSelection && !_menuBusy
                                        ? CupertinoColors.systemRed.resolveFrom(context)
                                        : disabledColor,
                                  ),
                                ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          minimumSize: const Size(30, 30),
                          onPressed: hasSelection && !_menuBusy
                              ? () => _showSelectionMoreMenu(rules)
                              : null,
                          child: _selectionActionBusy
                              ? const CupertinoActivityIndicator(radius: 9)
                              : Icon(
                                  CupertinoIcons.ellipsis_circle,
                                  size: 19,
                                  color: hasSelection
                                      ? enabledColor
                                      : disabledColor,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _syncSelectionWithRules(List<ReplaceRule> rules) {
    final availableIds = rules.map((rule) => rule.id).toSet();
    _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
  }

  void _toggleSelectionMode(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedRuleIds.clear();
    });
  }

  int _selectedCountIn(List<ReplaceRule> rules) {
    var count = 0;
    for (final rule in rules) {
      if (_selectedRuleIds.contains(rule.id)) {
        count += 1;
      }
    }
    return count;
  }

  void _toggleRuleSelection(int ruleId) {
    setState(() {
      if (_selectedRuleIds.contains(ruleId)) {
        _selectedRuleIds.remove(ruleId);
      } else {
        _selectedRuleIds.add(ruleId);
      }
    });
  }

  void _toggleSelectAllRules(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      final allSelected = _selectedCountIn(rules) == rules.length;
      if (allSelected) {
        _selectedRuleIds.removeAll(rules.map((rule) => rule.id));
      } else {
        _selectedRuleIds.addAll(rules.map((rule) => rule.id));
      }
    });
  }

  void _revertSelection(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      for (final rule in rules) {
        if (_selectedRuleIds.contains(rule.id)) {
          _selectedRuleIds.remove(rule.id);
        } else {
          _selectedRuleIds.add(rule.id);
        }
      }
    });
  }

  void _onSearchQueryChanged(String value) {
    setState(() {
      _searchQuery = value;
      // 搜索分支与分组分支在 build 中互斥，输入搜索时无需主动改写分组状态。
      _selectedRuleIds.clear();
    });
  }

  List<String> _buildGroups(List<ReplaceRule> rules) {
    final groups = <String>{};
    for (final rule in rules) {
      final raw = rule.group?.trim();
      if (raw == null || raw.isEmpty) {
        continue;
      }
      for (final part in raw.split(_groupSplitPattern)) {
        final group = part.trim();
        if (group.isEmpty) {
          continue;
        }
        groups.add(group);
      }
    }
    final sorted = groups.toList(growable: false)
      ..sort(SearchScopeGroupHelper.cnCompareLikeLegado);
    return sorted;
  }

  String _resolveActiveGroupQuery(List<String> groups) {
    if (_activeGroupQuery == _groupFilterAll ||
        _activeGroupQuery == _groupFilterNoGroup) {
      return _activeGroupQuery;
    }
    if (groups.contains(_activeGroupQuery)) {
      return _activeGroupQuery;
    }
    return _groupFilterAll;
  }

  List<ReplaceRule> _filterRulesByGroupQuery(
    List<ReplaceRule> rules,
    String query,
  ) {
    if (query == _groupFilterAll) {
      return rules;
    }
    if (query == _groupFilterNoGroup) {
      return rules.where(_isNoGroupRule).toList(growable: false);
    }
    return rules
        .where((rule) => _containsLikeLegacy(rule.group ?? '', query))
        .toList(growable: false);
  }

  /// 对齐 legado ReplaceRuleActivity.observeReplaceRuleData：
  /// 1) `未分组` -> flowNoGroup
  /// 2) `group:xxx` -> flowGroupSearch("%xxx%")
  /// 3) 其它关键字 -> flowSearch("%key%")（name/group 联合搜索）
  List<ReplaceRule> _filterRulesBySearchQueryLikeLegado(
    List<ReplaceRule> rules,
    String query,
  ) {
    final raw = query.trim();
    if (raw.isEmpty) {
      return rules;
    }
    if (raw == _noGroupLabel) {
      return rules.where(_isNoGroupRule).toList(growable: false);
    }
    if (raw.startsWith('group:')) {
      final key = raw.substring(6).trim();
      return rules.where((rule) {
        final group = rule.group;
        if (group == null) return false;
        // legacy SQL `group like '%%'` 会匹配空字符串分组，但不会命中 null。
        if (key.isEmpty) return true;
        return _containsLikeLegacy(group, key);
      }).toList(growable: false);
    }
    return rules.where((rule) {
      final group = rule.group ?? '';
      return _containsLikeLegacy(group, raw) ||
          _containsLikeLegacy(rule.name, raw);
    }).toList(growable: false);
  }

  /// 近似对齐 SQLite `LIKE '%key%'` 的匹配语义：
  /// - 空 key 视为命中；
  /// - 采用不区分大小写的“包含”匹配，避免 Dart `contains` 比 SQL `LIKE` 更严格。
  bool _containsLikeLegacy(String text, String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return true;
    return text.toLowerCase().contains(normalizedKey.toLowerCase());
  }

  bool _isNoGroupRule(ReplaceRule rule) {
    final raw = rule.group;
    if (raw == null) {
      return true;
    }
    final text = raw.trim();
    if (text.isEmpty) {
      return true;
    }
    return text.contains(_noGroupLabel);
  }

  Future<void> _showGroupFilterOptions(List<ReplaceRule> allRules) async {
    final groups = _buildGroups(allRules);
    final activeGroupQuery = _resolveActiveGroupQuery(groups);
    const manageToken = '__group_manage__';
    final items = <AppActionListItem<String>>[
      const AppActionListItem<String>(
        value: manageToken,
        icon: CupertinoIcons.square_list,
        label: '分组管理',
      ),
      AppActionListItem<String>(
        value: _groupFilterAll,
        icon: activeGroupQuery == _groupFilterAll
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.square_grid_2x2,
        label: '${activeGroupQuery == _groupFilterAll ? '✓ ' : ''}全部',
      ),
      AppActionListItem<String>(
        value: _groupFilterNoGroup,
        icon: activeGroupQuery == _groupFilterNoGroup
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.circle,
        label:
            '${activeGroupQuery == _groupFilterNoGroup ? '✓ ' : ''}$_noGroupLabel',
      ),
      ...groups.map(
        (group) => AppActionListItem<String>(
          value: group,
          icon: activeGroupQuery == group
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.folder,
          label: '${activeGroupQuery == group ? '✓ ' : ''}$group',
        ),
      ),
    ];
    final selected = await showAppActionListSheet<String>(
      context: context,
      title: '分组',
      showCancel: true,
      items: items,
    );
    if (selected == null || !mounted) return;
    if (selected == manageToken) {
      _showGroupManageSheet();
      return;
    }
    _applyGroupQuery(selected);
  }

  void _applyGroupQuery(String query) {
    setState(() {
      _activeGroupQuery = query;
      _searchQuery = '';
      _selectedRuleIds.clear();
    });
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  void _recordViewError({
    required String node,
    required String message,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
  }) {
    ExceptionLogService().record(
      node: node,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
    debugPrint('[replace-rule] $node failed: $error');
  }

  Future<void> _showGroupManageSheet() {
    return showReplaceRuleGroupManageSheet(
      context: context,
      repo: _repo,
      buildGroups: _buildGroups,
      showGroupInputDialog: ({required title, initialValue}) =>
          _showGroupInputDialog(
              title: title, initialValue: initialValue ?? ''),
      addGroupToNoGroupRules: _addGroupToNoGroupRules,
      renameGroup: _renameGroup,
      removeGroup: _removeGroup,
    );
  }

  Future<String?> _showGroupInputDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      final value = await showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: '分组名称',
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return value?.trim();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addGroupToNoGroupRules(String group) async {
    final normalized = group.trim();
    if (normalized.isEmpty) return;
    try {
      final updates = _repo
          .getAllRules()
          .where((rule) {
            final raw = rule.group;
            return raw == null || raw.trim().isEmpty;
          })
          .map((rule) => rule.copyWith(group: normalized))
          .toList(growable: false);
      if (updates.isEmpty) return;
      await _repo.addRules(updates);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.group.add',
        message: '新增替换规则分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'group': normalized,
        },
      );
    }
  }

  Future<void> _renameGroup({
    required String oldGroup,
    required String newGroup,
  }) async {
    final nextGroup = newGroup.trim();
    try {
      final updates = <ReplaceRule>[];
      for (final rule in _repo.getAllRules()) {
        final raw = rule.group;
        if (raw == null || raw.isEmpty || !raw.contains(oldGroup)) {
          continue;
        }
        final groups = _splitGroupsForGroupMutation(raw);
        if (!groups.remove(oldGroup)) {
          continue;
        }
        if (nextGroup.isNotEmpty) {
          groups.add(nextGroup);
        }
        updates.add(rule.copyWith(group: _joinGroupsForGroupMutation(groups)));
      }
      if (updates.isEmpty) return;
      await _repo.addRules(updates);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.group.rename',
        message: '重命名替换规则分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'oldGroup': oldGroup,
          'newGroup': nextGroup,
        },
      );
    }
  }

  Future<void> _removeGroup(String group) async {
    await _renameGroup(oldGroup: group, newGroup: '');
  }

  Set<String> _splitGroupsForGroupMutation(String rawGroup) {
    final groups = <String>{};
    for (final part in rawGroup.split(_groupSplitPattern)) {
      final group = part.trim();
      if (group.isEmpty) {
        continue;
      }
      groups.add(group);
    }
    return groups;
  }

  String _joinGroupsForGroupMutation(Set<String> groups) {
    if (groups.isEmpty) {
      return '';
    }
    return groups.join(',');
  }

  Widget _empty() {
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 86),
      title: '暂无规则',
      message: '可通过新建或导入创建替换净化规则',
      action: CupertinoButton.filled(
        onPressed: _createRule,
        child: const Text('新建规则'),
      ),
    );
  }

  Widget _buildList(List<ReplaceRule> rules) {
    return ReplaceRuleListItems(
      rules: rules,
      selectedRuleIds: _selectedRuleIds,
      selectionMode: _selectionMode,
      onToggleSelection: _toggleRuleSelection,
      onUpdateRule: (r) => _repo.updateRule(r),
      onEditRule: _editRule,
      onShowRuleItemMenu: _showRuleItemMenu,
    );
  }

  void _createRule() {
    _editRule(ReplaceRule.create());
  }

  int _nextReplaceRuleOrder() {
    var maxOrder = ReplaceRule.unsetOrder;
    for (final rule in _repo.getAllRules()) {
      if (rule.order > maxOrder) {
        maxOrder = rule.order;
      }
    }
    return maxOrder + 1;
  }

  ReplaceRule _normalizeRuleForSave(ReplaceRule rule) {
    if (rule.order != ReplaceRule.unsetOrder) {
      return rule;
    }
    return rule.copyWith(order: _nextReplaceRuleOrder());
  }

  void _editRule(ReplaceRule rule) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReplaceRuleEditView(
          initial: rule,
          onSave: (next) async {
            await _repo.addRule(_normalizeRuleForSave(next));
          },
        ),
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy || !mounted) return;
    final action = await showReplaceRuleTopMenu(
      context: context,
      anchorKey: _moreMenuKey,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ReplaceRuleTopMenuAction.create:
        _createRule();
      case ReplaceRuleTopMenuAction.importFile:
        _importFromFile();
      case ReplaceRuleTopMenuAction.importUrl:
        _importFromUrl();
      case ReplaceRuleTopMenuAction.importQr:
        _importFromQr();
      case ReplaceRuleTopMenuAction.help:
        _showReplaceRuleHelp();
    }
  }

  Future<void> _showRuleItemMenu(ReplaceRule rule) async {
    final action = await showReplaceRuleItemMenu(context: context, rule: rule);
    if (action == null || !mounted) return;
    switch (action) {
      case ReplaceRuleItemMenuAction.top:
        await _moveRuleToTop(rule);
      case ReplaceRuleItemMenuAction.bottom:
        await _moveRuleToBottom(rule);
      case ReplaceRuleItemMenuAction.delete:
        if (_selectedRuleIds.remove(rule.id)) setState(() {});
        await _confirmDeleteRule(rule);
    }
  }

  Future<void> _confirmDeleteRule(ReplaceRule rule) async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n${rule.name}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _repo.deleteRule(rule.id);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.delete',
        message: '删除替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'ruleId': rule.id,
          'ruleName': rule.name,
        },
      );
    }
  }

  Future<void> _confirmDeleteSelectedRules(
      List<ReplaceRule> visibleRules) async {
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: const Text('是否确认删除？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _deleteSelectedRules(selectedRules);
  }

  Future<void> _deleteSelectedRules(List<ReplaceRule> selectedRules) async {
    if (_deletingSelection || selectedRules.isEmpty) return;
    setState(() => _deletingSelection = true);
    try {
      final targetIds = selectedRules.map((rule) => rule.id).toSet();
      await _repo.deleteRulesByIds(targetIds);
      _selectedRuleIds.removeWhere(targetIds.contains);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.delete_selection',
        message: '批量删除替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
    } finally {
      if (!mounted) return;
      setState(() => _deletingSelection = false);
    }
  }

  Future<void> _moveRuleToTop(ReplaceRule rule) async {
    try {
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var minOrder = allRules.first.order;
      for (final current in allRules.skip(1)) {
        if (current.order < minOrder) {
          minOrder = current.order;
        }
      }
      await _repo.addRule(rule.copyWith(order: minOrder - 1));
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.move_top',
        message: '替换规则置顶失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'ruleId': rule.id,
          'ruleName': rule.name,
        },
      );
    }
  }

  Future<void> _moveRuleToBottom(ReplaceRule rule) async {
    try {
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var maxOrder = allRules.first.order;
      for (final current in allRules.skip(1)) {
        if (current.order > maxOrder) {
          maxOrder = current.order;
        }
      }
      await _repo.addRule(rule.copyWith(order: maxOrder + 1));
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.move_bottom',
        message: '替换规则置底失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'ruleId': rule.id,
          'ruleName': rule.name,
        },
      );
    }
  }

  Future<void> _showSelectionMoreMenu(List<ReplaceRule> visibleRules) async {
    if (_menuBusy || _selectedCountIn(visibleRules) == 0) return;
    final selected = await showReplaceRuleSelectionPopoverMenu(
      context: context,
      anchorKey: _moreMenuKey,
    );
    if (selected == null) return;
    switch (selected) {
      case ReplaceRuleSelectionMenuAction.enableSelection:
        await _enableSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.disableSelection:
        await _disableSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.topSelection:
        await _topSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.bottomSelection:
        await _bottomSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.exportSelection:
        await _exportSelectedRules(visibleRules);
    }
  }

  List<ReplaceRule> _selectedRulesByCurrentOrder(
      List<ReplaceRule> visibleRules) {
    if (visibleRules.isEmpty) return const <ReplaceRule>[];
    return visibleRules
        .where((rule) => _selectedRuleIds.contains(rule.id))
        .toList(growable: false);
  }

  Future<void> _exportSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_exportingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _exportingSelection = true);
    try {
      final jsonText = LegadoJson.encode(
        selectedRules.map((rule) => rule.toJson()).toList(growable: false),
      );
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出所选',
        fileName: 'exportReplaceRule.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      if (!mounted) return;
      await _showExportPathDialog(normalizedPath);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.export_selection',
        message: '导出所选替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导出所选',
        message: '导出失败：$error',
      );
    } finally {
      if (!mounted) return;
      setState(() => _exportingSelection = false);
    }
  }

  Future<void> _enableSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_enablingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _enablingSelection = true);
    try {
      await enableSelectedReplaceRules(
          repo: _repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.enable_selection',
        message: '批量启用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
      );
    } finally {
      if (!mounted) return;
      setState(() => _enablingSelection = false);
    }
  }

  Future<void> _disableSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_disablingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _disablingSelection = true);
    try {
      await disableSelectedReplaceRules(
          repo: _repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.disable_selection',
        message: '批量禁用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
      );
    } finally {
      if (!mounted) return;
      setState(() => _disablingSelection = false);
    }
  }

  Future<void> _topSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_toppingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _toppingSelection = true);
    try {
      await topSelectedReplaceRules(
          repo: _repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.top_selection',
        message: '批量置顶替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
      );
    } finally {
      if (!mounted) return;
      setState(() => _toppingSelection = false);
    }
  }

  Future<void> _bottomSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_bottomingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _bottomingSelection = true);
    try {
      await bottomSelectedReplaceRules(
          repo: _repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.bottom_selection',
        message: '批量置底替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
      );
    } finally {
      if (!mounted) return;
      setState(() => _bottomingSelection = false);
    }
  }



  // --- from replace_rule_list_view_import.dart ---
  Future<void> _importFromFile() async {
    if (_importingLocal) return;
    setState(() => _importingLocal = true);
    try {
      final localText = await pickLocalReplaceRuleImportText();
      if (localText == null) {
        return;
      }
      await _importRulesFromInput(localText);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_local',
        message: '本地导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: formatReplaceRuleImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingLocal = false);
      }
    }
  }

  Future<void> _importFromUrl() async {
    if (_importingOnline) return;
    setState(() => _importingOnline = true);
    try {
      final rawInput = await _showOnlineImportInputSheet();
      final normalizedInput = sanitizeReplaceRuleImportInput(rawInput ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      if (isReplaceRuleHttpUrl(normalizedInput)) {
        await _pushOnlineImportHistory(normalizedInput);
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_online',
        message: '网络导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: formatReplaceRuleImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingOnline = false);
      }
    }
  }

  Future<void> _importFromQr() async {
    if (_importingQr) return;
    setState(() => _importingQr = true);
    try {
      final text = await QrScanService.scanText(
        context,
        title: '二维码导入',
      );
      final normalizedInput = sanitizeReplaceRuleImportInput(text ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_qr',
        message: '二维码导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: formatReplaceRuleImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingQr = false);
      }
    }
  }

  Future<void> _importRulesFromInput(String rawInput) async {
    final importedRules = await parseReplaceRuleImportRulesFromInput(
        io: _io, input: rawInput, depth: 0);
    final candidates = buildReplaceRuleImportCandidates(
      importedRules: importedRules,
      localRules: _repo.getAllRules(),
    );
    if (candidates.isEmpty) {
      await _showMessageDialog(
        title: '导入替换规则',
        message: 'ImportError:格式不对',
      );
      return;
    }
    if (!mounted) return;
    final selectionDecision = await _showImportSelectionSheet(candidates);
    if (selectionDecision == null ||
        selectionDecision.selectedIndexes.isEmpty) {
      return;
    }
    if (!mounted) return;
    await _runImportingTask(() async {
      final selectedRules = <ReplaceRule>[];
      final sortedIndexes = selectionDecision.selectedIndexes.toList()..sort();
      for (final index in sortedIndexes) {
        if (index < 0 || index >= candidates.length) continue;
        selectedRules.add(
          applyReplaceRuleImportGroupPolicy(
            rule: candidates[index].rule,
            policy: selectionDecision.groupPolicy,
          ),
        );
      }
      await _repo.addRules(selectedRules);
    });
  }

  Future<String?> _showOnlineImportInputSheet() {
    return showReplaceRuleOnlineImportSheet(
      context: context,
      loadHistory: _loadOnlineImportHistory,
      saveHistory: _saveOnlineImportHistory,
    );
  }

  Future<List<String>> _loadOnlineImportHistory() async {
    return _onlineImportHistoryStore.load(_ReplaceRuleListViewState._onlineImportHistoryKey);
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    await _onlineImportHistoryStore.save(_ReplaceRuleListViewState._onlineImportHistoryKey, history);
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    await _onlineImportHistoryStore.push(_ReplaceRuleListViewState._onlineImportHistoryKey, url);
  }

  Future<void> _showExportPathDialog(String outputPath) =>
      showReplaceRuleExportPathDialog(
          context: context, outputPath: outputPath);

  Future<void> _showReplaceRuleHelp() => showReplaceRuleHelp(context);

  Future<ReplaceRuleImportSelectionDecision?> _showImportSelectionSheet(
    List<ReplaceRuleImportCandidate> candidates,
  ) =>
      showReplaceRuleImportSelectionSheet(
        context: context,
        candidates: candidates,
      );


  Future<void> _runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CupertinoAlertDialog(
        content: AppBlockingProgress(text: '导入中...'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    try {
      await task();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }


  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) =>
      showReplaceRuleMessageDialog(
          context: context, title: title, message: message);
}

