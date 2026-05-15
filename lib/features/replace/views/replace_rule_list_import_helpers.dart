import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/replace_rule.dart';
import '../services/replace_rule_import_export_service.dart';
import 'replace_rule_import_types.dart';

const int kMaxReplaceRuleImportDepth = 5;
const String kReplaceRuleRequestWithoutUaSuffix = '#requestWithoutUA';
final RegExp _groupSplitPattern = RegExp(r'[,;，；]');

bool isReplaceRuleHttpUrl(String value) {
  final parsed = Uri.tryParse(value);
  if (parsed == null) return false;
  final scheme = parsed.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

String sanitizeReplaceRuleImportInput(String input) {
  var value = input.trim();
  if (value.startsWith('﻿')) {
    value = value.replaceFirst(RegExp(r'^﻿+'), '');
  }
  return value.trim();
}

String formatReplaceRuleImportError(Object error) {
  if (error is FileSystemException) {
    final message = error.message.trim();
    if (message.isEmpty) return 'readTextError:ERROR';
    return 'readTextError:$message';
  }
  if (error is FormatException) {
    final message = error.message.trim();
    if (message.isEmpty) return 'ImportError:格式不对';
    return 'ImportError:$message';
  }
  final text = '$error'.trim();
  if (text.isEmpty) return 'ImportError:ERROR';
  if (text.startsWith('Exception:')) {
    final stripped = text.substring('Exception:'.length).trim();
    return stripped.isEmpty ? 'ImportError:ERROR' : 'ImportError:$stripped';
  }
  return 'ImportError:$text';
}

bool looksLikeReplaceRuleJson(String value) {
  return value.startsWith('{') || value.startsWith('[');
}

Future<String?> pickLocalReplaceRuleImportText() async {
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

Future<String> loadReplaceRuleTextFromUrl(String rawUrl) async {
  var requestUrl = rawUrl.trim();
  var requestWithoutUa = false;
  if (requestUrl.endsWith(kReplaceRuleRequestWithoutUaSuffix)) {
    requestWithoutUa = true;
    requestUrl = requestUrl.substring(
      0,
      requestUrl.length - kReplaceRuleRequestWithoutUaSuffix.length,
    );
  }
  final uri = Uri.parse(requestUrl);
  final httpClient = HttpClient();
  try {
    final request = await httpClient.getUrl(uri);
    if (requestWithoutUa) {
      request.headers.set(HttpHeaders.userAgentHeader, 'null');
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    final text = await response.transform(utf8.decoder).join();
    if (sanitizeReplaceRuleImportInput(text).isEmpty) {
      throw const FormatException('格式不对');
    }
    return text;
  } finally {
    httpClient.close(force: true);
  }
}

/// 递归解析输入文本到规则列表（支持 JSON / URL / 本地文件）。
Future<List<ReplaceRule>> parseReplaceRuleImportRulesFromInput({
  required ReplaceRuleImportExportService io,
  required String input,
  required int depth,
}) async {
  if (depth > kMaxReplaceRuleImportDepth) {
    throw const FormatException('导入链接重定向层级过深');
  }
  final text = sanitizeReplaceRuleImportInput(input);
  if (text.isEmpty) throw const FormatException('格式不对');
  if (looksLikeReplaceRuleJson(text)) {
    final parsed = io.importFromJson(text);
    if (parsed.success && parsed.rules.isNotEmpty) return parsed.rules;
    final detail = parsed.errorMessage?.trim();
    throw FormatException(
      detail == null || detail.isEmpty ? '格式不对' : detail,
    );
  }
  final parsedUri = Uri.tryParse(text);
  if (parsedUri != null) {
    final scheme = parsedUri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      final remoteText = await loadReplaceRuleTextFromUrl(text);
      return parseReplaceRuleImportRulesFromInput(
          io: io, input: remoteText, depth: depth + 1);
    }
    if (scheme == 'file') {
      final localText = await File.fromUri(parsedUri).readAsString();
      return parseReplaceRuleImportRulesFromInput(
          io: io, input: localText, depth: depth + 1);
    }
  }
  final localFile = File(text);
  if (await localFile.exists()) {
    final localText = await localFile.readAsString();
    return parseReplaceRuleImportRulesFromInput(
        io: io, input: localText, depth: depth + 1);
  }
  throw const FormatException('格式不对');
}

/// 把规则套上自定义分组策略（覆盖 / 追加）。
ReplaceRule applyReplaceRuleImportGroupPolicy({
  required ReplaceRule rule,
  required ReplaceRuleImportGroupPolicy policy,
}) {
  final groupName = policy.groupName.trim();
  if (groupName.isEmpty) return rule;
  if (!policy.appendGroup) return rule.copyWith(group: groupName);
  final groups = <String>{};
  final rawGroup = rule.group;
  if (rawGroup != null && rawGroup.isNotEmpty) {
    for (final part in rawGroup.split(_groupSplitPattern)) {
      final normalized = part.trim();
      if (normalized.isEmpty) continue;
      groups.add(normalized);
    }
  }
  groups.add(groupName);
  return rule.copyWith(group: groups.join(','));
}

ReplaceRuleImportCandidateState resolveReplaceRuleCandidateState({
  required ReplaceRule importedRule,
  required ReplaceRule? localRule,
}) {
  if (localRule == null) return ReplaceRuleImportCandidateState.newRule;
  if (importedRule.pattern != localRule.pattern ||
      importedRule.replacement != localRule.replacement ||
      importedRule.isRegex != localRule.isRegex ||
      importedRule.scope != localRule.scope) {
    return ReplaceRuleImportCandidateState.update;
  }
  return ReplaceRuleImportCandidateState.existing;
}

List<ReplaceRuleImportCandidate> buildReplaceRuleImportCandidates({
  required List<ReplaceRule> importedRules,
  required List<ReplaceRule> localRules,
}) {
  final localById = <int, ReplaceRule>{for (final rule in localRules) rule.id: rule};
  return importedRules.map((rule) {
    final localRule = localById[rule.id];
    return ReplaceRuleImportCandidate(
      rule: rule,
      localRule: localRule,
      state: resolveReplaceRuleCandidateState(
        importedRule: rule,
        localRule: localRule,
      ),
    );
  }).toList(growable: false);
}
