import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../models/replace_rule.dart';
enum ReplaceRuleImportCandidateState {
  newRule,
  update,
  existing,
}

class ReplaceRuleImportSelectionDecision {
  const ReplaceRuleImportSelectionDecision({
    required this.selectedIndexes,
    required this.groupPolicy,
  });

  final Set<int> selectedIndexes;
  final ReplaceRuleImportGroupPolicy groupPolicy;
}

class ReplaceRuleImportGroupPolicy {
  const ReplaceRuleImportGroupPolicy({
    required this.groupName,
    required this.appendGroup,
  });

  final String groupName;
  final bool appendGroup;
}

class ReplaceRuleImportGroupInput {
  const ReplaceRuleImportGroupInput({
    required this.groupName,
    required this.appendGroup,
  });

  final String groupName;
  final bool appendGroup;
}

enum ReplaceRuleItemMenuAction {
  top,
  bottom,
  delete,
}

enum ReplaceRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  topSelection,
  bottomSelection,
  exportSelection,
}

class ReplaceRuleImportCandidate {
  const ReplaceRuleImportCandidate({
    required this.rule,
    required this.localRule,
    required this.state,
  });

  final ReplaceRule rule;
  final ReplaceRule? localRule;
  final ReplaceRuleImportCandidateState state;

  bool get selectedByDefault =>
      state == ReplaceRuleImportCandidateState.newRule;
}

class ReplaceRuleImportCandidateTile extends StatelessWidget {
  const ReplaceRuleImportCandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final ReplaceRuleImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final title = candidate.rule.name.trim().isEmpty
        ? '未命名规则'
        : candidate.rule.name.trim();
    final group = candidate.rule.group?.trim();
    final subtitle = group == null || group.isEmpty ? '未分组' : '分组：$group';
    final backgroundColor = selected
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : CupertinoColors.systemBackground.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppCard(
        backgroundColor: backgroundColor,
        borderColor: CupertinoColors.separator.resolveFrom(context),
        borderWidth: 0.5,
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
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
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

  static String _stateLabel(ReplaceRuleImportCandidateState state) {
    return switch (state) {
      ReplaceRuleImportCandidateState.newRule => '新增',
      ReplaceRuleImportCandidateState.update => '更新',
      ReplaceRuleImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    ReplaceRuleImportCandidateState state,
  ) {
    return switch (state) {
      ReplaceRuleImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      ReplaceRuleImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      ReplaceRuleImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}
