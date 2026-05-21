// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../../../core/utils/legado_json.dart';
import '../models/replace_rule.dart';
import 'replace_rule_import_types.dart';
import 'replace_rule_list_import_flow.dart';
import 'replace_rule_list_menus.dart';
import 'replace_rule_list_selection_actions.dart';
import 'replace_rule_list_selection_state.dart';
import 'replace_rule_list_view.dart';

extension ReplaceRuleListBulkActions on ReplaceRuleListViewState {
  Future<void> confirmDeleteSelectedRules(
    List<ReplaceRule> visibleRules,
  ) async {
    final selectedRules = selectedRulesByCurrentOrder(visibleRules);
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
    if (confirmed != true) return;
    await deleteSelectedRules(selectedRules);
  }

  Future<void> deleteSelectedRules(List<ReplaceRule> selectedRules) async {
    if (deletingSelection || selectedRules.isEmpty) return;
    setState(() => deletingSelection = true);
    try {
      final targetIds = selectedRules.map((rule) => rule.id).toSet();
      await repo.deleteRulesByIds(targetIds);
      selectedRuleIds.removeWhere(targetIds.contains);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.delete_selection',
        message: '批量删除替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
      );
    } finally {
      if (!mounted) return;
      setState(() => deletingSelection = false);
    }
  }

  Future<void> showSelectionMoreMenu(List<ReplaceRule> visibleRules) async {
    if (menuBusy || selectedCountIn(visibleRules) == 0) return;
    final selected = await showReplaceRuleSelectionPopoverMenu(
      context: context,
      anchorKey: moreMenuKey,
    );
    if (selected == null) return;
    switch (selected) {
      case ReplaceRuleSelectionMenuAction.enableSelection:
        await enableSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.disableSelection:
        await disableSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.topSelection:
        await topSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.bottomSelection:
        await bottomSelectedRules(visibleRules);
      case ReplaceRuleSelectionMenuAction.exportSelection:
        await exportSelectedRules(visibleRules);
    }
  }

  Future<void> exportSelectedRules(List<ReplaceRule> visibleRules) async {
    if (exportingSelection) return;
    final selectedRules = selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => exportingSelection = true);
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
      if (outputPath == null || outputPath.trim().isEmpty) return;
      if (!mounted) return;
      await showExportPathDialog(outputPath.trim());
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.export_selection',
        message: '导出所选替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
      );
      if (!mounted) return;
      await showMessageDialog(title: '导出所选', message: '导出失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => exportingSelection = false);
    }
  }

  Future<void> enableSelectedRules(List<ReplaceRule> visibleRules) async {
    if (enablingSelection) return;
    final selectedRules = selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => enablingSelection = true);
    try {
      await enableSelectedReplaceRules(
          repo: repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      _recordSelectionError(
        node: 'replace_rule.enable_selection',
        message: '批量启用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        selectedRules: selectedRules,
      );
    } finally {
      if (!mounted) return;
      setState(() => enablingSelection = false);
    }
  }

  Future<void> disableSelectedRules(List<ReplaceRule> visibleRules) async {
    if (disablingSelection) return;
    final selectedRules = selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => disablingSelection = true);
    try {
      await disableSelectedReplaceRules(
        repo: repo,
        selectedRules: selectedRules,
      );
    } catch (error, stackTrace) {
      _recordSelectionError(
        node: 'replace_rule.disable_selection',
        message: '批量禁用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        selectedRules: selectedRules,
      );
    } finally {
      if (!mounted) return;
      setState(() => disablingSelection = false);
    }
  }

  Future<void> topSelectedRules(List<ReplaceRule> visibleRules) async {
    if (toppingSelection) return;
    final selectedRules = selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => toppingSelection = true);
    try {
      await topSelectedReplaceRules(repo: repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      _recordSelectionError(
        node: 'replace_rule.top_selection',
        message: '批量置顶替换规则失败',
        error: error,
        stackTrace: stackTrace,
        selectedRules: selectedRules,
      );
    } finally {
      if (!mounted) return;
      setState(() => toppingSelection = false);
    }
  }

  Future<void> bottomSelectedRules(List<ReplaceRule> visibleRules) async {
    if (bottomingSelection) return;
    final selectedRules = selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => bottomingSelection = true);
    try {
      await bottomSelectedReplaceRules(
        repo: repo,
        selectedRules: selectedRules,
      );
    } catch (error, stackTrace) {
      _recordSelectionError(
        node: 'replace_rule.bottom_selection',
        message: '批量置底替换规则失败',
        error: error,
        stackTrace: stackTrace,
        selectedRules: selectedRules,
      );
    } finally {
      if (!mounted) return;
      setState(() => bottomingSelection = false);
    }
  }

  void _recordSelectionError({
    required String node,
    required String message,
    required Object error,
    required StackTrace stackTrace,
    required List<ReplaceRule> selectedRules,
  }) {
    recordViewError(
      node: node,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{'count': selectedRules.length},
    );
  }
}
