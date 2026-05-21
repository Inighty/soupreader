// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/replace_rule.dart';
import 'replace_rule_list_filtering.dart';
import 'replace_rule_list_group_sheet.dart';
import 'replace_rule_list_view.dart';

extension ReplaceRuleListGroupActions on ReplaceRuleListViewState {
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
        value: ReplaceRuleListViewState.groupFilterAll,
        icon: activeGroupQuery == ReplaceRuleListViewState.groupFilterAll
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.square_grid_2x2,
        label:
            '${activeGroupQuery == ReplaceRuleListViewState.groupFilterAll ? '✓ ' : ''}全部',
      ),
      AppActionListItem<String>(
        value: ReplaceRuleListViewState.groupFilterNoGroup,
        icon: activeGroupQuery == ReplaceRuleListViewState.groupFilterNoGroup
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.circle,
        label:
            '${activeGroupQuery == ReplaceRuleListViewState.groupFilterNoGroup ? '✓ ' : ''}${ReplaceRuleListViewState.noGroupLabel}',
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
    applyGroupQuery(selected);
  }

  Future<void> _showGroupManageSheet() {
    return showReplaceRuleGroupManageSheet(
      context: context,
      repo: repo,
      buildGroups: buildGroups,
      showGroupInputDialog: ({required title, initialValue}) =>
          _showGroupInputDialog(title: title, initialValue: initialValue ?? ''),
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
        context: <String, dynamic>{'group': normalized},
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
      for (final rule in repo.getAllRules()) {
        final raw = rule.group;
        if (raw == null || raw.isEmpty || !raw.contains(oldGroup)) continue;
        final groups = _splitGroupsForGroupMutation(raw);
        if (!groups.remove(oldGroup)) continue;
        if (nextGroup.isNotEmpty) groups.add(nextGroup);
        updates.add(rule.copyWith(group: _joinGroupsForGroupMutation(groups)));
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

  Future<void> _removeGroup(String group) async {
    await _renameGroup(oldGroup: group, newGroup: '');
  }

  Set<String> _splitGroupsForGroupMutation(String rawGroup) {
    final groups = <String>{};
    for (final part
        in rawGroup.split(ReplaceRuleListViewState.groupSplitPattern)) {
      final group = part.trim();
      if (group.isEmpty) continue;
      groups.add(group);
    }
    return groups;
  }

  String _joinGroupsForGroupMutation(Set<String> groups) {
    if (groups.isEmpty) return '';
    return groups.join(',');
  }
}
