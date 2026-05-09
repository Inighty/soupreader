import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../models/txt_toc_rule.dart';
import '../services/txt_toc_rule_store.dart';
import 'txt_toc_rule_edit_view.dart';
import 'txt_toc_rule_manage_actions.dart';
import 'txt_toc_rule_manage_body.dart';
import 'txt_toc_rule_manage_dialogs.dart';
import 'txt_toc_rule_manage_menus.dart';

class TxtTocRuleManageView extends StatefulWidget {
  const TxtTocRuleManageView({super.key});

  @override
  State<TxtTocRuleManageView> createState() => _TxtTocRuleManageViewState();
}

class _TxtTocRuleManageViewState extends State<TxtTocRuleManageView> {
  static const String _onlineImportHistoryKey = 'tocRuleUrl';
  static const String _defaultOnlineImportUrl =
      'https://gitee.com/fisher52/YueDuJson/raw/master/myTxtChapterRule.json';

  final TxtTocRuleStore _ruleStore = TxtTocRuleStore();
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
  bool _reorderingRule = false;
  bool _deletingRule = false;
  bool _selectionMode = false;
  List<TxtTocRule> _rules = const <TxtTocRule>[];
  final Set<int> _selectedRuleIds = <int>{};

  bool get _selectionUpdating => _enablingSelection || _disablingSelection;

  bool get _selectionActionBusy =>
      _selectionUpdating || _exportingSelection || _deletingRule;

  bool get _menuBusy =>
      _importingDefault ||
      _importingLocal ||
      _importingOnline ||
      _importingQr ||
      _exportingSelection ||
      _selectionUpdating ||
      _reorderingRule ||
      _deletingRule;

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  Future<void> _reloadRules() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rules = await _ruleStore.loadRules();
      if (!mounted) return;
      final availableIds = rules.map((rule) => rule.id).toSet();
      setState(() {
        _rules = rules;
        _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
        if (_rules.isEmpty) {
          _selectionMode = false;
          _selectedRuleIds.clear();
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleSelectionMode() {
    if (!mounted) return;
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedRuleIds.clear();
    });
  }

  void _toggleRuleSelection(int ruleId) {
    if (!mounted) return;
    setState(() {
      if (!_selectedRuleIds.add(ruleId)) {
        _selectedRuleIds.remove(ruleId);
      }
    });
  }

  void _toggleSelectAllRules() {
    if (!mounted) return;
    setState(() {
      if (_selectedRuleIds.length == _rules.length) {
        _selectedRuleIds.clear();
      } else {
        _selectedRuleIds
          ..clear()
          ..addAll(_rules.map((rule) => rule.id));
      }
    });
  }

  void _revertSelection() {
    if (!mounted) return;
    setState(() {
      final all = _rules.map((rule) => rule.id).toSet();
      final next = all.difference(_selectedRuleIds);
      _selectedRuleIds
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _toggleRuleEnabled(TxtTocRule rule, bool enabled) async {
    try {
      await _ruleStore.upsertRule(rule.copyWith(enabled: enabled));
      await _reloadRules();
    } catch (_) {}
  }

  Future<void> _onReorderRules(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final mutable = List<TxtTocRule>.from(_rules);
    final moved = mutable.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    mutable.insert(insertAt, moved);
    setState(() => _rules = mutable);
    try {
      await _ruleStore.saveRules(mutable);
    } catch (_) {
      await _reloadRules();
    }
  }

  Future<void> _openRuleEditor(TxtTocRule rule) async {
    if (!mounted) return;
    final savedRule = await Navigator.of(context).push<TxtTocRule>(
      CupertinoPageRoute<TxtTocRule>(
        builder: (_) => TxtTocRuleEditView(initialRule: rule),
      ),
    );
    if (savedRule != null && mounted) {
      await _reloadRules();
    }
  }

  Future<void> _startAddRule() async {
    final draftRule = await _ruleStore.createDraftRule();
    if (!mounted) return;
    await _openRuleEditor(draftRule);
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showTxtTocRuleMoreMenu(
      context: context,
      anchorKey: _moreMenuKey,
    );
    if (selected == null) return;
    switch (selected) {
      case TxtTocRuleMenuAction.importDefault:
        await _importDefaultRules();
      case TxtTocRuleMenuAction.importLocal:
        await _importLocalRules();
      case TxtTocRuleMenuAction.importOnline:
        await _importOnlineRules();
      case TxtTocRuleMenuAction.importQr:
        await _importQrRules();
      case TxtTocRuleMenuAction.help:
        if (mounted) await showTxtTocRuleHelpDialog(context);
    }
  }

  Future<void> _showSelectionMoreMenu() async {
    if (_menuBusy || _selectedRuleIds.isEmpty) return;
    final selected = await showTxtTocRuleSelectionMoreMenu(
      context: context,
      anchorKey: _moreMenuKey,
    );
    if (selected == null) return;
    switch (selected) {
      case TxtTocRuleSelectionMenuAction.enableSelection:
        await _enableSelectedRules();
      case TxtTocRuleSelectionMenuAction.disableSelection:
        await _disableSelectedRules();
      case TxtTocRuleSelectionMenuAction.exportSelection:
        await _exportSelectedRules();
    }
  }

  Future<void> _showRuleItemMenu(TxtTocRule rule) async {
    if (_menuBusy || _selectionMode) return;
    final selected = await showTxtTocRuleItemActionSheet(
      context: context,
      ruleName: rule.name,
    );
    if (selected == null) return;
    switch (selected) {
      case TxtTocRuleItemMenuAction.top:
        await _moveRuleToTop(rule);
      case TxtTocRuleItemMenuAction.bottom:
        await _moveRuleToBottom(rule);
      case TxtTocRuleItemMenuAction.delete:
        if (_selectedRuleIds.remove(rule.id)) setState(() {});
        await _confirmDeleteRule(rule);
    }
  }

  Future<void> _confirmDeleteRule(TxtTocRule rule) async {
    final confirmed =
        await confirmTxtTocRuleDelete(context: context, name: rule.name);
    if (!confirmed) return;
    await _runRuleStateOp(
      flag: (v) => _deletingRule = v,
      op: () => _ruleStore.deleteRule(rule.id),
    );
  }

  Future<void> _confirmDeleteSelectedRules() async {
    final selectedIds = _selectedRuleIds.toSet();
    if (selectedIds.isEmpty) return;
    final confirmed = await confirmTxtTocRuleDeleteSelected(
      context: context,
      count: selectedIds.length,
    );
    if (!confirmed) return;
    await _runRuleStateOp(
      flag: (v) => _deletingRule = v,
      op: () => _ruleStore.deleteRulesByIds(selectedIds),
    );
  }

  Future<void> _moveRuleToTop(TxtTocRule rule) => _runRuleStateOp(
        flag: (v) => _reorderingRule = v,
        op: () => _ruleStore.moveRuleToTop(rule),
      );

  Future<void> _moveRuleToBottom(TxtTocRule rule) => _runRuleStateOp(
        flag: (v) => _reorderingRule = v,
        op: () => _ruleStore.moveRuleToBottom(rule),
      );

  Future<void> _enableSelectedRules() async {
    if (_selectionUpdating || _selectedRuleIds.isEmpty) return;
    await _runRuleStateOp(
      flag: (v) => _enablingSelection = v,
      op: () => _ruleStore.enableRulesByIds(_selectedRuleIds),
    );
  }

  Future<void> _disableSelectedRules() async {
    if (_selectionUpdating || _selectedRuleIds.isEmpty) return;
    await _runRuleStateOp(
      flag: (v) => _disablingSelection = v,
      op: () => _ruleStore.disableRulesByIds(_selectedRuleIds),
    );
  }

  /// 通用 wrapper：进入态 → 执行 op → 重载列表 → 离开态。
  Future<void> _runRuleStateOp({
    required void Function(bool value) flag,
    required Future<void> Function() op,
  }) async {
    if (!mounted) return;
    setState(() => flag(true));
    try {
      await op();
      await _reloadRules();
    } catch (_) {
      // noop：UI 仍可继续操作
    } finally {
      if (!mounted) return;
      setState(() => flag(false));
    }
  }

  Future<void> _exportSelectedRules() async {
    if (_exportingSelection) return;
    final selectedRules = _rules
        .where((rule) => _selectedRuleIds.contains(rule.id))
        .toList(growable: false);
    if (selectedRules.isEmpty) return;
    setState(() => _exportingSelection = true);
    try {
      final jsonText = TxtTocRule.listToJsonText(selectedRules);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出所选',
        fileName: 'exportTxtTocRule.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      final normalized = outputPath?.trim() ?? '';
      if (normalized.isEmpty || !mounted) return;
      await showTxtTocRuleExportPathDialog(
        context: context,
        outputPath: normalized,
        onToast: _toast,
      );
    } catch (error) {
      if (!mounted) return;
      await showTxtTocRuleMessageDialog(
        context: context,
        title: '导出所选',
        message: '导出失败：$error',
      );
    } finally {
      if (!mounted) return;
      setState(() => _exportingSelection = false);
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
      if (!mounted) return;
      setState(() => _importingDefault = false);
    }
  }

  Future<void> _importLocalRules() async {
    if (_importingLocal) return;
    setState(() => _importingLocal = true);
    try {
      final fileText = await pickTxtTocRuleLocalImportText();
      if (fileText == null || !mounted) return;
      await importTxtTocRulesFromInput(
        context: context,
        ruleStore: _ruleStore,
        rawInput: fileText,
      );
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showTxtTocRuleMessageDialog(
        context: context,
        title: '导入 TXT 目录规则',
        message: formatTxtTocRuleImportError(error),
      );
    } finally {
      if (!mounted) return;
      setState(() => _importingLocal = false);
    }
  }

  Future<void> _importOnlineRules() async {
    if (_importingOnline) return;
    setState(() => _importingOnline = true);
    try {
      final persistedHistory =
          await _onlineImportHistoryStore.load(_onlineImportHistoryKey);
      final history = _onlineImportHistoryStore.normalize(
        <String>[_defaultOnlineImportUrl, ...persistedHistory],
      );
      if (!mounted) return;
      final rawInput = await showTxtTocRuleOnlineImportInputSheet(
        context: context,
        history: history,
        onPersistHistory: (next) =>
            _onlineImportHistoryStore.save(_onlineImportHistoryKey, next),
      );
      final normalizedInput = rawInput?.trim();
      if (normalizedInput == null || normalizedInput.isEmpty) return;
      if (isTxtTocRuleHttpUrl(normalizedInput)) {
        await _onlineImportHistoryStore.push(
          _onlineImportHistoryKey,
          normalizedInput,
        );
      }
      if (!mounted) return;
      await importTxtTocRulesFromInput(
        context: context,
        ruleStore: _ruleStore,
        rawInput: normalizedInput,
      );
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showTxtTocRuleMessageDialog(
        context: context,
        title: '导入 TXT 目录规则',
        message: formatTxtTocRuleImportError(error),
      );
    } finally {
      if (!mounted) return;
      setState(() => _importingOnline = false);
    }
  }

  Future<void> _importQrRules() async {
    if (_importingQr) return;
    setState(() => _importingQr = true);
    try {
      await importTxtTocRulesFromQr(
        context: context,
        ruleStore: _ruleStore,
      );
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showTxtTocRuleMessageDialog(
        context: context,
        title: '导入 TXT 目录规则',
        message: formatTxtTocRuleImportError(error),
      );
    } finally {
      if (!mounted) return;
      setState(() => _importingQr = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedRuleIds.length;
    final totalCount = _rules.length;
    final hasSelection = selectedCount > 0;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    return AppCupertinoPageScaffold(
      title: 'TXT 目录规则',
      trailing: TxtTocRuleNavTrailingActions(
        moreMenuKey: _moreMenuKey,
        menuBusy: _menuBusy,
        selectionMode: _selectionMode,
        hasRules: _rules.isNotEmpty,
        hasSelection: hasSelection,
        selectionActionBusy: _selectionActionBusy,
        onAdd: _startAddRule,
        onToggleSelection: _toggleSelectionMode,
        onShowMoreMenu: _showMoreMenu,
        onShowSelectionMoreMenu: _showSelectionMoreMenu,
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Expanded(
                  child: TxtTocRuleManageList(
                    rules: _rules,
                    selectionMode: _selectionMode,
                    selectedRuleIds: _selectedRuleIds,
                    onReorder: _onReorderRules,
                    onToggleSelection: _toggleRuleSelection,
                    onOpenEditor: _openRuleEditor,
                    onToggleEnabled: _toggleRuleEnabled,
                    onShowItemMenu: _showRuleItemMenu,
                  ),
                ),
                if (_selectionMode)
                  TxtTocRuleSelectionBottomBar(
                    selectedCount: selectedCount,
                    totalCount: totalCount,
                    hasSelection: hasSelection,
                    allSelected: allSelected,
                    menuBusy: _menuBusy,
                    deletingRule: _deletingRule,
                    selectionActionBusy: _selectionActionBusy,
                    onToggleSelectAll: _toggleSelectAllRules,
                    onRevertSelection: _revertSelection,
                    onConfirmDeleteSelected: _confirmDeleteSelectedRules,
                    onShowSelectionMoreMenu: _showSelectionMoreMenu,
                  ),
              ],
            ),
    );
  }
}
