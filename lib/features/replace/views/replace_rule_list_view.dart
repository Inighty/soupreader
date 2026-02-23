import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/legado_json.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../models/replace_rule.dart';
import '../services/replace_rule_import_export_service.dart';
import 'replace_rule_edit_view.dart';

class ReplaceRuleListView extends StatefulWidget {
  const ReplaceRuleListView({super.key});

  @override
  State<ReplaceRuleListView> createState() => _ReplaceRuleListViewState();
}

class _ReplaceRuleListViewState extends State<ReplaceRuleListView> {
  static const int _maxImportDepth = 5;
  static const String _requestWithoutUaSuffix = '#requestWithoutUA';
  static const String _onlineImportHistoryKey = 'replaceRuleRecordKey';
  static const String _groupFilterAll = '';
  static const String _groupFilterNoGroup = '__no_group__';
  static const String _noGroupLabel = '未分组';
  static final RegExp _groupSplitPattern = RegExp(r'[,;，；]');

  late final ReplaceRuleRepository _repo;
  final ReplaceRuleImportExportService _io = ReplaceRuleImportExportService();

  String _activeGroupQuery = _groupFilterAll;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _importingQr = false;
  bool _exportingSelection = false;
  bool _enablingSelection = false;
  bool _disablingSelection = false;
  bool _toppingSelection = false;
  bool _bottomingSelection = false;
  bool _selectionMode = false;
  final Set<int> _selectedRuleIds = <int>{};

  bool get _selectionUpdating =>
      _enablingSelection ||
      _disablingSelection ||
      _toppingSelection ||
      _bottomingSelection;

  bool get _menuBusy =>
      _importingLocal ||
      _importingOnline ||
      _importingQr ||
      _exportingSelection ||
      _selectionUpdating;

  @override
  void initState() {
    super.initState();
    _repo = ReplaceRuleRepository(DatabaseService());
  }

  @override
  void dispose() => super.dispose();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReplaceRule>>(
      stream: _repo.watchAllRules(),
      builder: (context, snapshot) {
        final allRules = List<ReplaceRule>.from(
          snapshot.data ?? _repo.getAllRules(),
        )..sort((a, b) => a.order.compareTo(b.order));
        _syncSelectionWithRules(allRules);

        final groups = _buildGroups(allRules);
        final activeGroupQuery = _resolveActiveGroupQuery(groups);
        final rules = _filterRulesByGroupQuery(allRules, activeGroupQuery);
        final selectedCount = _selectedCountIn(rules);
        final totalCount = rules.length;
        final hasSelection = selectedCount > 0;
        final allSelected = totalCount > 0 && selectedCount == totalCount;
        final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
        final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);

        return AppCupertinoPageScaffold(
          title: '文本替换规则',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(30, 30),
                onPressed:
                    _menuBusy ? null : () => _showGroupFilterOptions(allRules),
                child: const Icon(CupertinoIcons.square_grid_2x2),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(30, 30),
                onPressed: _menuBusy || (!_selectionMode && allRules.isEmpty)
                    ? null
                    : () => _toggleSelectionMode(allRules),
                child: Text(
                  _selectionMode ? '完成' : '多选',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(30, 30),
                onPressed: _selectionMode
                    ? (hasSelection && !_menuBusy
                        ? () => _showSelectionMoreMenu(rules)
                        : null)
                    : (_menuBusy ? null : _showMoreMenu),
                child: _selectionMode
                    ? (_exportingSelection || _selectionUpdating
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
                          color: CupertinoColors.systemGrey4.resolveFrom(
                            context,
                          ),
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
                            horizontal: 4,
                            vertical: 6,
                          ),
                          minimumSize: const Size(30, 30),
                          onPressed: hasSelection && !_menuBusy
                              ? () => _showSelectionMoreMenu(rules)
                              : null,
                          child: _exportingSelection || _selectionUpdating
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
        .where((rule) => (rule.group ?? '').contains(query))
        .toList(growable: false);
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

  void _showGroupFilterOptions(List<ReplaceRule> allRules) {
    final groups = _buildGroups(allRules);
    final activeGroupQuery = _resolveActiveGroupQuery(groups);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('分组'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _showGroupManageSheet();
            },
            child: const Text('分组管理'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _applyGroupQuery(_groupFilterAll, popupContext),
            child: Text('${activeGroupQuery == _groupFilterAll ? '✓ ' : ''}全部'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                _applyGroupQuery(_groupFilterNoGroup, popupContext),
            child: Text(
              '${activeGroupQuery == _groupFilterNoGroup ? '✓ ' : ''}$_noGroupLabel',
            ),
          ),
          ...groups.map(
            (group) => CupertinoActionSheetAction(
              onPressed: () => _applyGroupQuery(group, popupContext),
              child: Text('${activeGroupQuery == group ? '✓ ' : ''}$group'),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _applyGroupQuery(String query, BuildContext popupContext) {
    setState(() {
      _activeGroupQuery = query;
      _selectedRuleIds.clear();
    });
    Navigator.pop(popupContext);
  }

  Future<void> _showGroupManageSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SizedBox(
            height:
                math.min(MediaQuery.of(sheetContext).size.height * 0.78, 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '分组管理',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: () async {
                          final name = await _showGroupInputDialog(
                            title: '添加分组',
                          );
                          if (name == null) return;
                          await _addGroupToNoGroupRules(name);
                        },
                        child: const Icon(CupertinoIcons.add_circled),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.systemGrey4.resolveFrom(sheetContext),
                ),
                Expanded(
                  child: StreamBuilder<List<ReplaceRule>>(
                    stream: _repo.watchAllRules(),
                    builder: (context, snapshot) {
                      final allRules = List<ReplaceRule>.from(
                        snapshot.data ?? _repo.getAllRules(),
                      )..sort((a, b) => a.order.compareTo(b.order));
                      final groups = _buildGroups(allRules);
                      if (groups.isEmpty) {
                        return Center(
                          child: Text(
                            '暂无分组',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => Container(
                          height: 0.5,
                          color:
                              CupertinoColors.systemGrey4.resolveFrom(context),
                        ),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(36, 30),
                                  onPressed: () async {
                                    final renamed = await _showGroupInputDialog(
                                      title: '编辑分组',
                                      initialValue: group,
                                    );
                                    if (renamed == null) return;
                                    await _renameGroup(
                                        oldGroup: group, newGroup: renamed);
                                  },
                                  child: const Text('编辑'),
                                ),
                                CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(36, 30),
                                  onPressed: () => _removeGroup(group),
                                  child: const Text(
                                    '删除',
                                    style: TextStyle(
                                      color: CupertinoColors.systemRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showGroupInputDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      final value = await showCupertinoDialog<String>(
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
      debugPrint('AddReplaceRuleGroupError:$error');
      debugPrint('$stackTrace');
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
      debugPrint('RenameReplaceRuleGroupError:$error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _removeGroup(String group) async {
    await _renameGroup(oldGroup: group, newGroup: '');
  }

  Set<String> _splitGroupsForGroupMutation(String rawGroup) {
    final groups = <String>{};
    for (final part in rawGroup.split(',')) {
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.nosign, size: 56),
          const SizedBox(height: 12),
          Text(
            '暂无规则',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: _createRule,
            child: const Text('新建规则'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<ReplaceRule> rules) {
    return ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        final selected = _selectedRuleIds.contains(rule.id);
        final title = rule.name.isEmpty ? '(未命名)' : rule.name;
        final subtitle = [
          if (rule.group != null && rule.group!.trim().isNotEmpty) rule.group!,
          rule.isRegex ? '正则' : '普通',
          rule.isEnabled ? '启用' : '未启用',
        ].join(' · ');
        final tile = CupertinoListTile.notched(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: _selectionMode
              ? Icon(
                  selected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: selected
                      ? CupertinoColors.activeBlue.resolveFrom(context)
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoSwitch(
                      value: rule.isEnabled,
                      onChanged: (v) =>
                          _repo.updateRule(rule.copyWith(isEnabled: v)),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 4, right: 2),
                      minimumSize: const Size(30, 30),
                      onPressed: () => _showRuleItemMenu(rule),
                      child: const Icon(
                        CupertinoIcons.ellipsis,
                        size: 18,
                      ),
                    ),
                  ],
                ),
          onTap: _selectionMode
              ? () => _toggleRuleSelection(rule.id)
              : () => _editRule(rule),
        );
        if (!_selectionMode || !selected) {
          return tile;
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.resolveFrom(context),
          ),
          child: tile,
        );
      },
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

  void _showMoreMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('替换净化规则'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('新建替换'),
            onPressed: () {
              Navigator.pop(context);
              _createRule();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从剪贴板导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromClipboard();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('本地导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromFile();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('网络导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromUrl();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('二维码导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromQr();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出'),
            onPressed: () {
              Navigator.pop(context);
              _export();
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除未启用规则'),
            onPressed: () {
              Navigator.pop(context);
              _repo.deleteDisabledRules();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _showRuleItemMenu(ReplaceRule rule) async {
    final action = await showCupertinoModalPopup<_ReplaceRuleItemMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(rule.name.isEmpty ? '未命名规则' : rule.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleItemMenuAction.top,
            ),
            child: const Text('置顶'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleItemMenuAction.bottom,
            ),
            child: const Text('置底'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleItemMenuAction.delete,
            ),
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (action == null) return;
    switch (action) {
      case _ReplaceRuleItemMenuAction.top:
        await _moveRuleToTop(rule);
        return;
      case _ReplaceRuleItemMenuAction.bottom:
        await _moveRuleToBottom(rule);
        return;
      case _ReplaceRuleItemMenuAction.delete:
        if (_selectedRuleIds.remove(rule.id)) {
          setState(() {});
        }
        await _confirmDeleteRule(rule);
        return;
    }
  }

  Future<void> _confirmDeleteRule(ReplaceRule rule) async {
    final confirmed = await showCupertinoDialog<bool>(
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
      debugPrint('DeleteReplaceRuleError:$error');
      debugPrint('$stackTrace');
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
      debugPrint('TopReplaceRuleError:$error');
      debugPrint('$stackTrace');
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
      debugPrint('BottomReplaceRuleError:$error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _showSelectionMoreMenu(List<ReplaceRule> visibleRules) async {
    if (_menuBusy || _selectedCountIn(visibleRules) == 0) return;
    final selected =
        await showCupertinoModalPopup<_ReplaceRuleSelectionMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('批量操作'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleSelectionMenuAction.enableSelection,
            ),
            child: const Text('启用所选'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleSelectionMenuAction.disableSelection,
            ),
            child: const Text('禁用所选'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleSelectionMenuAction.topSelection,
            ),
            child: const Text('置顶所选'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleSelectionMenuAction.bottomSelection,
            ),
            child: const Text('置底所选'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _ReplaceRuleSelectionMenuAction.exportSelection,
            ),
            child: const Text('导出所选'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case _ReplaceRuleSelectionMenuAction.enableSelection:
        await _enableSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.disableSelection:
        await _disableSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.topSelection:
        await _topSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.bottomSelection:
        await _bottomSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.exportSelection:
        await _exportSelectedRules(visibleRules);
        return;
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
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出所选',
        fileName: 'exportReplaceRule.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      final jsonText = LegadoJson.encode(
        selectedRules.map((rule) => rule.toJson()).toList(growable: false),
      );
      await _writeExportText(normalizedPath, jsonText);
      if (!mounted) return;
      await _showExportPathDialog(normalizedPath);
    } catch (error, stackTrace) {
      debugPrint('ExportReplaceRuleSelectionError:$error');
      debugPrint('$stackTrace');
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
      final updatedRules = selectedRules
          .map((rule) => rule.copyWith(isEnabled: true))
          .toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      debugPrint('EnableSelectionReplaceRuleError:$error');
      debugPrint('$stackTrace');
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
      final updatedRules = selectedRules
          .map((rule) => rule.copyWith(isEnabled: false))
          .toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      debugPrint('DisableSelectionReplaceRuleError:$error');
      debugPrint('$stackTrace');
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
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var minOrder = allRules.first.order;
      for (final rule in allRules.skip(1)) {
        if (rule.order < minOrder) {
          minOrder = rule.order;
        }
      }
      var nextOrder = minOrder - selectedRules.length;
      final updatedRules = selectedRules.map((rule) {
        nextOrder += 1;
        return rule.copyWith(order: nextOrder);
      }).toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      debugPrint('TopSelectionReplaceRuleError:$error');
      debugPrint('$stackTrace');
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
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var maxOrder = allRules.first.order;
      for (final rule in allRules.skip(1)) {
        if (rule.order > maxOrder) {
          maxOrder = rule.order;
        }
      }
      final updatedRules = selectedRules.map((rule) {
        final currentOrder = maxOrder;
        maxOrder += 1;
        return rule.copyWith(order: currentOrder);
      }).toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      debugPrint('BottomSelectionReplaceRuleError:$error');
      debugPrint('$stackTrace');
    } finally {
      if (!mounted) return;
      setState(() => _bottomingSelection = false);
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }
    final result = _io.importFromJson(text);
    if (!result.success) {
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    await _repo.addRules(result.rules);
    _showMessage('成功导入 ${result.rules.length} 条规则');
  }

  Future<void> _importFromFile() async {
    if (_importingLocal) return;
    setState(() => _importingLocal = true);
    try {
      final localText = await _pickLocalImportText();
      if (localText == null) {
        return;
      }
      await _importRulesFromInput(localText);
    } catch (error, stackTrace) {
      debugPrint('ImportReplaceRuleLocalError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
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
      final normalizedInput = _sanitizeImportInput(rawInput ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      if (_isHttpUrl(normalizedInput)) {
        await _pushOnlineImportHistory(normalizedInput);
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      debugPrint('ImportReplaceRuleOnlineError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
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
      final normalizedInput = _sanitizeImportInput(text ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      debugPrint('ImportReplaceRuleQrError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingQr = false);
      }
    }
  }

  Future<void> _importRulesFromInput(String rawInput) async {
    final importedRules = await _parseImportRulesFromInput(rawInput, depth: 0);
    final candidates = _buildImportCandidates(importedRules);
    if (candidates.isEmpty) {
      await _showMessageDialog(
        title: '导入替换规则',
        message: 'ImportError:格式不对',
      );
      return;
    }
    if (!mounted) return;
    final selectedIndexes = await _showImportSelectionSheet(candidates);
    if (selectedIndexes == null || selectedIndexes.isEmpty) {
      return;
    }
    if (!mounted) return;
    await _runImportingTask(() async {
      final selectedRules = <ReplaceRule>[];
      final sortedIndexes = selectedIndexes.toList()..sort();
      for (final index in sortedIndexes) {
        if (index < 0 || index >= candidates.length) {
          continue;
        }
        selectedRules.add(candidates[index].rule);
      }
      await _repo.addRules(selectedRules);
    });
  }

  Future<List<ReplaceRule>> _parseImportRulesFromInput(
    String input, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      throw const FormatException('导入链接重定向层级过深');
    }
    final text = _sanitizeImportInput(input);
    if (text.isEmpty) {
      throw const FormatException('格式不对');
    }
    if (_looksLikeJson(text)) {
      final parsed = _io.importFromJson(text);
      if (parsed.success && parsed.rules.isNotEmpty) {
        return parsed.rules;
      }
      final detail = parsed.errorMessage?.trim();
      throw FormatException(
        detail == null || detail.isEmpty ? '格式不对' : detail,
      );
    }
    final parsedUri = Uri.tryParse(text);
    if (parsedUri != null) {
      final scheme = parsedUri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        final remoteText = await _loadTextFromUrl(text);
        return _parseImportRulesFromInput(remoteText, depth: depth + 1);
      }
      if (scheme == 'file') {
        final localText = await File.fromUri(parsedUri).readAsString();
        return _parseImportRulesFromInput(localText, depth: depth + 1);
      }
    }
    final localFile = File(text);
    if (await localFile.exists()) {
      final localText = await localFile.readAsString();
      return _parseImportRulesFromInput(localText, depth: depth + 1);
    }
    throw const FormatException('格式不对');
  }

  Future<String> _loadTextFromUrl(String rawUrl) async {
    var requestUrl = rawUrl.trim();
    var requestWithoutUa = false;
    if (requestUrl.endsWith(_requestWithoutUaSuffix)) {
      requestWithoutUa = true;
      requestUrl = requestUrl.substring(
        0,
        requestUrl.length - _requestWithoutUaSuffix.length,
      );
    }
    final uri = Uri.parse(requestUrl);
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      if (requestWithoutUa) {
        request.headers.set(HttpHeaders.userAgentHeader, 'null');
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final text = await response.transform(utf8.decoder).join();
      if (_sanitizeImportInput(text).isEmpty) {
        throw const FormatException('格式不对');
      }
      return text;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<String?> _showOnlineImportInputSheet() async {
    final history = await _loadOnlineImportHistory();
    final inputController = TextEditingController();
    try {
      return showCupertinoModalPopup<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(
              height: math.min(MediaQuery.of(context).size.height * 0.72, 560),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '网络导入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(popupContext),
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: inputController,
                                placeholder: 'url',
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  popupContext,
                                  inputController.text.trim(),
                                );
                              },
                              child: const Text('导入'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '历史记录',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: history.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无历史记录',
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey6
                                          .resolveFrom(context),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              inputController.text = item;
                                            },
                                            child: Text(
                                              item,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(28, 28),
                                          onPressed: () async {
                                            history.removeAt(index);
                                            await _saveOnlineImportHistory(
                                              history,
                                            );
                                            if (mounted) {
                                              setDialogState(() {});
                                            }
                                          },
                                          child: const Icon(
                                            CupertinoIcons.delete,
                                            size: 18,
                                            color: CupertinoColors.systemRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      inputController.dispose();
    }
  }

  bool _isHttpUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    final scheme = parsed.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<List<String>> _loadOnlineImportHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final listValue = prefs.getStringList(_onlineImportHistoryKey);
    if (listValue != null) {
      return _normalizeOnlineImportHistory(listValue);
    }
    final textValue = prefs.getString(_onlineImportHistoryKey);
    if (textValue != null && textValue.trim().isNotEmpty) {
      return _normalizeOnlineImportHistory(
        textValue.split(RegExp(r'[\n,]')),
      );
    }
    return <String>[];
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeOnlineImportHistory(history);
    await prefs.setStringList(_onlineImportHistoryKey, normalized);
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    final history = await _loadOnlineImportHistory();
    history.remove(url);
    history.insert(0, url);
    await _saveOnlineImportHistory(history);
  }

  List<String> _normalizeOnlineImportHistory(Iterable<String> values) {
    final unique = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !unique.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  bool _looksLikeJson(String value) {
    return value.startsWith('{') || value.startsWith('[');
  }

  Future<void> _export() async {
    final rules = _repo.getAllRules()
      ..sort((a, b) => a.order.compareTo(b.order));
    final jsonText = LegadoJson.encode(
      rules.map((r) => r.toJson()).toList(growable: false),
    );
    // iOS/Android：保存文件；Web：复制到剪贴板（这里统一复制，避免平台差异）
    await Clipboard.setData(ClipboardData(text: jsonText));
    _showMessage('已复制 JSON（可粘贴保存为 replaceRule.json）');
  }

  Future<void> _writeExportText(String outputPath, String text) async {
    final uri = Uri.tryParse(outputPath);
    if (uri != null && uri.scheme.toLowerCase() == 'file') {
      await File.fromUri(uri).writeAsString(text, flush: true);
      return;
    }
    await File(outputPath).writeAsString(text, flush: true);
  }

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
    if (path.isEmpty || !mounted) return;
    final uri = Uri.tryParse(path);
    final isHttpPath = uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    final lines = <String>[
      '导出路径：',
      path,
      if (isHttpPath) '',
      if (isHttpPath) '检测到网络链接，可直接复制后分享。',
    ];
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  List<_ReplaceRuleImportCandidate> _buildImportCandidates(
    List<ReplaceRule> importedRules,
  ) {
    final localById = <int, ReplaceRule>{
      for (final rule in _repo.getAllRules()) rule.id: rule,
    };
    return importedRules.map((rule) {
      final localRule = localById[rule.id];
      return _ReplaceRuleImportCandidate(
        rule: rule,
        localRule: localRule,
        state: _resolveCandidateState(
          importedRule: rule,
          localRule: localRule,
        ),
      );
    }).toList(growable: false);
  }

  _ReplaceRuleImportCandidateState _resolveCandidateState({
    required ReplaceRule importedRule,
    required ReplaceRule? localRule,
  }) {
    if (localRule == null) {
      return _ReplaceRuleImportCandidateState.newRule;
    }
    if (importedRule.pattern != localRule.pattern ||
        importedRule.replacement != localRule.replacement ||
        importedRule.isRegex != localRule.isRegex ||
        importedRule.scope != localRule.scope) {
      return _ReplaceRuleImportCandidateState.update;
    }
    return _ReplaceRuleImportCandidateState.existing;
  }

  Future<Set<int>?> _showImportSelectionSheet(
    List<_ReplaceRuleImportCandidate> candidates,
  ) async {
    final selectedIndexes = <int>{
      for (var index = 0; index < candidates.length; index++)
        if (candidates[index].selectedByDefault) index,
    };
    return showCupertinoModalPopup<Set<int>>(
      context: context,
      builder: (popupContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedCount = selectedIndexes.length;
              final totalCount = candidates.length;
              final allSelected = totalCount > 0 && selectedCount == totalCount;
              final toggleAllLabel = allSelected
                  ? '取消全选（$selectedCount/$totalCount）'
                  : '全选（$selectedCount/$totalCount）';
              return SizedBox(
                height: math.min(
                  MediaQuery.of(context).size.height * 0.86,
                  680,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '导入替换规则',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => Navigator.pop(popupContext),
                            child: const Text('取消'),
                          ),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: selectedCount == 0
                                ? null
                                : () => Navigator.pop(
                                      popupContext,
                                      selectedIndexes.toSet(),
                                    ),
                            child: Text('导入($selectedCount)'),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: CupertinoColors.systemGrey5.resolveFrom(
                            context,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              if (allSelected) {
                                selectedIndexes.clear();
                              } else {
                                selectedIndexes
                                  ..clear()
                                  ..addAll(
                                    List<int>.generate(
                                      candidates.length,
                                      (index) => index,
                                    ),
                                  );
                              }
                            });
                          },
                          child: Text(toggleAllLabel),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: candidates.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final selected = selectedIndexes.contains(index);
                          return _ReplaceRuleImportCandidateTile(
                            candidate: candidate,
                            selected: selected,
                            onTap: () {
                              setDialogState(() {
                                if (selected) {
                                  selectedIndexes.remove(index);
                                } else {
                                  selectedIndexes.add(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CupertinoAlertDialog(
        content: _BlockingProgressContent(text: '导入中...'),
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

  Future<String?> _pickLocalImportText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return File(path).readAsString();
    }
    throw const FileSystemException('无法读取文件内容');
  }

  String _sanitizeImportInput(String input) {
    var value = input.trim();
    if (value.startsWith('\uFEFF')) {
      value = value.replaceFirst(RegExp(r'^\uFEFF+'), '');
    }
    return value.trim();
  }

  String _formatImportError(Object error) {
    if (error is FileSystemException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'readTextError:ERROR';
      return 'readTextError:$message';
    }
    if (error is FormatException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'ImportError:格式不对';
      return 'ImportError:$message';
    }
    final text = '$error'.trim();
    if (text.isEmpty) return 'ImportError:ERROR';
    if (text.startsWith('Exception:')) {
      final stripped = text.substring('Exception:'.length).trim();
      return stripped.isEmpty ? 'ImportError:ERROR' : 'ImportError:$stripped';
    }
    return 'ImportError:$text';
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

enum _ReplaceRuleImportCandidateState {
  newRule,
  update,
  existing,
}

enum _ReplaceRuleItemMenuAction {
  top,
  bottom,
  delete,
}

enum _ReplaceRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  topSelection,
  bottomSelection,
  exportSelection,
}

class _ReplaceRuleImportCandidate {
  const _ReplaceRuleImportCandidate({
    required this.rule,
    required this.localRule,
    required this.state,
  });

  final ReplaceRule rule;
  final ReplaceRule? localRule;
  final _ReplaceRuleImportCandidateState state;

  bool get selectedByDefault =>
      state == _ReplaceRuleImportCandidateState.newRule;
}

class _ReplaceRuleImportCandidateTile extends StatelessWidget {
  const _ReplaceRuleImportCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final _ReplaceRuleImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final title = candidate.rule.name.trim().isEmpty
        ? '未命名规则'
        : candidate.rule.name.trim();
    final group = candidate.rule.group?.trim();
    final subtitle = group == null || group.isEmpty ? '未分组' : '分组：$group';
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? CupertinoColors.systemGrey5.resolveFrom(context)
              : CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: selected
                    ? CupertinoColors.activeBlue.resolveFrom(context)
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _stateLabel(_ReplaceRuleImportCandidateState state) {
    return switch (state) {
      _ReplaceRuleImportCandidateState.newRule => '新增',
      _ReplaceRuleImportCandidateState.update => '更新',
      _ReplaceRuleImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    _ReplaceRuleImportCandidateState state,
  ) {
    return switch (state) {
      _ReplaceRuleImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      _ReplaceRuleImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      _ReplaceRuleImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}

class _BlockingProgressContent extends StatelessWidget {
  const _BlockingProgressContent({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    );
  }
}
