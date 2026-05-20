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
import 'replace_rule_list_view.dart';

/// 顶部菜单 + 单条菜单 + 多选菜单的派发与对应业务（删除/置顶/置底/导出/启用/禁用）。
extension ReplaceRuleListActions on ReplaceRuleListViewState {
  Future<void> showMoreMenu() async {
    if (menuBusy || !mounted) return;
    final action = await showReplaceRuleTopMenu(
      context: context,
      anchorKey: moreMenuKey,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ReplaceRuleTopMenuAction.create:
        createRule();
      case ReplaceRuleTopMenuAction.importFile:
        importFromFile();
      case ReplaceRuleTopMenuAction.importUrl:
        importFromUrl();
      case ReplaceRuleTopMenuAction.importQr:
        importFromQr();
      case ReplaceRuleTopMenuAction.help:
        openReplaceRuleHelp();
    }
  }

  Future<void> showRuleItemMenu(ReplaceRule rule) async {
    final action = await showReplaceRuleItemMenu(context: context, rule: rule);
    if (action == null || !mounted) return;
    switch (action) {
      case ReplaceRuleItemMenuAction.top:
        await moveRuleToTop(rule);
      case ReplaceRuleItemMenuAction.bottom:
        await moveRuleToBottom(rule);
      case ReplaceRuleItemMenuAction.delete:
        if (selectedRuleIds.remove(rule.id)) setState(() {});
        await confirmDeleteRule(rule);
    }
  }

  Future<void> confirmDeleteRule(ReplaceRule rule) async {
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
      await repo.deleteRule(rule.id);
    } catch (error, stackTrace) {
      recordViewError(
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

  Future<void> confirmDeleteSelectedRules(
      List<ReplaceRule> visibleRules) async {
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
    if (confirmed != true) {
      return;
    }
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
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
    } finally {
      if (!mounted) return;
      setState(() => deletingSelection = false);
    }
  }

  Future<void> moveRuleToTop(ReplaceRule rule) async {
    try {
      final allRules = repo.getAllRules();
      if (allRules.isEmpty) return;
      var minOrder = allRules.first.order;
      for (final current in allRules.skip(1)) {
        if (current.order < minOrder) {
          minOrder = current.order;
        }
      }
      await repo.addRule(rule.copyWith(order: minOrder - 1));
    } catch (error, stackTrace) {
      recordViewError(
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

  Future<void> moveRuleToBottom(ReplaceRule rule) async {
    try {
      final allRules = repo.getAllRules();
      if (allRules.isEmpty) return;
      var maxOrder = allRules.first.order;
      for (final current in allRules.skip(1)) {
        if (current.order > maxOrder) {
          maxOrder = current.order;
        }
      }
      await repo.addRule(rule.copyWith(order: maxOrder + 1));
    } catch (error, stackTrace) {
      recordViewError(
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

  List<ReplaceRule> selectedRulesByCurrentOrder(
      List<ReplaceRule> visibleRules) {
    if (visibleRules.isEmpty) return const <ReplaceRule>[];
    return visibleRules
        .where((rule) => selectedRuleIds.contains(rule.id))
        .toList(growable: false);
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
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      if (!mounted) return;
      await showExportPathDialog(normalizedPath);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.export_selection',
        message: '导出所选替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
      if (!mounted) return;
      await showMessageDialog(
        title: '导出所选',
        message: '导出失败：$error',
      );
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
      recordViewError(
        node: 'replace_rule.enable_selection',
        message: '批量启用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
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
          repo: repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.disable_selection',
        message: '批量禁用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
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
      await topSelectedReplaceRules(
          repo: repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.top_selection',
        message: '批量置顶替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
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
          repo: repo, selectedRules: selectedRules);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.bottom_selection',
        message: '批量置底替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'count': selectedRules.length},
      );
    } finally {
      if (!mounted) return;
      setState(() => bottomingSelection = false);
    }
  }
}
