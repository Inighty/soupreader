import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../models/replace_rule.dart';

/// 多选模式下的底部操作栏（全选 / 反选 / 删除 / 更多）。
class ReplaceRuleSelectionBar extends StatelessWidget {
  const ReplaceRuleSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.menuBusy,
    required this.selectionActionBusy,
    required this.deletingSelection,
    required this.onToggleAll,
    required this.onInvert,
    required this.onConfirmDelete,
    required this.onShowMore,
  });

  final int selectedCount;
  final int totalCount;
  final bool menuBusy;
  final bool selectionActionBusy;
  final bool deletingSelection;
  final VoidCallback onToggleAll;
  final VoidCallback onInvert;
  final VoidCallback onConfirmDelete;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    final allSelected = totalCount > 0 && selectedCount == totalCount;
    final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        decoration: BoxDecoration(
          color:
              CupertinoColors.systemGroupedBackground.resolveFrom(context),
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
                onPressed: totalCount == 0 ? null : onToggleAll,
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
              onPressed: totalCount == 0 ? null : onInvert,
              child: Text(
                '反选',
                style: TextStyle(
                  fontSize: 13,
                  color: totalCount == 0 ? disabledColor : enabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed:
                  hasSelection && !menuBusy ? onConfirmDelete : null,
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
              onPressed: hasSelection && !menuBusy ? onShowMore : null,
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

/// 列表项展示（含勾选 / 启用开关 / 编辑 / 更多）。
class ReplaceRuleListItems extends StatelessWidget {
  const ReplaceRuleListItems({
    super.key,
    required this.rules,
    required this.selectedRuleIds,
    required this.selectionMode,
    required this.onToggleSelection,
    required this.onUpdateRule,
    required this.onEditRule,
    required this.onShowRuleItemMenu,
  });

  final List<ReplaceRule> rules;
  final Set<int> selectedRuleIds;
  final bool selectionMode;
  final ValueChanged<int> onToggleSelection;
  final ValueChanged<ReplaceRule> onUpdateRule;
  final ValueChanged<ReplaceRule> onEditRule;
  final ValueChanged<ReplaceRule> onShowRuleItemMenu;

  @override
  Widget build(BuildContext context) {
    return AppListView(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      children: [
        for (var index = 0; index < rules.length; index++) ...[
          Builder(
            builder: (context) {
              final rule = rules[index];
              final selected = selectedRuleIds.contains(rule.id);
              final title = rule.name.isEmpty ? '(未命名)' : rule.name;
              final patternPreview = rule.pattern.trim().length > 20
                  ? '${rule.pattern.trim().substring(0, 20)}…'
                  : rule.pattern.trim();
              final replacementPreview = rule.replacement.trim().isEmpty
                  ? '(空)'
                  : (rule.replacement.trim().length > 15
                      ? '${rule.replacement.trim().substring(0, 15)}…'
                      : rule.replacement.trim());
              final rulePreview = patternPreview.isEmpty
                  ? ''
                  : '$patternPreview → $replacementPreview';
              final subtitle = [
                if (rulePreview.isNotEmpty) rulePreview,
                if (rule.group != null && rule.group!.trim().isNotEmpty)
                  rule.group!,
                rule.isRegex ? '正则' : '普通',
                rule.isEnabled ? '启用' : '未启用',
              ].join(' · ');
              final tile = CupertinoListTile.notched(
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: selectionMode
                    ? Icon(
                        selected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        color: selected
                            ? CupertinoColors.activeBlue.resolveFrom(context)
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                        size: 20,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoSwitch(
                            value: rule.isEnabled,
                            onChanged: (v) =>
                                onUpdateRule(rule.copyWith(isEnabled: v)),
                          ),
                          CupertinoButton(
                            padding:
                                const EdgeInsets.only(left: 4, right: 2),
                            minimumSize: const Size(36, 36),
                            onPressed: () => onEditRule(rule),
                            child: Icon(
                              CupertinoIcons.pencil,
                              size: 18,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                          CupertinoButton(
                            padding:
                                const EdgeInsets.only(left: 2, right: 2),
                            minimumSize: const Size(36, 36),
                            onPressed: () => onShowRuleItemMenu(rule),
                            child: Icon(
                              CupertinoIcons.ellipsis_vertical,
                              size: 18,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                onTap: selectionMode
                    ? () => onToggleSelection(rule.id)
                    : () => onEditRule(rule),
              );
              final child = (!selectionMode || !selected)
                  ? tile
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            CupertinoColors.systemGrey6.resolveFrom(context),
                      ),
                      child: tile,
                    );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AppCard(padding: EdgeInsets.zero, child: child),
              );
            },
          ),
          if (index < rules.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
