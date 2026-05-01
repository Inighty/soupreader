import 'dart:convert';

import 'package:soupreader/core/utils/legado_json.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_import/export_models.dart';

typedef SourceImportUrlLoader = Future<SourceImportResult> Function(
  String url, {
  required int depth,
});

class SourceImportExportParser {
  const SourceImportExportParser({
    required SourceImportUrlLoader importFromUrl,
    required int maxImportDepth,
  })  : _importFromUrl = importFromUrl,
        _maxImportDepth = maxImportDepth;

  final SourceImportUrlLoader _importFromUrl;
  final int _maxImportDepth;

  Future<SourceImportResult> importFromText(
    String text, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      return const SourceImportResult(
        success: false,
        errorMessage: '导入层级过深，请检查输入内容是否循环引用',
      );
    }

    final raw = _sanitizeJsonInput(text);
    if (raw.isEmpty) {
      return const SourceImportResult(
        success: false,
        errorMessage: '内容为空',
      );
    }

    if (_isHttpUrl(raw)) {
      return _importFromUrl(raw, depth: depth + 1);
    }

    dynamic decoded;
    try {
      decoded = json.decode(raw);
      decoded = _decodeNestedJsonValue(decoded);
    } catch (_) {
      return const SourceImportResult(
        success: false,
        errorMessage: '格式错误：需为书源 JSON、sourceUrls JSON 或 http/https 链接',
      );
    }

    final sourceUrls = _extractSourceUrls(decoded);
    if (sourceUrls != null) {
      if (sourceUrls.isEmpty) {
        return const SourceImportResult(
          success: false,
          errorMessage: 'sourceUrls 为空',
        );
      }
      return _importFromSourceUrls(sourceUrls, depth: depth + 1);
    }

    return importFromJson(raw);
  }

  SourceImportResult importFromJson(String jsonString) {
    try {
      final raw = _sanitizeJsonInput(jsonString);
      if (raw.isEmpty) {
        return const SourceImportResult(
          success: false,
          errorMessage: '内容为空',
        );
      }

      dynamic data = json.decode(raw);
      data = _decodeNestedJsonValue(data);

      final items = <dynamic>[];
      if (data is List) {
        items.addAll(data);
      } else if (data is Map) {
        items.add(data);
      } else {
        return const SourceImportResult(
          success: false,
          errorMessage: 'JSON格式不支持（需对象或数组）',
        );
      }

      final warnings = <String>[];
      var invalidCount = 0;
      var duplicateCount = 0;
      final sourceByUrl = <String, BookSource>{};
      final sourceRawJsonByUrl = <String, String>{};

      for (var i = 0; i < items.length; i++) {
        final map = _toSourceMap(items[i]);
        if (map == null) {
          invalidCount++;
          warnings.add('第${i + 1}条不是有效书源对象，已跳过');
          continue;
        }

        try {
          final source = BookSource.fromJson(map);
          final url = source.bookSourceUrl.trim();
          final name = source.bookSourceName.trim();

          if (url.isEmpty || name.isEmpty) {
            invalidCount++;
            warnings.add('第${i + 1}条缺少 bookSourceUrl/bookSourceName，已跳过');
            continue;
          }

          if (sourceByUrl.containsKey(url)) {
            duplicateCount++;
            sourceByUrl.remove(url);
            warnings.add('发现重复书源URL：$url（已使用后出现项覆盖）');
          }
          sourceByUrl[url] = source;
          sourceRawJsonByUrl[url] = LegadoJson.encode(map);
        } catch (error) {
          invalidCount++;
          warnings.add('第${i + 1}条解析失败：$error');
        }
      }

      final sources = sourceByUrl.values.toList(growable: false);
      if (sources.isEmpty) {
        final error =
            warnings.isNotEmpty ? '未识别到有效书源（共${items.length}条）' : '未识别到有效书源';
        return SourceImportResult(
          success: false,
          errorMessage: error,
          totalInputCount: items.length,
          invalidCount: invalidCount,
          duplicateCount: duplicateCount,
          warnings: warnings,
          sourceRawJsonByUrl: sourceRawJsonByUrl,
        );
      }

      return SourceImportResult(
        success: true,
        sources: sources,
        importCount: sources.length,
        totalInputCount: items.length,
        invalidCount: invalidCount,
        duplicateCount: duplicateCount,
        warnings: warnings,
        sourceRawJsonByUrl: sourceRawJsonByUrl,
      );
    } catch (error) {
      return SourceImportResult(
        success: false,
        errorMessage: 'JSON解析失败: $error',
      );
    }
  }

  Future<SourceImportResult> _importFromSourceUrls(
    List<String> sourceUrls, {
    required int depth,
  }) async {
    final warnings = <String>[];
    var invalidCount = 0;
    var duplicateCount = 0;
    final sourceByUrl = <String, BookSource>{};
    final sourceRawJsonByUrl = <String, String>{};

    for (var i = 0; i < sourceUrls.length; i++) {
      final targetUrl = sourceUrls[i].trim();
      if (targetUrl.isEmpty) {
        invalidCount++;
        warnings.add('sourceUrls 第${i + 1}项为空，已跳过');
        continue;
      }
      if (!_isHttpUrl(targetUrl)) {
        invalidCount++;
        warnings.add('sourceUrls 第${i + 1}项不是有效 http/https 链接：$targetUrl');
        continue;
      }

      final result = await _importFromUrl(targetUrl, depth: depth + 1);
      if (!result.success) {
        invalidCount++;
        final reason = result.errorMessage?.trim();
        warnings.add(
          'sourceUrls 第${i + 1}项导入失败：$targetUrl${(reason == null || reason.isEmpty) ? '' : '（$reason）'}',
        );
        continue;
      }

      warnings.addAll(result.warnings.map((warning) => '[$targetUrl] $warning'));

      for (final source in result.sources) {
        final url = source.bookSourceUrl.trim();
        if (url.isEmpty) continue;
        if (sourceByUrl.containsKey(url)) {
          duplicateCount++;
          sourceByUrl.remove(url);
        }
        sourceByUrl[url] = source;
        sourceRawJsonByUrl[url] =
            result.rawJsonForSourceUrl(url) ?? LegadoJson.encode(source.toJson());
      }
    }

    final sources = sourceByUrl.values.toList(growable: false);
    if (sources.isEmpty) {
      return SourceImportResult(
        success: false,
        errorMessage: '未识别到有效书源（sourceUrls）',
        totalInputCount: sourceUrls.length,
        invalidCount: invalidCount,
        duplicateCount: duplicateCount,
        warnings: warnings,
      );
    }

    return SourceImportResult(
      success: true,
      sources: sources,
      importCount: sources.length,
      totalInputCount: sourceUrls.length,
      invalidCount: invalidCount,
      duplicateCount: duplicateCount,
      warnings: warnings,
      sourceRawJsonByUrl: sourceRawJsonByUrl,
    );
  }

  List<String>? _extractSourceUrls(dynamic decoded) {
    if (decoded is! Map) return null;
    if (!decoded.containsKey('sourceUrls')) return null;

    final urls = <String>[];

    void addUrl(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return;
      urls.add(text);
    }

    final raw = _decodeNestedJsonValue(decoded['sourceUrls']);
    if (raw is List) {
      for (final item in raw) {
        addUrl(item);
      }
    } else if (raw is String) {
      final normalized = _sanitizeJsonInput(raw);
      if (normalized.startsWith('[')) {
        final nested = _decodeNestedJsonValue(normalized);
        if (nested is List) {
          for (final item in nested) {
            addUrl(item);
          }
        } else {
          addUrl(normalized);
        }
      } else {
        final parts = normalized.split(RegExp(r'[\n,]'));
        for (final part in parts) {
          addUrl(part);
        }
      }
    } else {
      addUrl(raw);
    }

    return urls;
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _sanitizeJsonInput(String input) {
    var value = input;
    if (value.startsWith('\uFEFF')) {
      value = value.replaceFirst(RegExp('^\uFEFF+'), '');
    }
    return value.trim();
  }

  dynamic _decodeNestedJsonValue(dynamic data, {int maxDepth = 5}) {
    var current = data;
    var depth = 0;

    while (depth < maxDepth && current is String) {
      final text = _sanitizeJsonInput(current);
      if (text.isEmpty) return '';

      final maybeJson = text.startsWith('{') ||
          text.startsWith('[') ||
          (text.startsWith('"') && text.endsWith('"'));
      if (!maybeJson) return current;

      try {
        current = json.decode(text);
        depth++;
      } catch (_) {
        return current;
      }
    }

    return current;
  }

  Map<String, dynamic>? _toSourceMap(dynamic item) {
    final decoded = _decodeNestedJsonValue(item);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
