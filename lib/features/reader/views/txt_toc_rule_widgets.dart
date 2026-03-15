import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../models/txt_toc_rule.dart';
import '../services/txt_toc_rule_store.dart';
class TxtTocRuleListTile extends StatelessWidget {
  const TxtTocRuleListTile({
    super.key,
    required this.rule,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onShowItemMenu,
    this.dragIndex,
    this.onEditTap,
    this.onToggleEnabled,
  });

  final TxtTocRule rule;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onShowItemMenu;
  final int? dragIndex;
  final VoidCallback? onEditTap;
  final ValueChanged<bool>? onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final cardColor = selected
        ? CupertinoColors.systemGrey6.resolveFrom(context)
        : CupertinoColors.systemBackground.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (selectionMode) ...[
                  Icon(
                    selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    size: 20,
                    color: selected
                        ? CupertinoColors.activeBlue.resolveFrom(context)
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  const SizedBox(width: 8),
                ] else if (dragIndex != null) ...[
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        CupertinoIcons.bars,
                        size: 18,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    rule.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!selectionMode) ...
                  [
                    CupertinoSwitch(
                      value: rule.enabled,
                      onChanged: onToggleEnabled,
                    ),
                    CupertinoButton(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(36, 36),
                      onPressed: onEditTap ?? onTap,
                      child: Icon(
                        CupertinoIcons.pencil,
                        size: 18,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context)
                            .resolveFrom(context),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 2, right: 2),
                      minimumSize: const Size(36, 36),
                      onPressed: onShowItemMenu,
                      child: Icon(
                        CupertinoIcons.ellipsis_vertical,
                        size: 18,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context)
                            .resolveFrom(context),
                      ),
                    ),
                  ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rule.rule,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: secondary,
              ),
            ),
            if ((rule.example ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '示例：${rule.example!.trim()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TxtTocRuleImportCandidateTile extends StatelessWidget {
  const TxtTocRuleImportCandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final TxtTocRuleImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemGrey6.resolveFrom(context);
    final state = _buildStateText(candidate.state);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusToast),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.scale(
              scale: 0.95,
              child: CupertinoSwitch(
                value: selected,
                onChanged: (_) => onTap(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.rule.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    candidate.rule.rule,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              state,
              style: TextStyle(
                fontSize: 12,
                color: _buildStateColor(context, candidate.state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildStateText(TxtTocRuleImportCandidateState state) {
    switch (state) {
      case TxtTocRuleImportCandidateState.newRule:
        return '新增';
      case TxtTocRuleImportCandidateState.update:
        return '更新';
      case TxtTocRuleImportCandidateState.existing:
        return '已有';
    }
  }

  Color _buildStateColor(
    BuildContext context,
    TxtTocRuleImportCandidateState state,
  ) {
    switch (state) {
      case TxtTocRuleImportCandidateState.newRule:
        return CupertinoColors.activeGreen.resolveFrom(context);
      case TxtTocRuleImportCandidateState.update:
        return CupertinoColors.activeBlue.resolveFrom(context);
      case TxtTocRuleImportCandidateState.existing:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }
}

class BlockingProgressContent extends StatelessWidget {
  const BlockingProgressContent({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

