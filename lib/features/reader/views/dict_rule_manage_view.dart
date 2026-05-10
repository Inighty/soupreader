import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../models/dict_rule.dart';
import '../services/dict_rule_store.dart';
import 'dict_rule_edit_view.dart';
import 'dict_rule_manage_actions.dart';
import 'dict_rule_manage_body.dart';
import 'dict_rule_manage_dialogs.dart';
import 'dict_rule_manage_menus.dart';

class DictRuleManageView extends StatefulWidget {
  const DictRuleManageView({super.key});

  @override
  State<DictRuleManageView> createState() => _DictRuleManageViewState();
}

class _DictRuleManageViewState extends State<DictRuleManageView> {
  static const String _onlineImportHistoryKey = 'dictRuleUrls';

  final DictRuleStore _ruleStore = DictRuleStore();
  final GlobalKey _moreMenuKey = GlobalKey();
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  bool _loading = true;
  bool _importingDefault = false;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _importingQr = false;
  bool _exportingSelection = false;
  bool _enablingSelection = false;
  bool _disablingSelection = false;
  bool _deletingSelection = false;
  bool _selectionMode = false;
  List<DictRule> _rules = const <DictRule>[];
  final Set<String> _selectedRuleNames = <String>{};

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  bool get _selectionUpdating => _enablingSelection || _disablingSelection;

  bool get _selectionActionBusy =>
      _selectionUpdating || _exportingSelection || _deletingSelection;

  bool get _menuBusy =>
      _importingDefault ||
      _importingLocal ||
      _importingOnline ||
      _importingQr ||
      _selectionUpdating ||
      _exportingSelection ||
      _deletingSelection;

  Future<void> _reloadRules() async {
    if (mounted) setState(() => _loading = true);
    final rules = await _ruleStore.loadRules();
    final sorted = rules.toList()
      ..sort((a, b) {
        final bySort = a.sortNumber.compareTo(b.sortNumber);
        if (bySort != 0) return bySort;
        return a.name.compareTo(b.name);
      });
    if (!mounted) return;
    final availableNames = sorted.map((rule) => rule.name).toSet();
    setState(() {
      _rules = sorted;
      _selectedRuleNames.removeWhere((name) => !availableNames.contains(name));
      if (_rules.isEmpty) {
        _selectionMode = false;
        _selectedRuleNames.clear();
      }
      _loading = false;
    });
  }

  void _toggleSelectionMode() {
    if (_rules.isEmpty) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedRuleNames.clear();
    });
  }

  void _toggleRuleSelection(String ruleName) {
    setState(() {
      if (!_selectedRuleNames.add(ruleName)) {
        _selectedRuleNames.remove(ruleName);
      }
    });
  }

  void _toggleSelectAllRules() {
    final totalCount = _rules.length;
    if (totalCount == 0) return;
    setState(() {
      final allSelected = _selectedRuleNames.length == totalCount;
      if (allSelected) {
        _selectedRuleNames.clear();
      } else {
        _selectedRuleNames
          ..clear()
          ..addAll(_rules.map((rule) => rule.name));
      }
    });
  }

  void _revertSelection() {
    if (_rules.isEmpty) return;
    final allNames = _rules.map((rule) => rule.name).toSet();
    setState(() {
      final reverted = allNames.difference(_selectedRuleNames);
      _selectedRuleNames
        ..clear()
        ..addAll(reverted);
    });
  }

  Future<void> _openRuleEditor(DictRule rule) async {
    final savedRule = await Navigator.of(context).push<DictRule>(
      CupertinoPageRoute<DictRule>(
        builder: (_) => DictRuleEditView(initialRule: rule),
      ),
    );
    if (savedRule == null) return;
    try {
      await _ruleStore.saveRule(originalName: rule.name, newRule: savedRule);
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showDictRuleMessageDialog(
        context: context,
        title: '字典规则',
        message: '保存失败：$error',
      );
    }
  }

  Future<void> _deleteRule(DictRule rule) async {
    try {
      await _ruleStore.deleteRulesByNames([rule.name]);
      await _reloadRules();
    } catch (_) {}
  }

  Future<void> _toggleRuleEnabled(DictRule rule, bool enabled) async {
    await _ruleStore.saveRule(
      originalName: rule.name,
      newRule: rule.copyWith(enabled: enabled),
    );
    await _reloadRules();
  }

  Future<void> _onReorderRules(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final mutable = List<DictRule>.from(_rules);
    final moved = mutable.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    mutable.insert(insertAt, moved);
    final reordered = mutable.indexed
        .map((e) => e.$2.copyWith(sortNumber: e.$1))
        .toList(growable: false);
    setState(() => _rules = reordered);
    try {
      await _ruleStore.saveRules(reordered);
    } catch (_) {
      await _reloadRules();
    }
  }

  Future<void> _createRule() => _openRuleEditor(
        const DictRule(
          name: '',
          urlRule: '',
          showRule: '',
          enabled: true,
          sortNumber: 0,
        ),
      );

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showDictRuleMoreMenu(
      context: context,
      anchorKey: _moreMenuKey,
    );
    if (selected == null) return;
    switch (selected) {
      case DictRuleMenuAction.importDefault:
        await _importDefaultRules();
      case DictRuleMenuAction.importLocal:
        await _importLocalRules();
      case DictRuleMenuAction.importOnline:
        await _importOnlineRules();
      case DictRuleMenuAction.importQr:
        await _importQrRules();
      case DictRuleMenuAction.help:
        if (mounted) await showDictRuleHelpDialog(context);
    }
  }

  Future<void> _showSelectionMoreMenu() async {
    if (_menuBusy || _selectedRuleNames.isEmpty) return;
    final selected = await showDictRuleSelectionMoreMenu(
      context: context,
      anchorKey: _moreMenuKey,
    );
    if (selected == null) return;
    switch (selected) {
      case DictRuleSelectionMenuAction.enableSelection:
        await _setEnabledForSelected(enabled: true, busyFlag: (v) => _enablingSelection = v);
      case DictRuleSelectionMenuAction.disableSelection:
        await _setEnabledForSelected(enabled: false, busyFlag: (v) => _disablingSelection = v);
      case DictRuleSelectionMenuAction.exportSelection:
        await _exportSelectedRules();
    }
  }

  Future<void> _setEnabledForSelected({
    required bool enabled,
    required void Function(bool value) busyFlag,
  }) async {
    if (_selectionUpdating || _selectedRuleNames.isEmpty) return;
    setState(() => busyFlag(true));
    try {
      await _ruleStore.setEnabledForRuleNames(
        ruleNames: _selectedRuleNames,
        enabled: enabled,
      );
      await _reloadRules();
    } catch (_) {
      // noop
    } finally {
      if (mounted) setState(() => busyFlag(false));
    }
  }

  Future<void> _deleteSelectedRules() async {
    if (_deletingSelection || _selectedRuleNames.isEmpty) return;
    final selectedNames = _selectedRuleNames.toSet();
    setState(() => _deletingSelection = true);
    try {
      await _ruleStore.deleteRulesByNames(selectedNames);
      await _reloadRules();
    } catch (_) {
      // noop
    } finally {
      if (mounted) setState(() => _deletingSelection = false);
    }
  }

  List<DictRule> _selectedRulesByCurrentOrder() {
    if (_selectedRuleNames.isEmpty) return const <DictRule>[];
    return _rules
        .where((rule) => _selectedRuleNames.contains(rule.name))
        .toList(growable: false);
  }

  Future<void> _exportSelectedRules() async {
    if (_exportingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder();
    if (selectedRules.isEmpty) return;
    setState(() => _exportingSelection = true);
    try {
      final jsonText = DictRule.listToJsonText(selectedRules);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出所选',
        fileName: 'exportDictRule.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      final normalized = outputPath?.trim() ?? '';
      if (normalized.isEmpty || !mounted) return;
      await showDictRuleExportPathDialog(
        context: context,
        outputPath: normalized,
        onToast: (_) {},
      );
    } catch (error) {
      if (!mounted) return;
      await showDictRuleMessageDialog(
        context: context,
        title: '导出所选',
        message: '导出失败：$error',
      );
    } finally {
      if (mounted) setState(() => _exportingSelection = false);
    }
  }

  Future<void> _importDefaultRules() async {
    if (_importingDefault) return;
    setState(() => _importingDefault = true);
    try {
      await _ruleStore.importDefaultRules();
      await _reloadRules();
    } catch (_) {
      // noop
    } finally {
      if (mounted) setState(() => _importingDefault = false);
    }
  }

  Future<void> _importLocalRules() async {
    if (_importingLocal) return;
    setState(() => _importingLocal = true);
    try {
      final fileText = await pickDictRuleLocalImportText();
      if (fileText == null || !mounted) return;
      await importDictRulesFromInput(
        context: context,
        ruleStore: _ruleStore,
        rawInput: fileText,
      );
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showDictRuleMessageDialog(
        context: context,
        title: '导入字典规则',
        message: formatDictRuleImportError(error),
      );
    } finally {
      if (mounted) setState(() => _importingLocal = false);
    }
  }

  Future<void> _importOnlineRules() async {
    if (_importingOnline) return;
    setState(() => _importingOnline = true);
    try {
      final history =
          await _onlineImportHistoryStore.load(_onlineImportHistoryKey);
      if (!mounted) return;
      final rawInput = await showDictRuleOnlineImportInputSheet(
        context: context,
        history: history,
        onPersistHistory: (next) =>
            _onlineImportHistoryStore.save(_onlineImportHistoryKey, next),
      );
      final normalizedInput = rawInput?.trim();
      if (normalizedInput == null || normalizedInput.isEmpty) return;
      if (isDictRuleHttpUrl(normalizedInput)) {
        await _onlineImportHistoryStore.push(
          _onlineImportHistoryKey,
          normalizedInput,
        );
      }
      if (!mounted) return;
      await importDictRulesFromInput(
        context: context,
        ruleStore: _ruleStore,
        rawInput: normalizedInput,
      );
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showDictRuleMessageDialog(
        context: context,
        title: '导入字典规则',
        message: formatDictRuleImportError(error),
      );
    } finally {
      if (mounted) setState(() => _importingOnline = false);
    }
  }

  Future<void> _importQrRules() async {
    if (_importingQr) return;
    setState(() => _importingQr = true);
    try {
      await importDictRulesFromQr(
        context: context,
        ruleStore: _ruleStore,
      );
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showDictRuleMessageDialog(
        context: context,
        title: '导入字典规则',
        message: formatDictRuleImportError(error),
      );
    } finally {
      if (mounted) setState(() => _importingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedRuleNames.length;
    final totalCount = _rules.length;
    final hasSelection = selectedCount > 0;
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return AppCupertinoPageScaffold(
      title: '配置字典规则',
      trailing: DictRuleNavTrailingActions(
        moreMenuKey: _moreMenuKey,
        menuBusy: _menuBusy,
        selectionMode: _selectionMode,
        hasRules: _rules.isNotEmpty,
        hasSelection: hasSelection,
        selectionActionBusy: _selectionActionBusy,
        onAdd: _createRule,
        onToggleSelection: _toggleSelectionMode,
        onShowMoreMenu: _showMoreMenu,
        onShowSelectionMoreMenu: _showSelectionMoreMenu,
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Expanded(
                  child: DictRuleManageList(
                    rules: _rules,
                    selectionMode: _selectionMode,
                    selectedRuleNames: _selectedRuleNames,
                    onReorder: _onReorderRules,
                    onToggleSelection: _toggleRuleSelection,
                    onOpenEditor: _openRuleEditor,
                    onToggleEnabled: _toggleRuleEnabled,
                    onDelete: _deleteRule,
                  ),
                ),
                if (_selectionMode)
                  DictRuleSelectionBottomBar(
                    selectedCount: selectedCount,
                    totalCount: totalCount,
                    hasSelection: hasSelection,
                    allSelected: allSelected,
                    menuBusy: _menuBusy,
                    deletingSelection: _deletingSelection,
                    selectionActionBusy: _selectionActionBusy,
                    onToggleSelectAll: _toggleSelectAllRules,
                    onRevertSelection: _revertSelection,
                    onDeleteSelection: _deleteSelectedRules,
                    onShowSelectionMoreMenu: _showSelectionMoreMenu,
                  ),
              ],
            ),
    );
  }
}
