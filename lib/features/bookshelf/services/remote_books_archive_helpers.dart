import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/exception_log_service.dart';

/// 远程压缩包子系统使用的纯函数与目录解析 helper。
class RemoteBooksArchiveHelpers {
  RemoteBooksArchiveHelpers._();

  static const Set<String> legacyBookExtensions = <String>{
    'txt',
    'epub',
    'umd',
    'pdf',
    'mobi',
    'azw3',
    'azw',
  };

  static String formatDownloadHttpError(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return '无权限（HTTP $statusCode），请检查 WebDav 账号密码';
      case 404:
        return '文件不存在（HTTP 404）';
      default:
        return 'HTTP $statusCode';
    }
  }

  static List<int>? responseBytes(dynamic raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return raw;
    return null;
  }

  static String sanitizeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final ext = p.extension(trimmed);
    final name = p.basenameWithoutExtension(trimmed);
    final normalizedName = name
        .replaceAll(RegExp(r'[\\\\/\\u0000-\\u001F]'), '_')
        .replaceAll(RegExp(r'[:*?\"<>|]'), '_')
        .trim();
    final normalizedExt = ext
        .replaceAll(RegExp(r'[\\\\/\\u0000-\\u001F]'), '')
        .replaceAll(RegExp(r'[:*?\"<>|]'), '')
        .trim();
    final safeName = normalizedName.isEmpty ? 'remote_archive' : normalizedName;
    final safeExt = normalizedExt.toLowerCase();
    return safeExt.isEmpty ? safeName : '$safeName$safeExt';
  }

  static String normalizeExtension(String rawExtension) {
    var ext = rawExtension.trim().toLowerCase();
    if (ext.startsWith('.')) ext = ext.substring(1);
    return ext;
  }

  static Future<void> atomicWriteBytes({
    required File targetFile,
    required String tempPath,
    required List<int> bytes,
    required ExceptionLogService exceptionLogService,
  }) async {
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tryDeleteFile(tempFile, exceptionLogService);
    }

    await tempFile.writeAsBytes(bytes, flush: true);

    if (await targetFile.exists()) {
      await tryDeleteFile(targetFile, exceptionLogService);
    }

    await tempFile.rename(targetFile.path);
  }

  static Future<void> tryDeleteFile(
    File file,
    ExceptionLogService exceptionLogService,
  ) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      exceptionLogService.record(
        node: 'remote_books.archive.cleanup.failed',
        message: '清理远程书籍压缩包临时文件失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'filePath': file.path,
        },
      );
    }
  }

  static ArchiveFile? findArchiveFileByBaseName(
    Archive archive,
    String fileName,
  ) {
    final normalized = fileName.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final base = p.basename(file.name).trim().toLowerCase();
      if (base == normalized) return file;
    }
    return null;
  }

  static Uint8List? archiveFileBytes(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    if (content is String) return Uint8List.fromList(utf8.encode(content));
    return null;
  }

  static String compactReason(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  /// 生成短 hash（用于避免不同目录同名压缩包缓存互相覆盖）。
  /// 使用 FNV-1a 32-bit，避免引入额外依赖。
  static String fnv1aHex(String input) {
    const int fnvOffsetBasis = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    var hash = fnvOffsetBasis;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<Directory> ensureArchiveDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(docs.path, '.remote_books', 'archives'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    if (!await target.exists()) {
      throw Exception('创建本地压缩包缓存目录失败');
    }
    return target;
  }

  static Future<Directory> ensureArchiveEntryDirectory({
    required String archiveKey,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final target = Directory(
      p.join(docs.path, '.remote_books', 'archive_entries', archiveKey),
    );
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    if (!await target.exists()) {
      throw Exception('创建本地压缩包条目缓存目录失败');
    }
    return target;
  }
}
