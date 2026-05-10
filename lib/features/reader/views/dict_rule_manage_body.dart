import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView, ReorderableDragStartListener;

import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../models/dict_rule.dart';

/// 顶部导航栏右侧的「添加 / 多选 / 更多」三键。
class DictRuleNavTrailingActions extends StatelessWidget {
  const DictRuleNavTrailingActions({
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
        if (!selectionMode)
          AppNavBarButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: menuBusy ? null : onAdd,
            child: const Icon(CupertinoIcons.add),
          ),
        AppNavBarButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onPressed:
              menuBusy || (!selectionMode && !hasRules) ? null : onToggleSelection,
          child: Text(
            selectionMode ? '完成' : '多选',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        AppNavBarButton(
          key: moreMenuKey,
          onPressed: selectionMode
              ? (hasSelection && !menuBusy ? onShowSelectionMoreMenu : null)
              : (menuBusy ? null : onShowMoreMenu),
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
    );
  }
}

/// 主体规则列表（空态 / 拖拽列表 / 选择列表 三态自动切换）。
class DictRuleManageList extends StatelessWidget {
  const DictRuleManageList({
    super.key,
    required this.rules,
    required this.selectionMode,
    required this.selectedRuleNames,
    required this.onReorder,
    required this.onToggleSelection,
    required this.onOpenEditor,
    required this.onToggleEnabled,
    required this.onDelete,
  });

  final List<DictRule> rules;
  final bool selectionMode;
  final Set<String> selectedRuleNames;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;
  final void Function(String ruleName) onToggleSelection;
  final Future<void> Function(DictRule rule) onOpenEditor;
  final Future<void> Function(DictRule rule, bool enabled) onToggleEnabled;
  final Future<void> Function(DictRule rule) onDelete;

  @override
  Widget build(BuildContext context) {
    return AppListView(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      children: [
        if (rules.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppEmptyState(
              illustration: AppEmptyPlanetIllustration(size: 86),
              title: '暂无规则',
              message: '点击右上角添加，或从更多菜单本地导入、网络导入、二维码导入。',
            ),
          )
        else if (!selectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: rules.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return _DictRuleReorderTile(
                  key: ValueKey(rule.name),
                  rule: rule,
                  index: index,
                  onToggleEnabled: (v) => onToggleEnabled(rule, v),
                  onEdit: () => onOpenEditor(rule),
                  onDelete: () => onDelete(rule),
                );
              },
            ),
          )
        else
          AppListSection(
            header: const Text('字典规则'),
            children: rules.map((rule) {
              final title = rule.name.trim().isEmpty
                  ? '未命名规则'
                  : rule.name.trim();
              final subtitle = rule.urlRule.trim().isEmpty
                  ? '未配置 URL 规则'
                  : rule.urlRule.trim();
              final selected = selectedRuleNames.contains(rule.name);
              final tile = CupertinoListTile.notched(
                title: Text(title),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                additionalInfo:
                    rule.enabled ? null : const Text('禁用'),
                trailing: Icon(
                  selected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: selected
                      ? CupertinoColors.activeBlue.resolveFrom(context)
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 20,
                ),
                onTap: () => onToggleSelection(rule.name),
              );
              if (!selected) return tile;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                ),
                child: tile,
              );
            }).toList(growable: false),
          ),
      ],
    );
  }
}

class _DictRuleReorderTile extends StatelessWidget {
  const _DictRuleReorderTile({
    super.key,
    required this.rule,
    required this.index,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final DictRule rule;
  final int index;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = rule.name.trim().isEmpty ? '未命名规则' : rule.name.trim();
    final secLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  CupertinoIcons.bars,
                  size: 18,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            CupertinoSwitch(value: rule.enabled, onChanged: onToggleEnabled),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(36, 36),
              onPressed: onEdit,
              child: Icon(
                CupertinoIcons.pencil,
                size: 18,
                color: secLabel,
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(left: 2, right: 2),
              minimumSize: const Size(36, 36),
              onPressed: onDelete,
              child: Icon(
                CupertinoIcons.delete,
                size: 18,
                color: CupertinoColors.destructiveRed.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 选择模式下的底部操作条（全选/反选/删除/更多）。
class DictRuleSelectionBottomBar extends StatelessWidget {
  const DictRuleSelectionBottomBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.hasSelection,
    required this.allSelected,
    required this.menuBusy,
    required this.deletingSelection,
    required this.selectionActionBusy,
    required this.onToggleSelectAll,
    required this.onRevertSelection,
    required this.onDeleteSelection,
    required this.onShowSelectionMoreMenu,
  });

  final int selectedCount;
  final int totalCount;
  final bool hasSelection;
  final bool allSelected;
  final bool menuBusy;
  final bool deletingSelection;
  final bool selectionActionBusy;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onRevertSelection;
  final VoidCallback onDeleteSelection;
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
              onPressed:
                  hasSelection && !menuBusy ? onDeleteSelection : null,
              child: deletingSelection
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
              onPressed:
                  hasSelection && !menuBusy ? onShowSelectionMoreMenu : null,
              child: selectionActionBusy
                  ? const CupertinoActivityIndicator(radius: 9)
                  : Icon(
                      CupertinoIcons.ellipsis_circle,
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
