import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView;

import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../models/txt_toc_rule.dart';
import 'txt_toc_rule_widgets.dart';

/// 顶部导航栏右侧的「添加 / 多选 / 更多」三键。
class TxtTocRuleNavTrailingActions extends StatelessWidget {
  const TxtTocRuleNavTrailingActions({
    super.key,
    required this.moreMenuKey,
    required this.menuBusy,
    required this.selectionMode,
    required this.hasRules,
    required this.hasSelection,
    required this.selectionActionBusy,
    required this.onAdd,
    required this.onToggleSelection,
    required this.onShowMoreMenu,
    required this.onShowSelectionMoreMenu,
  });

  final GlobalKey moreMenuKey;
  final bool menuBusy;
  final bool selectionMode;
  final bool hasRules;
  final bool hasSelection;
  final bool selectionActionBusy;
  final VoidCallback onAdd;
  final VoidCallback onToggleSelection;
  final VoidCallback onShowMoreMenu;
  final VoidCallback onShowSelectionMoreMenu;

  @override
  Widget build(BuildContext context) {
    final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppNavBarButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(30, 30),
          onPressed: menuBusy || selectionMode ? null : onAdd,
          child: const Text('添加', style: TextStyle(fontSize: 13)),
        ),
        AppNavBarButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(30, 30),
          onPressed:
              menuBusy || (!selectionMode && !hasRules) ? null : onToggleSelection,
          child: Text(
            selectionMode ? '完成' : '多选',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        AppNavBarButton(
          key: moreMenuKey,
          padding: EdgeInsets.zero,
          minimumSize: const Size(30, 30),
          onPressed: selectionMode
              ? (hasSelection && !menuBusy ? onShowSelectionMoreMenu : null)
              : (menuBusy ? null : onShowMoreMenu),
          child: selectionMode
              ? (selectionActionBusy
                  ? const CupertinoActivityIndicator(radius: 9)
                  : Icon(
                      CupertinoIcons.line_horizontal_3,
                      size: 20,
                      color: hasSelection ? enabledColor : disabledColor,
                    ))
              : (menuBusy
                  ? const CupertinoActivityIndicator(radius: 9)
                  : const Icon(CupertinoIcons.line_horizontal_3, size: 20)),
        ),
      ],
    );
  }
}

/// 主体规则列表（空态/拖拽列表/选择列表 三态自动切换）。
class TxtTocRuleManageList extends StatelessWidget {
  const TxtTocRuleManageList({
    super.key,
    required this.rules,
    required this.selectionMode,
    required this.selectedRuleIds,
    required this.onReorder,
    required this.onToggleSelection,
    required this.onOpenEditor,
    required this.onToggleEnabled,
    required this.onShowItemMenu,
  });

  final List<TxtTocRule> rules;
  final bool selectionMode;
  final Set<int> selectedRuleIds;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;
  final void Function(int ruleId) onToggleSelection;
  final Future<void> Function(TxtTocRule rule) onOpenEditor;
  final Future<void> Function(TxtTocRule rule, bool enabled) onToggleEnabled;
  final Future<void> Function(TxtTocRule rule) onShowItemMenu;

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return const AppEmptyState(
        illustration: AppEmptyPlanetIllustration(size: 86),
        title: '暂无目录规则',
        message: '可点击右上角添加，或从本地导入、网络导入、二维码导入。',
      );
    }
    if (selectionMode) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final rule = rules[index];
          return TxtTocRuleListTile(
            rule: rule,
            selectionMode: true,
            selected: selectedRuleIds.contains(rule.id),
            onTap: () => onToggleSelection(rule.id),
            onEditTap: () => onOpenEditor(rule),
            onToggleEnabled: (v) => onToggleEnabled(rule, v),
            onShowItemMenu: null,
          );
        },
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: rules.length,
      buildDefaultDragHandles: false,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return Padding(
          key: ValueKey(rule.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: TxtTocRuleListTile(
            rule: rule,
            selectionMode: false,
            selected: false,
            dragIndex: index,
            onTap: () => onOpenEditor(rule),
            onEditTap: () => onOpenEditor(rule),
            onToggleEnabled: (v) => onToggleEnabled(rule, v),
            onShowItemMenu: () => onShowItemMenu(rule),
          ),
        );
      },
    );
  }
}

/// 选择模式下的底部操作条（全选/反选/删除/更多）。
class TxtTocRuleSelectionBottomBar extends StatelessWidget {
  const TxtTocRuleSelectionBottomBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.hasSelection,
    required this.allSelected,
    required this.menuBusy,
    required this.deletingRule,
    required this.selectionActionBusy,
    required this.onToggleSelectAll,
    required this.onRevertSelection,
    required this.onConfirmDeleteSelected,
    required this.onShowSelectionMoreMenu,
  });

  final int selectedCount;
  final int totalCount;
  final bool hasSelection;
  final bool allSelected;
  final bool menuBusy;
  final bool deletingRule;
  final bool selectionActionBusy;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onRevertSelection;
  final VoidCallback onConfirmDeleteSelected;
  final VoidCallback onShowSelectionMoreMenu;

  @override
  Widget build(BuildContext context) {
    final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(30, 30),
                alignment: Alignment.centerLeft,
                onPressed: totalCount == 0 ? null : onToggleSelectAll,
                child: Text(
                  allSelected
                      ? '取消全选（$selectedCount/$totalCount）'
                      : '全选（$selectedCount/$totalCount）',
                  style: TextStyle(
                    fontSize: 13,
                    color: totalCount == 0 ? disabledColor : enabledColor,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: hasSelection ? onRevertSelection : null,
              child: Text(
                '反选',
                style: TextStyle(
                  fontSize: 13,
                  color: hasSelection ? enabledColor : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: hasSelection && !menuBusy
                  ? onConfirmDeleteSelected
                  : null,
              child: deletingRule
                  ? const CupertinoActivityIndicator(radius: 9)
                  : Text(
                      '删除',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasSelection && !menuBusy
                            ? CupertinoColors.systemRed.resolveFrom(context)
                            : disabledColor,
                      ),
                    ),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: hasSelection && !menuBusy
                  ? onShowSelectionMoreMenu
                  : null,
              child: selectionActionBusy
                  ? const CupertinoActivityIndicator(radius: 9)
                  : Icon(
                      CupertinoIcons.line_horizontal_3,
                      size: 19,
                      color: hasSelection ? enabledColor : disabledColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
