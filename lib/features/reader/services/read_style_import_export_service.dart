import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/file_picker_save_compat.dart';
import '../models/reading_settings.dart';

typedef ReadStyleHttpFetcher = Future<Response<List<int>>> Function(Uri uri);
typedef ReadStyleBgDirectoryResolver = Future<Directory> Function();

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

class ReadStyleImportExportService {
  ReadStyleImportExportService({
    ReadStyleHttpFetcher? httpFetcher,
    ReadStyleBgDirectoryResolver? bgDirectoryResolver,
  })  : _httpFetcher = httpFetcher,
        _bgDirectoryResolver = bgDirectoryResolver ?? _defaultBgDirectory;

  static const String _configFileName = 'readConfig.json';
  static const String _defaultExportZipName = 'readConfig.zip';

  final ReadStyleHttpFetcher? _httpFetcher;
  final ReadStyleBgDirectoryResolver _bgDirectoryResolver;

  Future<ReadStyleImportResult> importFromFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (picked == null || picked.files.isEmpty) {
        return const ReadStyleImportResult(cancelled: true);
      }

      final file = picked.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null) {
        final path = file.path?.trim();
        if (path == null || path.isEmpty) {
          return const ReadStyleImportResult(message: '无法读取文件内容');
        }
        bytes = await File(path).readAsBytes();
      }
      if (bytes.isEmpty) {
        return const ReadStyleImportResult(message: '导入文件为空');
      }

      final parsed = await parseZipBytes(
        bytes,
        persistExternalBackground: true,
      );
      if (!parsed.success || parsed.style == null) {
        return ReadStyleImportResult(
          message: parsed.errorMessage ?? '导入失败',
        );
      }
      return ReadStyleImportResult(
        success: true,
        style: parsed.style,
        warning: parsed.warning,
        message: '导入成功',
      );
    } catch (e) {
      return ReadStyleImportResult(
        message: '导入失败: $e',
      );
    }
  }

  Future<ReadStyleImportResult> importFromUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return const ReadStyleImportResult(message: '请输入有效地址');
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return const ReadStyleImportResult(message: '链接格式无效');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const ReadStyleImportResult(message: '仅支持 http/https 链接');
    }

    try {
      final response = await _fetchFromUrl(uri);
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        return ReadStyleImportResult(
          message: '网络请求失败（HTTP $statusCode）',
        );
      }
      final payload = response.data;
      if (payload == null || payload.isEmpty) {
        return const ReadStyleImportResult(message: '下载结果为空');
      }

      final parsed = await parseZipBytes(
        Uint8List.fromList(payload),
        persistExternalBackground: true,
      );
      if (!parsed.success || parsed.style == null) {
        return ReadStyleImportResult(
          message: parsed.errorMessage ?? '导入失败',
        );
      }
      final redirectWarning = _buildRedirectWarning(
        requestUri: uri,
        realUri: response.realUri,
      );
      return ReadStyleImportResult(
        success: true,
        style: parsed.style,
        warning: _mergeWarnings(parsed.warning, redirectWarning),
        message: '导入成功',
      );
    } catch (e) {
      return ReadStyleImportResult(
        message: '网络导入失败: $e',
      );
    }
  }

  Future<ReadStyleExportResult> exportStyle(ReadStyleConfig style) async {
    final safeStyle = style.sanitize();
    if (kIsWeb) {
      return const ReadStyleExportResult(
        message: '当前平台暂不支持直接导出文件',
      );
    }

    try {
      final exportBackground = await _resolveBackgroundForExport(safeStyle);
      final zipBytes = buildExportZipBytes(
        safeStyle,
        backgroundImageBytes: exportBackground?.bytes,
        backgroundImageName: exportBackground?.name,
      );

      final outputPath = await saveFileWithBytesCompat(
        dialogTitle: '导出配置',
        fileName: _buildExportFileName(safeStyle.name),
        allowedExtensions: const ['zip'],
        bytes: zipBytes,
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return const ReadStyleExportResult(cancelled: true);
      }
      final normalizedPath = outputPath.trim();
      final warning = (safeStyle.bgType == ReadStyleConfig.bgTypeFile &&
              exportBackground == null)
          ? '背景图文件不存在，已仅导出配置'
          : null;
      return ReadStyleExportResult(
        success: true,
        outputPath: normalizedPath,
        message: warning,
      );
    } catch (e) {
      return ReadStyleExportResult(
        message: '导出失败: $e',
      );
    }
  }

  Uint8List buildExportZipBytes(
    ReadStyleConfig style, {
    Uint8List? backgroundImageBytes,
    String? backgroundImageName,
  }) {
    final archive = Archive();
    var exportStyle = style.sanitize();

    if (backgroundImageBytes != null &&
        backgroundImageBytes.isNotEmpty &&
        backgroundImageName != null &&
        backgroundImageName.trim().isNotEmpty) {
      final normalizedName = p.basename(backgroundImageName.trim());
      archive.addFile(
        ArchiveFile(
          normalizedName,
          backgroundImageBytes.length,
          backgroundImageBytes,
        ),
      );
      if (exportStyle.bgType == ReadStyleConfig.bgTypeFile) {
        exportStyle = exportStyle.copyWith(bgStr: normalizedName);
      }
    }

    final configJson = const JsonEncoder.withIndent('  ').convert(
      exportStyle.toJson(),
    );
    final configBytes = Uint8List.fromList(utf8.encode(configJson));
    archive.addFile(
      ArchiveFile(_configFileName, configBytes.length, configBytes),
    );
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('无法生成导出文件');
    }
    return Uint8List.fromList(encoded);
  }

  Future<ReadStyleZipParseResult> parseZipBytes(
    Uint8List bytes, {
    bool persistExternalBackground = false,
  }) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final configFile = _findArchiveFileByBaseName(archive, _configFileName);
      if (configFile == null) {
        return ReadStyleZipParseResult.error('导入失败: 未找到 $_configFileName');
      }
      final configBytes = _archiveFileBytes(configFile);
      if (configBytes == null || configBytes.isEmpty) {
        return ReadStyleZipParseResult.error('导入失败: 配置文件内容为空');
      }
      final decoded =
          json.decode(utf8.decode(configBytes, allowMalformed: true));
      final map = _normalizeMap(decoded);
      if (map == null) {
        return ReadStyleZipParseResult.error('导入失败: 配置文件格式不支持');
      }

      var style = ReadStyleConfig.fromJson(map).sanitize();
      String? warning;

      if (style.bgType == ReadStyleConfig.bgTypeAsset) {
        final assetName = _extractBgName(style.bgStr);
        if (assetName.isEmpty) {
          style = _downgradeToColorStyle(style);
          warning = _mergeWarnings(warning, '内置背景图名称无效，已回退为纯色背景');
        } else {
          style = style.copyWith(
            bgType: ReadStyleConfig.bgTypeAsset,
            bgStr: assetName,
          );
        }
      } else if (style.bgType == ReadStyleConfig.bgTypeFile) {
        final bgName = _extractBgName(style.bgStr);
        if (bgName.isEmpty) {
          style = _downgradeToColorStyle(style);
          warning = _mergeWarnings(warning, '背景图文件名无效，已回退为纯色背景');
        } else {
          final bgFile = _findArchiveFileByBaseName(archive, bgName);
          final bgBytes = bgFile == null ? null : _archiveFileBytes(bgFile);
          if (bgBytes == null || bgBytes.isEmpty) {
            style = _downgradeToColorStyle(style);
            warning = _mergeWarnings(warning, '背景图文件缺失，已回退为纯色背景');
          } else if (persistExternalBackground) {
            final savedPath = await _saveImportedBackground(
              name: bgName,
              bytes: bgBytes,
            );
            if (savedPath == null) {
              style = _downgradeToColorStyle(style);
              warning = _mergeWarnings(warning, '背景图保存失败，已回退为纯色背景');
            } else {
              style = style.copyWith(
                bgType: ReadStyleConfig.bgTypeFile,
                bgStr: savedPath,
              );
            }
          } else {
            style = style.copyWith(
              bgType: ReadStyleConfig.bgTypeFile,
              bgStr: bgName,
            );
          }
        }
      }

      return ReadStyleZipParseResult.ok(
        style.sanitize(),
        warning: warning,
      );
    } catch (e) {
      return ReadStyleZipParseResult.error('导入失败: $e');
    }
  }

  Future<Response<List<int>>> _fetchFromUrl(Uri uri) {
    final fetcher = _httpFetcher;
    if (fetcher != null) {
      return fetcher(uri);
    }
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    ).get<List<int>>(uri.toString());
  }

  String _buildExportFileName(String styleName) {
    final normalized = styleName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return _defaultExportZipName;
    return '$normalized.zip';
  }

  Future<_ExportBackground?> _resolveBackgroundForExport(
    ReadStyleConfig style,
  ) async {
    if (style.bgType != ReadStyleConfig.bgTypeFile) {
      return null;
    }
    final raw = style.bgStr.trim();
    if (raw.isEmpty) return null;

    final candidates = <String>{raw};
    final baseName = _extractBgName(raw);
    if (baseName.isNotEmpty) {
      candidates.add(baseName);
    }

    if (!p.isAbsolute(raw)) {
      final directory = await _bgDirectoryResolver();
      candidates.add(p.join(directory.path, raw));
      if (baseName.isNotEmpty) {
        candidates.add(p.join(directory.path, baseName));
      }
    }

    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      return _ExportBackground(
        name: _extractBgName(file.path),
        bytes: bytes,
      );
    }
    return null;
  }

  ArchiveFile? _findArchiveFileByBaseName(Archive archive, String targetName) {
    final target = targetName.toLowerCase();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final rawName = file.name.replaceAll('\\', '/').trim();
      if (rawName.isEmpty) continue;
      final baseName = p.basename(rawName).toLowerCase();
      if (baseName == target || rawName.toLowerCase() == target) {
        return file;
      }
    }
    return null;
  }

  Uint8List? _archiveFileBytes(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    if (content is String) return Uint8List.fromList(utf8.encode(content));
    return null;
  }

  Map<String, dynamic>? _normalizeMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  ReadStyleConfig _downgradeToColorStyle(ReadStyleConfig style) {
    final safe = style.sanitize();
    final color = safe.backgroundColor;
    final hex =
        (color & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    return safe.copyWith(
      bgType: ReadStyleConfig.bgTypeColor,
      bgStr: '#$hex',
    );
  }

  String _extractBgName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    return p.basename(text.replaceAll('\\', '/')).trim();
  }

  String? _buildRedirectWarning({
    required Uri requestUri,
    required Uri? realUri,
  }) {
    if (realUri == null) return null;
    final from = requestUri.toString().trim();
    final to = realUri.toString().trim();
    if (from.isEmpty || to.isEmpty || from == to) {
      return null;
    }
    return '已跟随重定向：$from -> $to';
  }

  String? _mergeWarnings(String? first, String? second) {
    final values = <String>[];
    final textA = first?.trim();
    if (textA != null && textA.isNotEmpty) {
      values.add(textA);
    }
    final textB = second?.trim();
    if (textB != null && textB.isNotEmpty) {
      values.add(textB);
    }
    if (values.isEmpty) return null;
    return values.join('；');
  }

  Future<String?> _saveImportedBackground({
    required String name,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;
    try {
      final directory = await _bgDirectoryResolver();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final fileName = _extractBgName(name);
      if (fileName.isEmpty) return null;
      final targetPath = p.join(directory.path, fileName);
      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(bytes, flush: true);
      return targetFile.path;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _defaultBgDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'reader', 'bg'));
  }
}

class _ExportBackground {
  final String name;
  final Uint8List bytes;

  const _ExportBackground({
    required this.name,
    required this.bytes,
  });
}
