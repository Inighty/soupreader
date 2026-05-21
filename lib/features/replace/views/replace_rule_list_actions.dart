// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/replace_rule.dart';
import 'replace_rule_import_types.dart';
import 'replace_rule_list_import_flow.dart';
import 'replace_rule_list_menus.dart';
import 'replace_rule_list_view.dart';

/// 顶部菜单与单条规则菜单派发。
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
    if (confirmed != true) return;
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

  Future<void> moveRuleToTop(ReplaceRule rule) async {
    try {
      final allRules = repo.getAllRules();
      if (allRules.isEmpty) return;
      var minOrder = allRules.first.order;
      for (final current in allRules.skip(1)) {
        if (current.order < minOrder) minOrder = current.order;
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
        if (current.order > maxOrder) maxOrder = current.order;
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
}
