// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_blocking_progress.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/qr_scan_service.dart';
import '../models/replace_rule.dart';
import 'replace_rule_import_types.dart';
import 'replace_rule_list_import_dialog.dart';
import 'replace_rule_list_import_helpers.dart';
import 'replace_rule_list_message_dialogs.dart';
import 'replace_rule_list_online_import.dart';
import 'replace_rule_list_view.dart';

/// 导入流程扩展（文件 / URL / 二维码 / 共用 importRulesFromInput 与
/// 阻塞进度框 runImportingTask）。
extension ReplaceRuleListImportFlow on ReplaceRuleListViewState {
  Future<void> importFromFile() async {
    if (importingLocal) return;
    setState(() => importingLocal = true);
    try {
      final localText = await pickLocalReplaceRuleImportText();
      if (localText == null) {
        return;
      }
      await importRulesFromInput(localText);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.import_local',
        message: '本地导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await showMessageDialog(
        title: '导入替换规则',
        message: formatReplaceRuleImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => importingLocal = false);
      }
    }
  }

  Future<void> importFromUrl() async {
    if (importingOnline) return;
    setState(() => importingOnline = true);
    try {
      final rawInput = await showOnlineImportInputSheet();
      final normalizedInput = sanitizeReplaceRuleImportInput(rawInput ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      if (isReplaceRuleHttpUrl(normalizedInput)) {
        await pushOnlineImportHistory(normalizedInput);
      }
      await importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.import_online',
        message: '网络导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await showMessageDialog(
        title: '导入替换规则',
        message: formatReplaceRuleImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => importingOnline = false);
      }
    }
  }

  Future<void> importFromQr() async {
    if (importingQr) return;
    setState(() => importingQr = true);
    try {
      final text = await QrScanService.scanText(
        context,
        title: '二维码导入',
      );
      final normalizedInput = sanitizeReplaceRuleImportInput(text ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      await importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      recordViewError(
        node: 'replace_rule.import_qr',
        message: '二维码导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await showMessageDialog(
        title: '导入替换规则',
        message: formatReplaceRuleImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => importingQr = false);
      }
    }
  }

  Future<void> importRulesFromInput(String rawInput) async {
    final importedRules = await parseReplaceRuleImportRulesFromInput(
        io: io, input: rawInput, depth: 0);
    final candidates = buildReplaceRuleImportCandidates(
      importedRules: importedRules,
      localRules: repo.getAllRules(),
    );
    if (candidates.isEmpty) {
      await showMessageDialog(
        title: '导入替换规则',
        message: 'ImportError:格式不对',
      );
      return;
    }
    if (!mounted) return;
    final selectionDecision = await showImportSelectionSheet(candidates);
    if (selectionDecision == null ||
        selectionDecision.selectedIndexes.isEmpty) {
      return;
    }
    if (!mounted) return;
    await runImportingTask(() async {
      final selectedRules = <ReplaceRule>[];
      final sortedIndexes = selectionDecision.selectedIndexes.toList()..sort();
      for (final index in sortedIndexes) {
        if (index < 0 || index >= candidates.length) continue;
        selectedRules.add(
          applyReplaceRuleImportGroupPolicy(
            rule: candidates[index].rule,
            policy: selectionDecision.groupPolicy,
          ),
        );
      }
      await repo.addRules(selectedRules);
    });
  }

  Future<String?> showOnlineImportInputSheet() {
    return showReplaceRuleOnlineImportSheet(
      context: context,
      loadHistory: loadOnlineImportHistory,
      saveHistory: saveOnlineImportHistory,
    );
  }

  Future<List<String>> loadOnlineImportHistory() async {
    return onlineImportHistoryStore.load(ReplaceRuleListViewState.onlineImportHistoryKey);
  }

  Future<void> saveOnlineImportHistory(List<String> history) async {
    await onlineImportHistoryStore.save(ReplaceRuleListViewState.onlineImportHistoryKey, history);
  }

  Future<void> pushOnlineImportHistory(String url) async {
    await onlineImportHistoryStore.push(ReplaceRuleListViewState.onlineImportHistoryKey, url);
  }

  Future<void> showExportPathDialog(String outputPath) =>
      showReplaceRuleExportPathDialog(
          context: context, outputPath: outputPath);

  Future<void> openReplaceRuleHelp() => showReplaceRuleHelp(context);

  Future<ReplaceRuleImportSelectionDecision?> showImportSelectionSheet(
    List<ReplaceRuleImportCandidate> candidates,
  ) =>
      showReplaceRuleImportSelectionSheet(
        context: context,
        candidates: candidates,
      );


  Future<void> runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CupertinoAlertDialog(
        content: AppBlockingProgress(text: '导入中...'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    try {
      await task();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}
