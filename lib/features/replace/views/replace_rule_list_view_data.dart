part of 'replace_rule_list_view.dart';


enum _ReplaceRuleImportCandidateState {
  newRule,
  update,
  existing,
}

class _ReplaceRuleImportSelectionDecision {
  const _ReplaceRuleImportSelectionDecision({
    required this.selectedIndexes,
    required this.groupPolicy,
  });

  final Set<int> selectedIndexes;
  final _ReplaceRuleImportGroupPolicy groupPolicy;
}

class _ReplaceRuleImportGroupPolicy {
  const _ReplaceRuleImportGroupPolicy({
    required this.groupName,
    required this.appendGroup,
  });

  final String groupName;
  final bool appendGroup;
}

class _ReplaceRuleImportGroupInput {
  const _ReplaceRuleImportGroupInput({
    required this.groupName,
    required this.appendGroup,
  });

  final String groupName;
  final bool appendGroup;
}

enum _ReplaceRuleItemMenuAction {
  top,
  bottom,
  delete,
}

enum _ReplaceRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  topSelection,
  bottomSelection,
  exportSelection,
}

class _ReplaceRuleImportCandidate {
  const _ReplaceRuleImportCandidate({
    required this.rule,
    required this.localRule,
    required this.state,
  });

  final ReplaceRule rule;
  final ReplaceRule? localRule;
  final _ReplaceRuleImportCandidateState state;

  bool get selectedByDefault =>
      state == _ReplaceRuleImportCandidateState.newRule;
}

class _ReplaceRuleImportCandidateTile extends StatelessWidget {
  const _ReplaceRuleImportCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final _ReplaceRuleImportCandidate candidate;
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

  static String _stateLabel(_ReplaceRuleImportCandidateState state) {
    return switch (state) {
      _ReplaceRuleImportCandidateState.newRule => '新增',
      _ReplaceRuleImportCandidateState.update => '更新',
      _ReplaceRuleImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    _ReplaceRuleImportCandidateState state,
  ) {
    return switch (state) {
      _ReplaceRuleImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      _ReplaceRuleImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      _ReplaceRuleImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}


