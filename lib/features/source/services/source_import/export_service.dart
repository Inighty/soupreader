import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:soupreader/core/utils/file_picker_save_compat.dart';
import 'package:soupreader/core/utils/legado_json.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_import/export_models.dart';
import 'package:soupreader/features/source/services/source_import/export_parser.dart';

export 'package:soupreader/features/source/services/source_import/export_models.dart';

typedef SourceImportHttpFetcher = Future<Response<String>> Function(Uri uri);

/// 书源导入导出服务
class SourceImportExportService {
  static const String _requestWithoutUaSuffix = '#requestWithoutUA';
  static const int _maxImportDepth = 3;

  final SourceImportHttpFetcher? _httpFetcher;
  final bool _isWeb;
  late final SourceImportExportParser _parser;

  SourceImportExportService({
    SourceImportHttpFetcher? httpFetcher,
    bool? isWeb,
  })  : _httpFetcher = httpFetcher,
        _isWeb = isWeb ?? kIsWeb {
    _parser = SourceImportExportParser(
      importFromUrl: _importFromUrl,
      maxImportDepth: _maxImportDepth,
    );
  }

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
      return fetcher(uri);
    }
    return _defaultFetch(
      uri,
      requestWithoutUa: requestWithoutUa,
    );
  }

  String? _buildRedirectHint({
    required Uri requested,
    required Uri? resolved,
  }) {
    if (resolved == null) return null;
    final from = requested.toString().trim();
    final to = resolved.toString().trim();
    if (from.isEmpty || to.isEmpty || from == to) {
      return null;
    }
    return '已跟随重定向：$from -> $to';
  }

  bool _isLikelyCorsError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('xmlhttprequest') ||
        lower.contains('cors') ||
        lower.contains('cross-origin') ||
        lower.contains('access-control-allow-origin');
  }

  String _networkErrorMessage(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return '网络请求失败：连接超时';
        case DioExceptionType.sendTimeout:
          return '网络请求失败：发送超时';
        case DioExceptionType.receiveTimeout:
          return '网络请求失败：接收超时';
        case DioExceptionType.badCertificate:
          return '网络请求失败：证书异常';
        case DioExceptionType.cancel:
          return '网络请求已取消';
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          if (status != null) {
            return '网络请求失败（HTTP $status）';
          }
          break;
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          break;
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return '网络请求失败: $message';
      }
    }
    return '网络请求失败: $error';
  }

  /// 从JSON文件导入书源
  Future<SourceImportResult> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return SourceImportResult(cancelled: true);
      }

      final file = result.files.first;
      String content;

      if (file.bytes != null) {
        // Web/iOS 使用 bytes
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        // 其他平台使用路径
        content = await File(file.path!).readAsString();
      } else {
        return SourceImportResult(
          success: false,
          errorMessage: '无法读取文件内容',
        );
      }

      return importFromText(content);
    } catch (e) {
      return SourceImportResult(
        success: false,
        errorMessage: '导入失败: $e',
      );
    }
  }

  /// 从JSON字符串导入书源
  SourceImportResult importFromJson(String jsonString) {
    return _parser.importFromJson(jsonString);
  }

  /// 从文本导入书源（支持 URL / JSON / {sourceUrls:[...]}）
  Future<SourceImportResult> importFromText(String text) {
    return _parser.importFromText(text, depth: 0);
  }

  /// 从URL导入书源
  Future<SourceImportResult> importFromUrl(String url) async {
    return _importFromUrl(url, depth: 0);
  }

  Future<SourceImportResult> _importFromUrl(
    String url, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      return const SourceImportResult(
        success: false,
        errorMessage: '导入层级过深，请检查输入内容是否循环引用',
      );
    }

    try {
      var normalizedUrl = url.trim();
      var requestWithoutUa = false;
      if (normalizedUrl.endsWith(_requestWithoutUaSuffix)) {
        requestWithoutUa = true;
        normalizedUrl = normalizedUrl
            .substring(0, normalizedUrl.length - _requestWithoutUaSuffix.length)
            .trim();
      }

      final uri = Uri.tryParse(normalizedUrl);
      if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
        return SourceImportResult(
          success: false,
          errorMessage: '无效链接',
        );
      }

      final response = await _fetchFromUrl(
        uri,
        requestWithoutUa: requestWithoutUa,
      );
      final redirectHint = _buildRedirectHint(
        requested: uri,
        resolved: response.realUri,
      );
      final warnings = <String>[];
      if (requestWithoutUa) {
        warnings.add('已按 #requestWithoutUA 导入（User-Agent=null）');
        if (_httpFetcher != null) {
          warnings.add('当前为自定义网络抓取器，可能未处理 User-Agent 置空语义');
        }
      }
      if (redirectHint != null) {
        warnings.add(redirectHint);
      }

      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return SourceImportResult(
          success: false,
          errorMessage: 'HTTP请求失败: $status',
          warnings: warnings,
        );
      }

      final content = (response.data ?? '').trim();
      if (content.isEmpty) {
        return SourceImportResult(
          success: false,
          errorMessage: '返回内容为空',
          warnings: warnings,
        );
      }

      final parsed = await _parser.importFromText(content, depth: depth + 1);
      return parsed.copyWithMergedWarnings(warnings);
    } catch (e) {
      final err = e.toString();
      if (_isWeb && _isLikelyCorsError(err)) {
        return SourceImportResult(
          success: false,
          errorMessage: '网络导入失败：浏览器跨域限制（CORS），请改用“从剪贴板导入”或“本地导入”',
        );
      }
      return SourceImportResult(
        success: false,
        errorMessage: _networkErrorMessage(e),
      );
    }
  }

  /// 导出书源为JSON
  String exportToJson(List<BookSource> sources) {
    final jsonList = sources.map((s) => s.toJson()).toList(growable: false);
    return LegadoJson.encode(jsonList);
  }

  /// 导出书源到文件
  Future<SourceExportFileResult> exportToFile(
    List<BookSource> sources, {
    String defaultFileName = 'bookSource.json',
  }) async {
    try {
      final jsonString = exportToJson(sources);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出书源',
        fileName: defaultFileName,
        allowedExtensions: const ['json'],
        text: jsonString,
      );

      if (outputPath == null || outputPath.trim().isEmpty) {
        return const SourceExportFileResult(cancelled: true);
      }

      final normalizedPath = outputPath.trim();
      return SourceExportFileResult(
        success: true,
        outputPath: normalizedPath,
      );
    } catch (e) {
      debugPrint('导出失败: $e');
      return SourceExportFileResult(
        success: false,
        errorMessage: '导出失败：$e',
      );
    }
  }

  /// 生成用于系统分享的临时 JSON 文件（移动端/桌面端）
  Future<File?> exportToShareFile(List<BookSource> sources) async {
    if (_isWeb) return null;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/share_book_source_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path);
      await file.writeAsString(exportToJson(sources));
      return file;
    } catch (e) {
      debugPrint('生成分享文件失败: $e');
      return null;
    }
  }
}
