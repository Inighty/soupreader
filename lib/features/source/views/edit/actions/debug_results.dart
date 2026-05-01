import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_actions.dart';

class SourceEditDebugResultsSection extends StatelessWidget {
  const SourceEditDebugResultsSection({
    super.key,
    required this.state,
    required this.actions,
    required this.debugActions,
  });

  final SourceEditState state;
  final SourceEditViewActions actions;
  final SourceEditDebugActions debugActions;

  @override
  Widget build(BuildContext context) {
    final summaryText = debugActions.structuredSummaryText();
    return CupertinoListSection.insetGrouped(
      header: const Text('源码 & 结果'),
      children: [
        CupertinoListTile.notched(
          title: const Text('结构化调试摘要'),
          subtitle: const Text('请求/解析/错误摘要，便于快速定位失败阶段'),
          additionalInfo: Text(summaryText == null ? '—' : '可查看'),
          trailing: const CupertinoListTileChevron(),
          onTap: summaryText == null
              ? null
              : () => actions.openDebugText(
                    title: '结构化调试摘要',
                    text: summaryText,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('列表页源码'),
          additionalInfo: Text(
            (state.debugListSrcHtml ?? '').isEmpty
                ? '—'
                : '${state.debugListSrcHtml!.length} 字符',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: (state.debugListSrcHtml ?? '').isEmpty
              ? null
              : () => actions.openDebugText(
                    title: '列表页源码',
                    text: state.debugListSrcHtml!,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('详情页源码'),
          additionalInfo: Text(
            (state.debugBookSrcHtml ?? '').isEmpty
                ? '—'
                : '${state.debugBookSrcHtml!.length} 字符',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: (state.debugBookSrcHtml ?? '').isEmpty
              ? null
              : () => actions.openDebugText(
                    title: '详情页源码',
                    text: state.debugBookSrcHtml!,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('目录页源码'),
          additionalInfo: Text(
            (state.debugTocSrcHtml ?? '').isEmpty
                ? '—'
                : '${state.debugTocSrcHtml!.length} 字符',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: (state.debugTocSrcHtml ?? '').isEmpty
              ? null
              : () => actions.openDebugText(
                    title: '目录页源码',
                    text: state.debugTocSrcHtml!,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('正文页源码'),
          additionalInfo: Text(
            (state.debugContentSrcHtml ?? '').isEmpty
                ? '—'
                : '${state.debugContentSrcHtml!.length} 字符',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: (state.debugContentSrcHtml ?? '').isEmpty
              ? null
              : () => actions.openDebugText(
                    title: '正文页源码',
                    text: state.debugContentSrcHtml!,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('正文结果（清理后）'),
          additionalInfo: Text(
            (state.debugContentResult ?? '').isEmpty
                ? '—'
                : '${state.debugContentResult!.length} 字符',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: (state.debugContentResult ?? '').isEmpty
              ? null
              : () => actions.openDebugText(
                    title: '正文结果',
                    text: state.debugContentResult!,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('运行时变量快照'),
          additionalInfo: Text('${state.debugRuntimeVarsSnapshot.length} 项'),
          trailing: const CupertinoListTileChevron(),
          onTap: state.debugRuntimeVarsSnapshot.isEmpty
              ? null
              : () => actions.openDebugText(
                    title: '运行时变量快照',
                    text: const JsonEncoder.withIndent('  ').convert(
                      state.debugRuntimeVarsSnapshot,
                    ),
                  ),
        ),
      ],
    );
  }
}
