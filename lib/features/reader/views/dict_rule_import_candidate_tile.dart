import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../services/dict_rule_store.dart';

/// 单个待导入候选规则的行视图（新增 / 已有 状态徽标）。
class DictRuleImportCandidateTile extends StatelessWidget {
  const DictRuleImportCandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final DictRuleImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final title = candidate.rule.name.trim().isEmpty
        ? '未命名规则'
        : candidate.rule.name.trim();
    final subtitle = candidate.rule.urlRule.trim().isEmpty
        ? '未配置 URL 规则'
        : candidate.rule.urlRule.trim();
    final backgroundColor = selected
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : CupertinoColors.systemBackground.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppCard(
        backgroundColor: backgroundColor,
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
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }

  static String _stateLabel(DictRuleImportCandidateState state) {
    return switch (state) {
      DictRuleImportCandidateState.newRule => '新增',
      DictRuleImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    DictRuleImportCandidateState state,
  ) {
    return switch (state) {
      DictRuleImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      DictRuleImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}
