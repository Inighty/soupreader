import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/app/theme/design_tokens.dart';
import 'package:soupreader/app/theme/typography.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_actions.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_diagnosis.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_quick_actions.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_results.dart';

class SourceEditDebugTab extends ConsumerStatefulWidget {
  const SourceEditDebugTab({
    super.key,
    required this.args,
    required this.actions,
    required this.debugActions,
  });

  final SourceEditArgs args;
  final SourceEditViewActions actions;
  final SourceEditDebugActions debugActions;

  @override
  ConsumerState<SourceEditDebugTab> createState() => _SourceEditDebugTabState();
}

class _SourceEditDebugTabState extends ConsumerState<SourceEditDebugTab> {
  late final TextEditingController _debugKeyController;

  @override
  void initState() {
    super.initState();
    _debugKeyController = TextEditingController(
      text: ref.read(sourceEditProvider(widget.args)).debugKey,
    );
  }

  @override
  void dispose() {
    _debugKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sourceEditProvider(widget.args));
    final notifier = ref.read(sourceEditProvider(widget.args).notifier);
    if (_debugKeyController.text != state.debugKey) {
      _debugKeyController.value = _debugKeyController.value.copyWith(
        text: state.debugKey,
      );
    }

    final statusColor = state.debugLoading
        ? CupertinoColors.systemBlue.resolveFrom(context)
        : (state.debugError ?? '').trim().isNotEmpty
            ? CupertinoColors.systemRed.resolveFrom(context)
            : state.debugLinesAll.isNotEmpty
                ? CupertinoColors.systemGreen.resolveFrom(context)
                : CupertinoColors.secondaryLabel.resolveFrom(context);
    final statusText = state.debugLoading
        ? '运行中'
        : (state.debugError ?? '').trim().isNotEmpty
            ? '失败'
            : state.debugLinesAll.isNotEmpty
                ? '已完成'
                : '未开始';

    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('调试状态'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '意图：${state.debugIntentType?.name ?? '未识别'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '日志 ${state.debugLinesAll.length} 行',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if ((state.debugError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.debugError!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemRed.resolveFrom(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('快速输入'),
          footer: const Text('关键字/URL/前缀调试；完整语法见“工具 -> 菜单 -> 调试帮助”。'),
          children: [
            CupertinoListTile.notched(
              title: const Text('Key'),
              subtitle: CupertinoTextField(
                controller: _debugKeyController,
                placeholder: '输入关键字或调试 key',
                textInputAction: TextInputAction.search,
                onChanged: notifier.updateDebugKey,
                onSubmitted: (_) => widget.debugActions.startDebug(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onPressed: state.debugLoading
                          ? null
                          : () => widget.debugActions.startDebug(),
                      child: Text(state.debugLoading ? '调试运行中…' : '开始调试'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '输入后按对应链路执行（搜索/详情/发现/目录/正文）。',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (state.showDebugQuickHelp)
          SourceEditDebugQuickActionsSection(
            state: state,
            debugActions: widget.debugActions,
          ),
        CupertinoListSection.insetGrouped(
          header: const Text('工具'),
          children: [
            CupertinoListTile.notched(
              title: Text(state.showDebugQuickHelp ? '收起快捷动作' : '显示快捷动作'),
              subtitle: Text(
                state.showDebugQuickHelp
                    ? '减少首屏占用，保留核心输入与结果'
                    : '重新展开“我的/系统/发现候选/++/--”快捷区',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: () => notifier.setShowDebugQuickHelp(!state.showDebugQuickHelp),
            ),
            CupertinoListTile.notched(
              title: const Text('菜单'),
              subtitle: const Text('扫码/查看源码/刷新发现/调试帮助'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => widget.debugActions.showLegacyMenuSheet(),
            ),
            CupertinoListTile.notched(
              title: const Text('高级工具'),
              subtitle: const Text('网页验证/调试摘要/变量快照/控制台'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => widget.debugActions.showMoreToolsSheet(),
            ),
          ],
        ),
        SourceEditDebugDiagnosisSection(
          state: state,
          debugActions: widget.debugActions,
        ),
        SourceEditDebugResultsSection(
          state: state,
          actions: widget.actions,
          debugActions: widget.debugActions,
        ),
        CupertinoListSection.insetGrouped(
          header: Text('控制台（共 ${state.debugLinesAll.length} 行）'),
          children: [
            CupertinoListTile.notched(
              title: const Text('复制控制台'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => widget.debugActions.copyDebugConsole(),
            ),
            CupertinoListTile.notched(
              title: const Text('复制最小复现信息'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => widget.debugActions.copyMinimalReproInfo(),
            ),
            CupertinoListTile.notched(
              title: const Text('清空日志'),
              trailing: const CupertinoListTileChevron(),
              onTap: notifier.clearDebugConsole,
            ),
            for (final line in state.debugLines)
              if (line.text.trim().isNotEmpty)
                CupertinoListTile.notched(
                  title: Text(
                    line.text,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamilyMonospace,
                      fontSize: 12.5,
                      color: line.state == -1
                          ? CupertinoColors.systemRed.resolveFrom(context)
                          : line.state == 1000
                              ? CupertinoColors.systemGreen.resolveFrom(context)
                              : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
