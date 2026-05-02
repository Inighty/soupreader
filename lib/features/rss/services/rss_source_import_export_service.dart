import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/file_picker_save_compat.dart';
import '../../../core/utils/legado_json.dart';
import '../models/rss_source.dart';
import 'rss_source_import_helpers.dart';
import 'rss_source_io_models.dart';

export 'rss_source_io_models.dart';

typedef RssSourceImportHttpFetcher = Future<Response<String>> Function(
  Uri uri, {
  required bool requestWithoutUa,
});

/// RSS 订阅源导入服务（对齐 legado ImportRssSource 语义）
class RssSourceImportExportService {
  static const String requestWithoutUaSuffix = '#requestWithoutUA';

  RssSourceImportExportService({
    RssSourceImportHttpFetcher? httpFetcher,
    bool? isWeb,
  })  : _httpFetcher = httpFetcher,
        _isWeb = isWeb ?? kIsWeb;

  final RssSourceImportHttpFetcher? _httpFetcher;
  final bool _isWeb;

  Future<Response<String>> _defaultFetch(
    Uri uri, {
    required bool requestWithoutUa,
  }) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    ).get<String>(
      uri.toString(),
      options: Options(
        headers: requestWithoutUa ? const {'User-Agent': 'null'} : null,
      ),
    );
  }

  Future<Response<String>> _fetchFromUrl(
    Uri uri, {
    required bool requestWithoutUa,
  }) {
    final fetcher = _httpFetcher;
    if (fetcher != null) {
      return fetcher(uri, requestWithoutUa: requestWithoutUa);
    }
    return _defaultFetch(uri, requestWithoutUa: requestWithoutUa);
  }

  Future<RssSourceImportResult> _importFromSourceUrls(
    List<String> sourceUrls, {
    required int depth,
  }) async {
    final warnings = <String>[];
    var invalidCount = 0;
    var duplicateCount = 0;
    final sourceByUrl = <String, RssSource>{};
    final sourceRawJsonByUrl = <String, String>{};

    for (var i = 0; i < sourceUrls.length; i++) {
      final targetUrl = sourceUrls[i].trim();
      if (targetUrl.isEmpty) {
        invalidCount++;
        warnings.add('sourceUrls 第${i + 1}项为空，已跳过');
        continue;
      }
      if (!isHttpUrl(targetUrl)) {
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

      warnings.addAll(
        result.warnings.map((warning) => '[$targetUrl] $warning'),
      );

      for (final source in result.sources) {
        final url = source.sourceUrl.trim();
        if (url.isEmpty) continue;
        if (sourceByUrl.containsKey(url)) {
          duplicateCount++;
          sourceByUrl.remove(url);
        }
        sourceByUrl[url] = source;
        sourceRawJsonByUrl[url] = result.rawJsonForSourceUrl(url) ??
            LegadoJson.encode(source.toJson());
      }
    }

    final sources = sourceByUrl.values.toList(growable: false);
    if (sources.isEmpty) {
      return RssSourceImportResult(
        success: false,
        errorMessage: '未识别到有效订阅源（sourceUrls）',
        totalInputCount: sourceUrls.length,
        invalidCount: invalidCount,
        duplicateCount: duplicateCount,
        warnings: warnings,
      );
    }

    return RssSourceImportResult(
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

  Future<RssSourceImportResult> _importFromText(
    String text, {
    required int depth,
  }) async {
    if (depth > kRssSourceImportMaxDepth) {
      return const RssSourceImportResult(
        success: false,
        errorMessage: '导入层级过深，请检查输入内容是否循环引用',
      );
    }

    final raw = sanitizeJsonInput(text);
    if (raw.isEmpty) {
      return const RssSourceImportResult(
        success: false,
        errorMessage: '内容为空',
      );
    }

    if (isHttpUrl(raw)) {
      return _importFromUrl(raw, depth: depth + 1);
    }

    dynamic decoded;
    try {
      decoded = json.decode(raw);
      decoded = decodeNestedJsonValue(decoded);
    } catch (_) {
      return const RssSourceImportResult(
        success: false,
        errorMessage: '格式错误：需为订阅源 JSON、sourceUrls JSON 或 http/https 链接',
      );
    }

    final sourceUrls = extractSourceUrlsFromDecoded(decoded);
    if (sourceUrls != null) {
      if (sourceUrls.isEmpty) {
        return const RssSourceImportResult(
          success: false,
          errorMessage: 'sourceUrls 为空',
        );
      }
      return _importFromSourceUrls(sourceUrls, depth: depth + 1);
    }

    return importFromJson(raw);
  }

  Future<RssSourceImportResult> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return const RssSourceImportResult(cancelled: true);
      }

      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return const RssSourceImportResult(
          success: false,
          errorMessage: '无法读取文件内容',
        );
      }

      return importFromText(content);
    } catch (e) {
      return RssSourceImportResult(
        success: false,
        errorMessage: '导入失败: $e',
      );
    }
  }

  Future<RssSourceImportResult> importFromText(String text) {
    return _importFromText(text, depth: 0);
  }

  Future<RssSourceImportResult> importFromUrl(String url) {
    return _importFromUrl(url, depth: 0);
  }

  Future<RssSourceImportResult> importFromDefaultAsset({
    String assetPath = 'assets/rss/rssSources.json',
  }) async {
    try {
      final text = await rootBundle.loadString(assetPath);
      return importFromText(text);
    } catch (e) {
      return RssSourceImportResult(
        success: false,
        errorMessage: '默认订阅源读取失败: $e',
      );
    }
  }

  Future<RssSourceImportResult> _importFromUrl(
    String url, {
    required int depth,
  }) async {
    if (depth > kRssSourceImportMaxDepth) {
      return const RssSourceImportResult(
        success: false,
        errorMessage: '导入层级过深，请检查输入内容是否循环引用',
      );
    }

    final normalized = url.trim();
    if (!isHttpUrl(normalized)) {
      return const RssSourceImportResult(
        success: false,
        errorMessage: '请输入有效的 http/https 链接',
      );
    }

    var requestWithoutUa = false;
    var requestUrl = normalized;
    if (requestUrl.endsWith(requestWithoutUaSuffix)) {
      requestWithoutUa = true;
      requestUrl = requestUrl.substring(
        0,
        requestUrl.length - requestWithoutUaSuffix.length,
      );
    }

    final uri = Uri.tryParse(requestUrl);
    if (uri == null || !isHttpUrl(requestUrl)) {
      return const RssSourceImportResult(
        success: false,
        errorMessage: '链接格式错误',
      );
    }

    try {
      final response = await _fetchFromUrl(
        uri,
        requestWithoutUa: requestWithoutUa,
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return RssSourceImportResult(
          success: false,
          errorMessage: '网络请求失败（HTTP $status）',
        );
      }

      final data = response.data;
      if (data == null || data.trim().isEmpty) {
        return const RssSourceImportResult(
          success: false,
          errorMessage: '响应内容为空',
        );
      }

      final result = await _importFromText(data, depth: depth + 1);
      final warnings = <String>[];
      final redirectHint = buildRedirectHint(
        requested: uri,
        resolved: response.realUri,
      );
      if (redirectHint != null) {
        warnings.add(redirectHint);
      }
      if (requestWithoutUa) {
        warnings.add('已按 #requestWithoutUA 导入（User-Agent=null）');
      }
      if (warnings.isEmpty) {
        return result;
      }
      return result.copyWithMergedWarnings(warnings);
    } catch (error) {
      final message = describeRssNetworkError(error);
      if (_isWeb && isLikelyCorsError(message)) {
        return const RssSourceImportResult(
          success: false,
          errorMessage: '网络导入失败：浏览器跨域限制（CORS），请改用"扫码导入"或"文件导入"',
        );
      }
      return RssSourceImportResult(
        success: false,
        errorMessage: message,
      );
    }
  }

  RssSourceImportResult importFromJson(String jsonString) {
    final raw = sanitizeJsonInput(jsonString);
    if (raw.isEmpty) {
      return const RssSourceImportResult(
        success: false,
        errorMessage: 'JSON 内容为空',
      );
    }

    dynamic decoded;
    try {
      decoded = json.decode(raw);
      decoded = decodeNestedJsonValue(decoded);
    } catch (e) {
      return RssSourceImportResult(
        success: false,
        errorMessage: 'JSON 解析失败: $e',
      );
    }

    final warnings = <String>[];
    final sourceByUrl = <String, RssSource>{};
    final sourceRawByUrl = <String, String>{};
    var totalInputCount = 0;
    var invalidCount = 0;
    var duplicateCount = 0;

    Iterable<dynamic> normalizeItems(dynamic value) sync* {
      if (value is List) {
        yield* value;
        return;
      }
      if (value is Map) {
        if (value.containsKey('sourceUrl')) {
          yield value;
        } else {
          invalidCount++;
          warnings.add('未发现 sourceUrl 字段，已跳过');
        }
        return;
      }
      yield value;
    }

    for (final item in normalizeItems(decoded)) {
      totalInputCount++;
      Map<String, dynamic>? itemMap;
      if (item is Map<String, dynamic>) {
        itemMap = Map<String, dynamic>.from(item);
      } else if (item is Map) {
        itemMap = item.map((key, value) => MapEntry('$key', value));
      }
      if (itemMap == null) {
        invalidCount++;
        warnings.add('第$totalInputCount项不是对象，已跳过');
        continue;
      }

      RssSource source;
      try {
        source = RssSource.fromJson(itemMap);
      } catch (e) {
        invalidCount++;
        warnings.add('第$totalInputCount项解析失败：$e');
        continue;
      }

      final url = source.sourceUrl.trim();
      if (url.isEmpty) {
        invalidCount++;
        warnings.add('第$totalInputCount项缺少 sourceUrl，已跳过');
        continue;
      }

      if (sourceByUrl.containsKey(url)) {
        duplicateCount++;
        sourceByUrl.remove(url);
      }
      sourceByUrl[url] = source;

      final rawMap = Map<String, dynamic>.from(itemMap);
      rawMap['sourceUrl'] = url;
      sourceRawByUrl[url] = LegadoJson.encode(rawMap);
    }

    final sources = sourceByUrl.values.toList(growable: false);
    if (sources.isEmpty) {
      return RssSourceImportResult(
        success: false,
        errorMessage: 'JSON格式不支持或无有效订阅源',
        totalInputCount: totalInputCount,
        invalidCount: invalidCount,
        duplicateCount: duplicateCount,
        warnings: warnings,
      );
    }

    return RssSourceImportResult(
      success: true,
      sources: sources,
      importCount: sources.length,
      totalInputCount: totalInputCount,
      invalidCount: invalidCount,
      duplicateCount: duplicateCount,
      warnings: warnings,
      sourceRawJsonByUrl: sourceRawByUrl,
    );
  }

  /// 导出订阅源为 JSON
  String exportToJson(List<RssSource> sources) {
    final jsonList =
        sources.map((source) => source.toJson()).toList(growable: false);
    return LegadoJson.encode(jsonList);
  }

  /// 导出订阅源到文件
  Future<RssSourceExportFileResult> exportToFile(
    List<RssSource> sources, {
    String? defaultFileName,
  }) async {
    try {
      final jsonString = exportToJson(sources);
      final normalizedDefaultFileName = (defaultFileName ?? '').trim();
      final outputFileName = normalizedDefaultFileName.isNotEmpty
          ? normalizedDefaultFileName
          : 'soupreader_rss_${DateTime.now().millisecondsSinceEpoch}.json';
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出订阅源',
        fileName: outputFileName,
        allowedExtensions: const ['json'],
        text: jsonString,
      );

      if (outputPath == null || outputPath.trim().isEmpty) {
        return const RssSourceExportFileResult(cancelled: true);
      }

      final normalizedPath = outputPath.trim();
      return RssSourceExportFileResult(
        success: true,
        outputPath: normalizedPath,
      );
    } catch (error) {
      return RssSourceExportFileResult(
        success: false,
        errorMessage: '导出失败: $error',
      );
    }
  }

  /// 导出订阅源到临时文件，用于系统分享
  Future<File?> exportToShareFile(List<RssSource> sources) async {
    if (_isWeb) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/share_rss_source_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path);
      await file.writeAsString(exportToJson(sources));
      return file;
    } catch (_) {
      return null;
    }
  }
}
