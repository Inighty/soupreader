import 'package:flutter/cupertino.dart';

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
import '../../search/models/search_scope_group_helper.dart';
import '../models/replace_rule.dart';
import '../services/replace_rule_import_export_service.dart';
import 'replace_rule_edit_view.dart';
import 'replace_rule_list_actions.dart';
import 'replace_rule_list_group_sheet.dart';
import 'replace_rule_list_message_dialogs.dart';
import 'replace_rule_list_widgets.dart';



class ReplaceRuleListView extends StatefulWidget {
  const ReplaceRuleListView({super.key});

  @override
  State<ReplaceRuleListView> createState() => ReplaceRuleListViewState();
}

enum ReplaceRuleTopMenuAction {
  create,
  importFile,
  importUrl,
  importQr,
  help,
}

class ReplaceRuleListViewState extends State<ReplaceRuleListView> {
  static const String onlineImportHistoryKey = 'replaceRuleRecordKey';
  static const String _groupFilterAll = '';
  static const String _groupFilterNoGroup = '__no_group__';
  static const String _noGroupLabel = '未分组';
  static final RegExp _groupSplitPattern = RegExp(r'[,;，；]');

  late final ReplaceRuleRepository repo;
  final GlobalKey moreMenuKey = GlobalKey();
  final ReplaceRuleImportExportService io = ReplaceRuleImportExportService();
  final TextEditingController searchController = TextEditingController();
  final OnlineImportHistoryStore onlineImportHistoryStore =
      OnlineImportHistoryStore();

  String activeGroupQuery = _groupFilterAll;
  String searchQuery = '';
  bool changed = false;
  bool dataInited = false;
  bool importingLocal = false;
  bool importingOnline = false;
  bool importingQr = false;
  bool exportingSelection = false;
  bool enablingSelection = false;
  bool disablingSelection = false;
  bool toppingSelection = false;
  bool bottomingSelection = false;
  bool deletingSelection = false;
  bool selectionMode = false;
  final Set<int> selectedRuleIds = <int>{};

  bool get selectionUpdating =>
      enablingSelection ||
      disablingSelection ||
      toppingSelection ||
      bottomingSelection;

  bool get selectionActionBusy =>
      exportingSelection || selectionUpdating || deletingSelection;

  bool get menuBusy =>
      importingLocal ||
      importingOnline ||
      importingQr ||
      exportingSelection ||
      selectionUpdating ||
      deletingSelection;

  @override
  void initState() {
    super.initState();
    repo = ReplaceRuleRepository(DatabaseService());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void markChanged() {
    if (!changed) setState(() => changed = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReplaceRule>>(
      stream: repo.watchAllRules(),
      builder: (context, snapshot) {
        final allRules = List<ReplaceRule>.from(
          snapshot.data ?? repo.getAllRules(),
        )..sort((a, b) => a.order.compareTo(b.order));
        if (dataInited && snapshot.hasData) markChanged();
        dataInited = true;
        syncSelectionWithRules(allRules);

        final groups = buildGroups(allRules);
        final activeGroupQuery = resolveActiveGroupQuery(groups);
        // 对齐 legado：当搜索关键字非空时，优先走搜索分支（含 `group:` 与“未分组”语义）。
        final normalizedSearchQuery = searchQuery.trim();
        final rules = normalizedSearchQuery.isEmpty
            ? filterRulesByGroupQuery(allRules, activeGroupQuery)
            : filterRulesBySearchQueryLikeLegado(
                allRules,
                normalizedSearchQuery,
              );
        final selectedCount = selectedCountIn(rules);
        final totalCount = rules.length;
        final hasSelection = selectedCount > 0;
        final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
        final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);

        return PopScope<bool>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) Navigator.of(context).pop(changed);
          },
          child: AppCupertinoPageScaffold(
          title: '文本替换规则',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNavBarButton(
                onPressed:
                    menuBusy ? null : () => showGroupFilterOptions(allRules),
                child: const Icon(CupertinoIcons.square_grid_2x2),
              ),
              AppNavBarButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: menuBusy || (!selectionMode && allRules.isEmpty)
                    ? null
                    : () => toggleSelectionMode(allRules),
                child: Text(
                  selectionMode ? '完成' : '多选',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              AppNavBarButton(
                key: moreMenuKey,
                onPressed: selectionMode
                    ? (hasSelection && !menuBusy
                        ? () => showSelectionMoreMenu(rules)
                        : null)
                    : (menuBusy ? null : showMoreMenu),
                child: selectionMode
                    ? (selectionActionBusy
                        ? const CupertinoActivityIndicator(radius: 9)
                        : Icon(
                            CupertinoIcons.ellipsis_circle,
                            color: hasSelection ? enabledColor : disabledColor,
                          ))
                    : (menuBusy
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
                  controller: searchController,
                  placeholder: '替换净化搜索',
                  onChanged: onSearchQueryChanged,
                ),
              ),
              Expanded(
                child: rules.isEmpty ? empty() : buildList(rules),
              ),
              if (selectionMode)
                ReplaceRuleSelectionBar(
                  selectedCount: selectedCount,
                  totalCount: totalCount,
                  menuBusy: menuBusy,
                  selectionActionBusy: selectionActionBusy,
                  deletingSelection: deletingSelection,
                  onToggleAll: () => toggleSelectAllRules(rules),
                  onInvert: () => revertSelection(rules),
                  onConfirmDelete: () => confirmDeleteSelectedRules(rules),
                  onShowMore: () => showSelectionMoreMenu(rules),
                ),
            ],
          ),
        ),
      );
      },
    );
  }

  void syncSelectionWithRules(List<ReplaceRule> rules) {
    final availableIds = rules.map((rule) => rule.id).toSet();
    selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
  }

  void toggleSelectionMode(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      selectionMode = !selectionMode;
      selectedRuleIds.clear();
    });
  }

  int selectedCountIn(List<ReplaceRule> rules) {
    var count = 0;
    for (final rule in rules) {
      if (selectedRuleIds.contains(rule.id)) {
        count += 1;
      }
    }
    return count;
  }

  void toggleRuleSelection(int ruleId) {
    setState(() {
      if (selectedRuleIds.contains(ruleId)) {
        selectedRuleIds.remove(ruleId);
      } else {
        selectedRuleIds.add(ruleId);
      }
    });
  }

  void toggleSelectAllRules(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      final allSelected = selectedCountIn(rules) == rules.length;
      if (allSelected) {
        selectedRuleIds.removeAll(rules.map((rule) => rule.id));
      } else {
        selectedRuleIds.addAll(rules.map((rule) => rule.id));
      }
    });
  }

  void revertSelection(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      for (final rule in rules) {
        if (selectedRuleIds.contains(rule.id)) {
          selectedRuleIds.remove(rule.id);
        } else {
          selectedRuleIds.add(rule.id);
        }
      }
    });
  }

  void onSearchQueryChanged(String value) {
    setState(() {
      searchQuery = value;
      // 搜索分支与分组分支在 build 中互斥，输入搜索时无需主动改写分组状态。
      selectedRuleIds.clear();
    });
  }

  List<String> buildGroups(List<ReplaceRule> rules) {
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

  String resolveActiveGroupQuery(List<String> groups) {
    if (activeGroupQuery == _groupFilterAll ||
        activeGroupQuery == _groupFilterNoGroup) {
      return activeGroupQuery;
    }
    if (groups.contains(activeGroupQuery)) {
      return activeGroupQuery;
    }
    return _groupFilterAll;
  }

  List<ReplaceRule> filterRulesByGroupQuery(
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
  List<ReplaceRule> filterRulesBySearchQueryLikeLegado(
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

  Future<void> showGroupFilterOptions(List<ReplaceRule> allRules) async {
    final groups = buildGroups(allRules);
    final activeGroupQuery = resolveActiveGroupQuery(groups);
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
      showGroupManageSheet();
      return;
    }
    applyGroupQuery(selected);
  }

  void applyGroupQuery(String query) {
    setState(() {
      activeGroupQuery = query;
      searchQuery = '';
      selectedRuleIds.clear();
    });
    if (searchController.text.isNotEmpty) {
      searchController.clear();
    }
  }

  void recordViewError({
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

  Future<void> showGroupManageSheet() {
    return showReplaceRuleGroupManageSheet(
      context: context,
      repo: repo,
      buildGroups: buildGroups,
      showGroupInputDialog: ({required title, initialValue}) =>
          showGroupInputDialog(
              title: title, initialValue: initialValue ?? ''),
      addGroupToNoGroupRules: addGroupToNoGroupRules,
      renameGroup: renameGroup,
      removeGroup: removeGroup,
    );
  }

  Future<String?> showGroupInputDialog({
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

  Future<void> addGroupToNoGroupRules(String group) async {
    final normalized = group.trim();
    if (normalized.isEmpty) return;
    try {
      final updates = repo
          .getAllRules()
          .where((rule) {
            final raw = rule.group;
            return raw == null || raw.trim().isEmpty;
          })
          .map((rule) => rule.copyWith(group: normalized))
          .toList(growable: false);
      if (updates.isEmpty) return;
      await repo.addRules(updates);
    } catch (error, stackTrace) {
      recordViewError(
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

  Future<void> renameGroup({
    required String oldGroup,
    required String newGroup,
  }) async {
    final nextGroup = newGroup.trim();
    try {
      final updates = <ReplaceRule>[];
      for (final rule in repo.getAllRules()) {
        final raw = rule.group;
        if (raw == null || raw.isEmpty || !raw.contains(oldGroup)) {
          continue;
        }
        final groups = splitGroupsForGroupMutation(raw);
        if (!groups.remove(oldGroup)) {
          continue;
        }
        if (nextGroup.isNotEmpty) {
          groups.add(nextGroup);
        }
        updates.add(rule.copyWith(group: joinGroupsForGroupMutation(groups)));
      }
      if (updates.isEmpty) return;
      await repo.addRules(updates);
    } catch (error, stackTrace) {
      recordViewError(
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

  Future<void> removeGroup(String group) async {
    await renameGroup(oldGroup: group, newGroup: '');
  }

  Set<String> splitGroupsForGroupMutation(String rawGroup) {
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

  String joinGroupsForGroupMutation(Set<String> groups) {
    if (groups.isEmpty) {
      return '';
    }
    return groups.join(',');
  }

  Widget empty() {
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 86),
      title: '暂无规则',
      message: '可通过新建或导入创建替换净化规则',
      action: CupertinoButton.filled(
        onPressed: createRule,
        child: const Text('新建规则'),
      ),
    );
  }

  Widget buildList(List<ReplaceRule> rules) {
    return ReplaceRuleListItems(
      rules: rules,
      selectedRuleIds: selectedRuleIds,
      selectionMode: selectionMode,
      onToggleSelection: toggleRuleSelection,
      onUpdateRule: (r) => repo.updateRule(r),
      onEditRule: editRule,
      onShowRuleItemMenu: showRuleItemMenu,
    );
  }

  void createRule() {
    editRule(ReplaceRule.create());
  }

  int _nextReplaceRuleOrder() {
    var maxOrder = ReplaceRule.unsetOrder;
    for (final rule in repo.getAllRules()) {
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

  void editRule(ReplaceRule rule) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReplaceRuleEditView(
          initial: rule,
          onSave: (next) async {
            await repo.addRule(_normalizeRuleForSave(next));
          },
        ),
      ),
    );
  }

  Future<void> showMessageDialog({
    required String title,
    required String message,
  }) =>
      showReplaceRuleMessageDialog(
          context: context, title: title, message: message);
}

