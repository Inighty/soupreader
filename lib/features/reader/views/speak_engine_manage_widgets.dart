import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../services/http_tts_rule_store.dart';

/// 「更多」菜单的可选动作。
enum SpeakEngineMenuAction {
  importDefaultRules,
  importLocal,
  importOnline,
  export,
}

/// 单个待导入候选规则的行视图。
class ImportCandidateTile extends StatelessWidget {
  const ImportCandidateTile({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final HttpTtsImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final name = candidate.rule.name.trim();
    final url = candidate.rule.url.trim();
    final title = name.isEmpty ? (url.isEmpty ? '未命名引擎' : url) : name;
    final subtitle = url.isEmpty ? '未配置 URL' : url;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppCard(
        backgroundColor: selected
            ? CupertinoColors.systemGrey5.resolveFrom(context)
            : CupertinoColors.systemBackground.resolveFrom(context),
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
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
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

  static String _stateLabel(HttpTtsImportCandidateState state) {
    return switch (state) {
      HttpTtsImportCandidateState.newRule => '新增',
      HttpTtsImportCandidateState.update => '更新',
      HttpTtsImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    HttpTtsImportCandidateState state,
  ) {
    return switch (state) {
      HttpTtsImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      HttpTtsImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      HttpTtsImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}

/// 居中加载文案，用于「导入中…」之类的阻塞对话框。
class BlockingProgressContent extends StatelessWidget {
  const BlockingProgressContent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    );
  }
}
