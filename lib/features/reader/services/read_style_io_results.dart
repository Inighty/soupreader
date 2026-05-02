import 'dart:io';

import 'package:dio/dio.dart';

import '../models/reading_settings.dart';

/// 远程下载阅读样式 zip 的 HTTP 函数签名。
typedef ReadStyleHttpFetcher = Future<Response<List<int>>> Function(Uri uri);

/// 解析阅读样式背景图片目录的函数签名。
typedef ReadStyleBgDirectoryResolver = Future<Directory> Function();

/// 阅读样式导入结果。
class ReadStyleImportResult {
  final bool success;
  final bool cancelled;
  final ReadStyleConfig? style;
  final String? warning;
  final String? message;

  const ReadStyleImportResult({
    this.success = false,
    this.cancelled = false,
    this.style,
    this.warning,
    this.message,
  });
}

/// 阅读样式导出结果。
class ReadStyleExportResult {
  final bool success;
  final bool cancelled;
  final String? outputPath;
  final String? message;

  const ReadStyleExportResult({
    this.success = false,
    this.cancelled = false,
    this.outputPath,
    this.message,
  });
}

/// 阅读样式 zip 解析结果。
class ReadStyleZipParseResult {
  final bool success;
  final ReadStyleConfig? style;
  final String? warning;
  final String? errorMessage;

  const ReadStyleZipParseResult({
    required this.success,
    this.style,
    this.warning,
    this.errorMessage,
  });

  factory ReadStyleZipParseResult.ok(
    ReadStyleConfig style, {
    String? warning,
  }) {
    return ReadStyleZipParseResult(
      success: true,
      style: style,
      warning: warning,
    );
  }

  factory ReadStyleZipParseResult.error(String message) {
    return ReadStyleZipParseResult(
      success: false,
      errorMessage: message,
    );
  }
}
