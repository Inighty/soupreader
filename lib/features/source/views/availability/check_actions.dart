import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/services/source_availability/check_task_service.dart';
import 'package:soupreader/features/source/services/source_debug/export_service.dart';
import 'package:soupreader/features/source/views/availability/check_support.dart';
import 'package:soupreader/features/source/views/shared/debug_text_view.dart';
import 'package:soupreader/features/source/views/edit/source_edit_view.dart';

class SourceAvailabilityCheckActions {
  const SourceAvailabilityCheckActions({
    required this.context,
    required this.repo,
    required this.taskService,
    required this.exportService,
    required this.items,
    required this.activeConfig,
    required this.resultFilter,
    required this.running,
    required this.onItemsChanged,
  });

  final BuildContext context;
  final SourceRepository repo;
  final SourceAvailabilityCheckTaskService taskService;
  final SourceDebugExportService exportService;
  final List<SourceCheckItem> items;
  final SourceCheckTaskConfig activeConfig;
  final SourceAvailabilityResultFilter resultFilter;
  final bool running;
  final VoidCallback onItemsChanged;

  Future<void> ensureTaskStarted({bool forceRestart = false}) async {
    final result = await taskService.start(
      activeConfig,
      forceRestart: forceRestart,
    );
    if (!context.mounted) return;
    if (result.type == SourceCheckStartType.runningOtherTask ||
        result.type == SourceCheckStartType.emptySource) {
      await _showMessage(result.message);
    }
  }

  Future<void> copyReport() async {
    final text = SourceAvailabilityCheckSupport.buildReportText(
      items: items,
      activeConfig: activeConfig,
      resultFilter: resultFilter,
      onlyVisible: true,
    );
    await Clipboard.setData(ClipboardData(text: text));
    await _showMessage('已复制检测报告');
  }

  Future<void> exportReportToFile() async {
    final text = SourceAvailabilityCheckSupport.buildReportText(
      items: items,
      activeConfig: activeConfig,
      resultFilter: resultFilter,
      onlyVisible: true,
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'source_availability_report_$timestamp.txt';
    final ok = await exportService.exportTextToFile(
      text: text,
      fileName: fileName,
      dialogTitle: '导出检测报告',
    );
    if (!context.mounted) return;
    await _showMessage(ok ? '已导出：$fileName' : '导出取消或失败');
  }

  Future<void> disableUnavailableSources() async {
    if (running) {
      await _showMessage('检测进行中，请先停止检测再执行此操作。');
      return;
    }

    final targets = items
        .where(
          (item) =>
              item.source.enabled &&
              (item.status == SourceCheckStatus.fail ||
                  item.status == SourceCheckStatus.empty),
        )
        .toList(growable: false);
    if (targets.isEmpty) {
      await _showMessage('没有可禁用的失效书源（仅处理失败/空列表且当前启用）。');
      return;
    }

    final confirmed = await showCupertinoBottomSheetDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('一键禁用失效源'),
            content: Text(
              '\n将禁用 ${targets.length} 条书源（失败/空列表）。此操作可在书源列表手动恢复。',
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认禁用'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    for (final item in targets) {
      final updated = item.source.copyWith(enabled: false);
      await repo.updateSource(updated);
      item.source = updated;
      item.message = '${item.message ?? '已检测'}；已自动禁用';
    }
    taskService.touch();
    onItemsChanged();
    await _showMessage('已禁用 ${targets.length} 条失效书源。', title: '完成');
  }

  Future<void> openItemDetails(SourceCheckItem item) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(
          title: '检测详情',
          text: SourceAvailabilityCheckSupport.buildItemDetails(item),
        ),
      ),
    );
  }

  Future<void> openEditorAtDebug(SourceCheckItem item) async {
    final source = repo.getSourceByUrl(item.source.bookSourceUrl);
    if (source == null) {
      await _showMessage('书源不存在或已被删除');
      return;
    }
    final raw = repo.getRawJsonByUrl(source.bookSourceUrl);
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditView.fromSource(
          source,
          rawJson: raw,
          initialTab: 3,
          initialDebugKey: item.debugKey,
        ),
      ),
    );
  }

  Future<void> _showMessage(
    String message, {
    String title = '提示',
  }) async {
    if (!context.mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }
}
