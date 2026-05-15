import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../models/replace_rule.dart';

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
