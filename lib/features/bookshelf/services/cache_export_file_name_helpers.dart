/// 文件名/目录名/Hash 等纯函数。
library;

import 'dart:convert';

import '../../../core/services/exception_log_service.dart';
import '../../../core/services/js_runtime.dart';
import '../models/book.dart';

const String _exportFileNameEvalErrorPrefix =
    '__SOUP_EXPORT_FILE_NAME_EVAL_ERROR__';

/// 把不安全字符替换为下划线，并裁剪到 80 字符以内。
String safeExportFileName(String raw) {
  final trimmed = raw.trim();
  final sanitized = trimmed
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (sanitized.isEmpty) return '未命名书籍';
  if (sanitized.length <= 80) return sanitized;
  return sanitized.substring(0, 80);
}

/// 把不安全字符替换后再去掉结尾点号，作为目录名安全。
String safeExportFolderName(String raw) {
  final safe = safeExportFileName(raw);
  final normalized = safe.replaceAll(RegExp(r'\.+$'), '').trim();
  return normalized.isEmpty ? '未命名' : normalized;
}

String normalizeExportAuthor(String author) => author.trim();

/// 默认文件名：`书名 作者：xxx.suffix`。
String buildDefaultExportFileName(Book book, {required String suffix}) {
  final author = normalizeExportAuthor(book.author);
  final fileName = '${book.title} 作者：$author';
  return '${safeExportFileName(fileName)}.$suffix';
}

/// 优先按 [jsRule] 在 JsRuntime 里求值得到自定义文件名；失败回退默认名。
String buildExportFileName({
  required Book book,
  required String suffix,
  required String? jsRule,
  required JsRuntime jsRuntime,
}) {
  final defaultName = buildDefaultExportFileName(book, suffix: suffix);
  if (jsRule == null || jsRule.trim().isEmpty) return defaultName;
  final evalName = _evaluateExportFileNameRule(
    jsRule: jsRule,
    name: book.title,
    author: normalizeExportAuthor(book.author),
    jsRuntime: jsRuntime,
  );
  if (evalName == null || evalName.trim().isEmpty) return defaultName;
  return '${safeExportFileName(evalName)}.$suffix';
}

String? _evaluateExportFileNameRule({
  required String jsRule,
  required String name,
  required String author,
  required JsRuntime jsRuntime,
}) {
  final safeRule = jsonEncode(jsRule);
  final safeName = jsonEncode(name);
  final safeAuthor = jsonEncode(author);
  final script = '''
      (function() {
        try {
          var name = $safeName;
          var author = $safeAuthor;
          var epubIndex = "";
          var __res = eval($safeRule);
          if (__res === undefined || __res === null) return '';
          if (typeof __res === 'string') return __res;
          try { return JSON.stringify(__res); } catch(_jsonErr) { return String(__res); }
        } catch(e) {
          try {
            return "$_exportFileNameEvalErrorPrefix" + String(e && (e.stack || e.message || e));
          } catch(_e) {
            return "$_exportFileNameEvalErrorPrefix";
          }
        }
      })()
    ''';
  final output = decodeMaybeJsonString(jsRuntime.evaluate(script).trim());
  if (output.isEmpty) return null;
  if (output.startsWith(_exportFileNameEvalErrorPrefix)) {
    final error = output.substring(_exportFileNameEvalErrorPrefix.length);
    ExceptionLogService().record(
      node: 'bookshelf.cache.export_file_name.eval_failed',
      message: '导出文件名规则解析失败，已回退默认规则',
      error: error.isEmpty ? null : error,
      context: <String, dynamic>{
        'rule': jsRule,
        'bookName': name,
        'bookAuthor': author,
      },
    );
    return null;
  }
  return output;
}

String decodeMaybeJsonString(String text) {
  final trimmed = text.trim();
  if (trimmed.length >= 2 &&
      trimmed.startsWith('"') &&
      trimmed.endsWith('"')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String) return decoded.trim();
    } catch (_) {
      // noop
    }
  }
  return trimmed;
}

/// 在同一目录下，用 `file(N).ext` 格式确保不覆盖已有文件。
String stableExportHash16(String input) {
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xFFFFFFFFFFFFFFFF;
  for (final code in input.codeUnits) {
    hash ^= code;
    hash = (hash * prime) & mask;
  }
  final hex = hash.toRadixString(16).padLeft(16, '0');
  return hex.substring(0, 16);
}
