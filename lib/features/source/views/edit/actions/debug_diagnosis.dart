import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_actions.dart';

class SourceEditDebugDiagnosisSection extends StatelessWidget {
  const SourceEditDebugDiagnosisSection({
    super.key,
    required this.state,
    required this.debugActions,
  });

  final SourceEditState state;
  final SourceEditDebugActions debugActions;

  @override
  Widget build(BuildContext context) {
    final labels = debugActions.diagnosisLabels();
    final hints = debugActions.diagnosisHints();
    final hasLogs = state.debugLinesAll.isNotEmpty;

    return CupertinoListSection.insetGrouped(
      header: const Text('诊断标签'),
      children: [
        CupertinoListTile.notched(
          title: const Text('失败分类'),
          subtitle: hasLogs
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in labels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: debugActions.labelColor(label).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          debugActions.labelText(label),
                          style: TextStyle(
                            fontSize: 12,
                            color: debugActions.labelColor(label),
                          ),
                        ),
                      ),
                  ],
                )
              : const Text('暂无调试数据，请先执行“开始调试”'),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs
              ? () => debugActions.openDebugText(
                    title: '诊断标签（结构化）',
                    text: const JsonEncoder.withIndent('  ').convert(
                      debugActions.buildStructuredDebugSummary()['diagnosis'],
                    ),
                  )
              : null,
        ),
        CupertinoListTile.notched(
          title: const Text('定位建议'),
          subtitle: Text(hints.isEmpty ? '—' : hints.join('\n')),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs
              ? () => debugActions.openDebugText(
                    title: '定位建议',
                    text: hints.isEmpty ? '—' : hints.join('\n'),
                  )
              : null,
        ),
      ],
    );
  }
}
