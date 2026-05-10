import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/services/qr_scan_service.dart';
import '../services/dict_rule_store.dart';
import 'dict_rule_manage_dialogs.dart';

/// 「导入候选 → 选择 → 提交」共享流程。
Future<void> importDictRulesFromInput({
  required BuildContext context,
  required DictRuleStore ruleStore,
  required String rawInput,
}) async {
  final candidates = await ruleStore.previewImportCandidates(rawInput);
  if (candidates.isEmpty) {
    if (!context.mounted) return;
    await showDictRuleMessageDialog(
      context: context,
      title: '导入字典规则',
      message: '格式不对',
    );
    return;
  }
  if (!context.mounted) return;
  final selectedIndexes = await showDictRuleImportSelectionSheet(
    context: context,
    candidates: candidates,
  );
  if (selectedIndexes == null || selectedIndexes.isEmpty) return;
  if (!context.mounted) return;
  await runDictRuleImportingTask(
    context: context,
    task: () => ruleStore.importCandidates(
      candidates: candidates,
      selectedIndexes: selectedIndexes,
    ),
  );
}

/// 通过系统文件选择器读取本地 txt/json 内容。
Future<String?> pickDictRuleLocalImportText() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['txt', 'json'],
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  if (file.bytes != null) {
    return utf8.decode(file.bytes!, allowMalformed: true);
  }
  final path = file.path;
  if (path != null && path.trim().isNotEmpty) {
    return File(path).readAsString();
  }
  throw const FileSystemException('无法读取文件内容');
}

bool isDictRuleHttpUrl(String value) {
  final parsed = Uri.tryParse(value);
  if (parsed == null) return false;
  return parsed.scheme == 'http' || parsed.scheme == 'https';
}

/// 二维码导入：调起扫码 → 用扫到的文本走标准导入流程。
Future<void> importDictRulesFromQr({
  required BuildContext context,
  required DictRuleStore ruleStore,
}) async {
  final text = await QrScanService.scanText(context, title: '二维码导入');
  final normalizedInput = text?.trim();
  if (normalizedInput == null || normalizedInput.isEmpty) return;
  if (!context.mounted) return;
  await importDictRulesFromInput(
    context: context,
    ruleStore: ruleStore,
    rawInput: normalizedInput,
  );
}
