import 'dart:convert';

import '../../core/database/database_service.dart';
import '../../core/services/exception_log_service.dart';
import '../../core/services/js_runtime.dart';

class ImportFileNameParseResult {
  final bool hasName;
  final String name;
  final bool hasAuthor;
  final String author;

  const ImportFileNameParseResult({
    this.hasName = false,
    this.name = '',
    this.hasAuthor = false,
    this.author = '',
  });

  bool get hasAnyField => hasName || hasAuthor;
}

/// 本地导入文件名规则（对齐 legado `bookImportFileName`）。
class BookImportFileNameRuleService {
  static const String settingKey = 'bookImportFileName';
  static const String _evalErrorPrefix = '__SOUP_IMPORT_FILE_NAME_EVAL_ERROR__';

  final DatabaseService _database;
  final JsRuntime _jsRuntime;

  BookImportFileNameRuleService({
    DatabaseService? database,
    JsRuntime? jsRuntime,
  })  : _database = database ?? DatabaseService(),
        _jsRuntime = jsRuntime ?? createJsRuntime();

  String getRule() {
    final raw = _database.getSetting(settingKey, defaultValue: null);
    final text = raw?.toString() ?? '';
    return text;
  }

  Future<void> saveRule(String? rule) async {
    await _database.putSetting(settingKey, (rule ?? '').toString());
  }

  ImportFileNameParseResult evaluateByFileName(String rawFileName) {
    final fileName = _stripExtension(rawFileName);
    if (fileName.isEmpty) return const ImportFileNameParseResult();

    final jsRule = getRule().trim();
    if (jsRule.isEmpty) return const ImportFileNameParseResult();

    final script = '''
      (function() {
        try {
          var src = ${jsonEncode(fileName)};
          $jsRule
          return JSON.stringify({author:author,name:name});
        } catch(e) {
          try {
            return "$_evalErrorPrefix" + String(e && (e.stack || e.message || e));
          } catch(_e) {
            return "$_evalErrorPrefix";
          }
        }
      })()
    ''';

    final output = _decodeMaybeJsonString(_jsRuntime.evaluate(script).trim());
    if (output.isEmpty) {
      return const ImportFileNameParseResult();
    }
    if (output.startsWith(_evalErrorPrefix)) {
      final detail = output.substring(_evalErrorPrefix.length).trim();
      ExceptionLogService().record(
        node: 'bookshelf.import.file_name_rule.eval_failed',
        message: '导入文件名规则解析失败，已回退默认文件名',
        error: detail.isEmpty ? null : detail,
        context: <String, dynamic>{
          'fileName': fileName,
          'rule': jsRule,
        },
      );
      return const ImportFileNameParseResult();
    }

    try {
      final decoded = jsonDecode(output);
      if (decoded is! Map) return const ImportFileNameParseResult();
      final map = decoded.map((key, value) => MapEntry('$key', value));
      final hasName = map.containsKey('name');
      final hasAuthor = map.containsKey('author');
      final name = _normalizeField(map['name']);
      var author = _normalizeField(map['author']);
      if (author.length == fileName.length) {
        author = '';
      }
      return ImportFileNameParseResult(
        hasName: hasName,
        name: name,
        hasAuthor: hasAuthor,
        author: author,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.file_name_rule.decode_failed',
        message: '导入文件名规则结果解析失败，已回退默认文件名',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'fileName': fileName,
          'rule': jsRule,
          'rawOutput': output,
        },
      );
      return const ImportFileNameParseResult();
    }
  }

  String _decodeMaybeJsonString(String text) {
    final trimmed = text.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded.trim();
        }
      } catch (_) {
        // noop
      }
    }
    return trimmed;
  }

  String _stripExtension(String fileName) {
    final normalized = fileName.trim();
    if (normalized.isEmpty) return '';
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0) return normalized;
    return normalized.substring(0, dotIndex).trim();
  }

  String _normalizeField(Object? raw) {
    if (raw == null) return '';
    return raw.toString().trim();
  }
}
