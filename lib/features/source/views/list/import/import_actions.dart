import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:soupreader/app/widgets/app_card.dart';
import 'package:soupreader/app/widgets/app_empty_state.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/core/services/online_import_history_store.dart';
import 'package:soupreader/core/services/qr_scan_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_import/commit_service.dart';
import 'package:soupreader/features/source/services/source_import/export_service.dart';
import 'package:soupreader/features/source/services/source_import/selection_helper.dart';
import 'package:soupreader/features/source/views/list/widgets/dialogs.dart';
import 'package:soupreader/features/source/views/list/import/import_dialogs.dart';

class SourceListImportActions {
  const SourceListImportActions({
    required this.context,
    required this.sourceRepo,
    required this.importCommitService,
    required this.importExportService,
    required this.importHistoryStore,
    required this.importDialogs,
    required this.importHistoryPrefKey,
    required this.urlController,
  });

  final BuildContext context;
  final SourceRepository sourceRepo;
  final SourceImportCommitService importCommitService;
  final SourceImportExportService importExportService;
  final OnlineImportHistoryStore importHistoryStore;
  final SourceListImportDialogs importDialogs;
  final String importHistoryPrefKey;
  final TextEditingController urlController;

  Future<void> importFromFile() async {
    final result = await importExportService.importFromFile();
    await commitImportResult(result);
  }

  Future<void> importFromQrCode() async {
    final text = await QrScanService.scanText(context, title: '二维码导入');
    final value = text?.trim();
    if (value == null || value.isEmpty) return;
    final result = await importExportService.importFromText(value);
    await commitImportResult(result);
  }

  Future<void> importFromUrl() async {
    urlController.clear();
    final history = await loadOnlineImportHistory();
    final url = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: SizedBox(
          height: 560,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '网络导入',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: urlController,
                            placeholder: '输入书源网址',
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          onPressed: () {
                            Navigator.pop(context, urlController.text);
                          },
                          child: const Text('导入'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            '历史记录',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: history.isEmpty
                        ? const AppEmptyState(
                            illustration: AppEmptyPlanetIllustration(size: 76),
                            title: '暂无历史记录',
                            message: '输入 URL 并导入后会自动保存',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: history.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = history[index];
                              return AppCard(
                                backgroundColor:
                                    CupertinoColors.systemGrey6.resolveFrom(context),
                                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          urlController.text = item;
                                        },
                                        child: Text(
                                          item,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(28, 28),
                                      onPressed: () async {
                                        history.removeAt(index);
                                        await saveOnlineImportHistory(history);
                                        if (context.mounted) {
                                          setDialogState(() {});
                                        }
                                      },
                                      child: Icon(
                                        CupertinoIcons.delete,
                                        size: 18,
                                        color: CupertinoColors.systemRed.resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final normalizedUrl = url?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;

    final isHttpUrl =
        normalizedUrl.startsWith('http://') || normalizedUrl.startsWith('https://');
    if (isHttpUrl) {
      await pushImportHistory(normalizedUrl);
    }

    final result = isHttpUrl
        ? await importExportService.importFromUrl(normalizedUrl)
        : await importExportService.importFromText(normalizedUrl);
    await commitImportResult(result);
  }

  Future<void> commitImportResult(SourceImportResult result) async {
    try {
      if (!result.success) {
        if (!result.cancelled) {
          showImportError(result);
        }
        return;
      }
      final candidates = SourceImportSelectionHelper.buildCandidates(
        result: result,
        localMap: localSourceMap(),
      );
      if (candidates.isEmpty) {
        await SourceListDialogs.showMessage(context, '没有可导入的书源');
        return;
      }

      final decision = await importDialogs.showImportSelectionDialog(candidates);
      if (decision == null) return;
      final plan = SourceImportSelectionHelper.buildCommitPlan(
        candidates: decision.candidates,
        policy: decision.policy,
      );
      if (plan.imported <= 0) {
        await SourceListDialogs.showMessage(context, '未选择可导入书源');
        return;
      }

      final commitResult = await importCommitService.commit(plan.items);
      if (commitResult.imported <= 0) {
        final blockedCount = commitResult.blockedCount;
        if (blockedCount > 0) {
          final blockedPreview = commitResult.blockedNames.take(3).join('、');
          final extra = blockedCount > 3 ? ' 等$blockedCount条' : '';
          await SourceListDialogs.showMessage(context, '未导入书源\n已拦截：$blockedPreview$extra');
          return;
        }
        await SourceListDialogs.showMessage(context, '未选择可导入书源');
        return;
      }

      showImportSummary(
        result,
        imported: commitResult.imported,
        newCount: commitResult.newCount,
        updateCount: commitResult.updateCount,
        existingCount: commitResult.existingCount,
        blockedNames: commitResult.blockedNames,
      );
    } catch (error, stackTrace) {
      debugPrint('[source-import] 导入流程异常: $error');
      ExceptionLogService().record(
        node: 'source.import.commit',
        message: '导入流程异常',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrintStack(stackTrace: stackTrace);
      await SourceListDialogs.showMessage(context, '导入流程异常：$error');
    }
  }

  Map<String, BookSource> localSourceMap() {
    final all = sourceRepo.getAllSources();
    return {for (final source in all) source.bookSourceUrl: source};
  }

  void showImportError(SourceImportResult result) {
    final lines = <String>[result.errorMessage ?? '导入失败'];
    if (result.totalInputCount > 0) {
      lines.add('输入条数：${result.totalInputCount}');
      if (result.invalidCount > 0) lines.add('无效条数：${result.invalidCount}');
      if (result.duplicateCount > 0) {
        lines.add('重复URL：${result.duplicateCount}（后项覆盖）');
      }
    }
    if (kIsWeb && (result.errorMessage ?? '').contains('跨域限制')) {
      lines.add('建议：改用“剪贴板导入”或“本地导入”');
    }
    if (result.warnings.isNotEmpty) {
      lines.add('详情：');
      lines.addAll(result.warnings.take(5));
      final more = result.warnings.length - 5;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    unawaited(SourceListDialogs.showMessage(context, lines.join('\n')));
  }

  void showImportSummary(
    SourceImportResult result, {
    required int imported,
    required int newCount,
    required int updateCount,
    required int existingCount,
    List<String> blockedNames = const <String>[],
  }) {
    final lines = <String>[
      '成功导入 $imported 条书源',
      '新增：$newCount',
      '更新：$updateCount',
      '已有覆盖：$existingCount',
    ];
    if (blockedNames.isNotEmpty) {
      lines.add('已拦截：${blockedNames.length}');
      lines.add('拦截项：${blockedNames.take(3).join('、')}');
      final more = blockedNames.length - 3;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    if (result.totalInputCount > 0) {
      lines.add('输入条数：${result.totalInputCount}');
      if (result.invalidCount > 0) lines.add('跳过无效：${result.invalidCount}');
      if (result.duplicateCount > 0) {
        lines.add('导入内容内重复URL：${result.duplicateCount}（后项覆盖）');
      }
    }
    if (result.warnings.isNotEmpty) {
      lines.add('说明：');
      lines.addAll(result.warnings.take(5));
      final more = result.warnings.length - 5;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    unawaited(SourceListDialogs.showMessage(context, lines.join('\n')));
  }

  Future<List<String>> loadOnlineImportHistory() =>
      importHistoryStore.load(importHistoryPrefKey);

  Future<void> saveOnlineImportHistory(List<String> history) =>
      importHistoryStore.save(importHistoryPrefKey, history);

  Future<void> pushImportHistory(String url) =>
      importHistoryStore.push(importHistoryPrefKey, url);
}
