import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../import/import_service.dart';
import 'remote_books_archive_link_store.dart';
import 'remote_books_archive_service.dart';
import 'remote_books_service.dart';
import 'remote_books_shelf_link_store.dart';

class RemoteBooksImportFailure {
  final String fileName;
  final String remoteUrl;
  final String message;

  const RemoteBooksImportFailure({
    required this.fileName,
    required this.remoteUrl,
    required this.message,
  });
}

class RemoteBooksImportSummary {
  final int total;
  final int success;
  final List<RemoteBooksImportFailure> failures;

  const RemoteBooksImportSummary({
    required this.total,
    required this.success,
    required this.failures,
  });

  int get failed => failures.length;

  String get summaryText {
    return '共 $total 本：成功 $success，失败 $failed';
  }
}

/// 远程书籍导入服务（WebDav -> 下载 -> 本地导入 -> 加入书架）。
///
/// 对齐 legado `RemoteBookViewModel.addToBookshelf` 的核心语义，同时补齐：
/// - 多文件导入的成功/失败聚合；
/// - 明确的中文失败提示与必要日志；
/// - 禁止并发（由调用方做 UI 层防抖/禁用）。
class RemoteBooksImportService {
  RemoteBooksImportService({
    Dio? dio,
    ImportService? importService,
    RemoteBooksShelfLinkStore? shelfLinkStore,
    RemoteBooksArchiveLinkStore? archiveLinkStore,
    RemoteBooksArchiveService? archiveService,
    ExceptionLogService? exceptionLogService,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 60),
                responseType: ResponseType.bytes,
                validateStatus: (_) => true,
              ),
            ),
        _importService = importService ?? ImportService(),
        _shelfLinkStore = shelfLinkStore ?? RemoteBooksShelfLinkStore(),
        _archiveLinkStore = archiveLinkStore ?? RemoteBooksArchiveLinkStore(),
        _archiveService = archiveService ?? RemoteBooksArchiveService(),
        _exceptionLogService = exceptionLogService ?? ExceptionLogService();

  final Dio _dio;
  final ImportService _importService;
  final RemoteBooksShelfLinkStore _shelfLinkStore;
  final RemoteBooksArchiveLinkStore _archiveLinkStore;
  final RemoteBooksArchiveService _archiveService;
  final ExceptionLogService _exceptionLogService;

  /// 当前 SoupReader 侧可导入的格式（与 ImportService 兼容）。
  static const Set<String> _supportedExtensions = <String>{
    'txt',
    'epub',
  };

  static const Set<String> _supportedArchiveExtensions = <String>{
    'zip',
    'rar',
    '7z',
  };

  /// 导入远程文件列表（按传入顺序串行执行，避免并发导入导致 DB/文件写入竞争）。
  Future<RemoteBooksImportSummary> importRemoteEntries({
    required AppSettings settings,
    required List<RemoteBookEntry> entries,
  }) async {
    final unique = <String, RemoteBookEntry>{};
    for (final entry in entries) {
      final remoteUrl = entry.path.trim();
      if (remoteUrl.isEmpty) continue;
      unique[remoteUrl] = entry;
    }

    if (unique.isEmpty) {
      return const RemoteBooksImportSummary(
        total: 0,
        success: 0,
        failures: <RemoteBooksImportFailure>[],
      );
    }

    var success = 0;
    final failures = <RemoteBooksImportFailure>[];

    for (final entry in unique.values) {
      final remoteUrl = entry.path.trim();
      final fileName = _resolveRemoteFileName(entry);
      final extension = _normalizeExtension(p.extension(fileName));

      // 压缩包：对齐 legado `LocalBook.importFiles` 语义：下载 -> 枚举候选 -> 逐个导入。
      if (_supportedArchiveExtensions.contains(extension)) {
        try {
          final imported = await _importRemoteArchive(
            settings: settings,
            remoteUrl: remoteUrl,
            archiveFileName: fileName,
            failures: failures,
          );
          if (imported > 0) {
            success += imported;
          }
        } catch (error, stackTrace) {
          final reason = _compactReason(error.toString());
          failures.add(
            RemoteBooksImportFailure(
              fileName: fileName,
              remoteUrl: remoteUrl,
              message: '压缩包导入失败：$reason',
            ),
          );
          _exceptionLogService.record(
            node: 'remote_books.import.archive.failed',
            message: '导入远程压缩包失败',
            error: error,
            stackTrace: stackTrace,
            context: <String, dynamic>{
              'remoteUrl': remoteUrl,
              'fileName': fileName,
              'extension': extension,
            },
          );
        }
        continue;
      }

      if (!_supportedExtensions.contains(extension)) {
        final reason = extension.isEmpty ? '不支持的文件格式' : '暂不支持导入该格式：$extension';
        failures.add(
          RemoteBooksImportFailure(
            fileName: fileName,
            remoteUrl: remoteUrl,
            message: reason,
          ),
        );
        _exceptionLogService.record(
          node: 'remote_books.import.unsupported',
          message: '远程书籍导入失败：不支持的格式',
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'fileName': fileName,
            'extension': extension,
          },
        );
        continue;
      }

      String? localPath;
      try {
        localPath = await _downloadRemoteBookToLocalFile(
          settings: settings,
          remoteUrl: remoteUrl,
          fileName: fileName,
        );
      } catch (error, stackTrace) {
        final reason = _compactReason(error.toString());
        failures.add(
          RemoteBooksImportFailure(
            fileName: fileName,
            remoteUrl: remoteUrl,
            message: '下载失败：$reason',
          ),
        );
        _exceptionLogService.record(
          node: 'remote_books.import.download.failed',
          message: '下载远程书籍失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'fileName': fileName,
          },
        );
        continue;
      }

      try {
        final result = await _importService.importLocalBookByPath(localPath);
        if (result.success) {
          success++;
          final book = result.book;
          if (book != null) {
            await _shelfLinkStore.upsertLink(
              remoteUrl: remoteUrl,
              bookId: book.id,
            );
          }
          continue;
        }
        final reason = _compactReason(result.errorMessage ?? '导入失败');
        failures.add(
          RemoteBooksImportFailure(
            fileName: fileName,
            remoteUrl: remoteUrl,
            message: reason,
          ),
        );
        _exceptionLogService.record(
          node: 'remote_books.import.parse.failed',
          message: '导入远程书籍失败',
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'fileName': fileName,
            'localPath': localPath,
            'reason': reason,
          },
        );
        await _tryDeleteFile(localPath);
      } catch (error, stackTrace) {
        final reason = _compactReason(error.toString());
        failures.add(
          RemoteBooksImportFailure(
            fileName: fileName,
            remoteUrl: remoteUrl,
            message: reason,
          ),
        );
        _exceptionLogService.record(
          node: 'remote_books.import.failed',
          message: '导入远程书籍异常',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'fileName': fileName,
            'localPath': localPath,
          },
        );
        await _tryDeleteFile(localPath);
      }
    }

    return RemoteBooksImportSummary(
      // 说明：总数口径与 legacy 不同（legacy 无汇总提示）；
      // 这里对齐 UI 语义：“本次尝试导入的书籍数”：
      // - 普通文件：1 个远程文件对应 1 本书；
      // - 压缩包：可能对应多本书，因此 success 可能大于 entries 数量。
      total: success + failures.length,
      success: success,
      failures: failures,
    );
  }

  /// 从“已下载的本地压缩包”中导入指定条目（用于“打开压缩包 -> 选择阅读条目”流程）。
  ///
  /// 说明：
  /// - legacy 支持 zip/rar/7z，但 Flutter 侧当前仅实现 zip；
  /// - candidates 列表由 `RemoteBooksArchiveService.parseLocalArchive` 生成，默认只包含 txt/epub。
  ///
  /// 返回：
  /// - `success=true` 且 `book!=null`：导入成功；
  /// - `success=false`：失败原因写入 `errorMessage`（并记录必要日志）。
  Future<ImportResult> importArchiveEntryForReading({
    required String remoteArchiveUrl,
    required String localArchivePath,
    required String entryFileName,
    String? archiveFileName,
  }) async {
    final remoteUrl = remoteArchiveUrl.trim();
    final archivePath = localArchivePath.trim();
    final entryName = entryFileName.trim();
    final archiveName = (archiveFileName ?? '').trim();
    if (remoteUrl.isEmpty || archivePath.isEmpty || entryName.isEmpty) {
      return ImportResult.error('导入参数无效');
    }

    final entryExt = _normalizeExtension(p.extension(entryName));
    if (!_supportedExtensions.contains(entryExt)) {
      return ImportResult.error('暂不支持导入该格式：$entryExt');
    }

    late final String extractedPath;
    try {
      extractedPath = await _archiveService.extractZipEntryToLocalFile(
        localArchivePath: archivePath,
        entryFileName: entryName,
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive.entry.extract.failed',
        message: '解压压缩包条目失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'remoteUrl': remoteUrl,
          'archiveName': archiveName,
          'localArchivePath': archivePath,
          'entryName': entryName,
        },
      );
      return ImportResult.error('解压失败：${_compactReason(error.toString())}');
    }

    try {
      final result = await _importService.importLocalBookByPath(extractedPath);
      if (!result.success || result.book == null) {
        final reason = _compactReason(result.errorMessage ?? '导入失败');
        _exceptionLogService.record(
          node: 'remote_books.archive.entry.import.failed',
          message: '导入压缩包条目失败',
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'archiveName': archiveName,
            'localArchivePath': archivePath,
            'entryName': entryName,
            'extractedPath': extractedPath,
            'reason': reason,
          },
        );
        await _tryDeleteFile(extractedPath);
        return ImportResult.error(reason);
      }

      await _archiveLinkStore.upsertEntryLink(
        remoteArchiveUrl: remoteUrl,
        entryName: entryName,
        bookId: result.book!.id,
      );
      return result;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive.entry.import.exception',
        message: '导入压缩包条目异常',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'remoteUrl': remoteUrl,
          'archiveName': archiveName,
          'localArchivePath': archivePath,
          'entryName': entryName,
          'extractedPath': extractedPath,
        },
      );
      if (extractedPath.trim().isNotEmpty) {
        await _tryDeleteFile(extractedPath);
      }
      return ImportResult.error(_compactReason(error.toString()));
    }
  }

  /// 导入远程压缩包（zip/rar/7z）：
  /// - 下载并缓存压缩包；
  /// - 枚举压缩包内可导入候选（当前仅支持 txt/epub）；
  /// - 逐条解压并调用 ImportService 导入；
  /// - 写入 remoteArchiveUrl -> entryName -> bookId 映射，供 UI “点击压缩包 -> 选择阅读条目”使用。
  ///
  /// 注意：
  /// - legado 支持 zip/rar/7z，但 Flutter 侧当前仅实现 zip 解析；
  /// - rar/7z 会返回明确中文提示并计入 failures。
  Future<int> _importRemoteArchive({
    required AppSettings settings,
    required String remoteUrl,
    required String archiveFileName,
    required List<RemoteBooksImportFailure> failures,
  }) async {
    final openResult = await _archiveService.openRemoteArchive(
      settings: settings,
      remoteUrl: remoteUrl,
      fileName: archiveFileName,
      allowDownload: true,
      allowedBookExtensions: _supportedExtensions,
    );

    if (!openResult.success || openResult.localArchivePath == null) {
      final reason = _compactReason(openResult.errorMessage ?? '解析失败');
      failures.add(
        RemoteBooksImportFailure(
          fileName: archiveFileName,
          remoteUrl: remoteUrl,
          message: '压缩包解析失败：$reason',
        ),
      );
      return 0;
    }

    final candidates = openResult.candidates;
    if (candidates.isEmpty) {
      final warning = openResult.warning?.trim();
      failures.add(
        RemoteBooksImportFailure(
          fileName: archiveFileName,
          remoteUrl: remoteUrl,
          message: warning == null || warning.isEmpty
              ? '压缩包内未找到可导入文件（仅支持 txt/epub）'
              : '压缩包内未找到可导入文件（仅支持 txt/epub）。$warning',
        ),
      );
      return 0;
    }

    var successCount = 0;
    for (final candidate in candidates) {
      final entryName = candidate.fileName.trim();
      if (entryName.isEmpty) continue;

      String? extractedPath;
      try {
        extractedPath = await _archiveService.extractZipEntryToLocalFile(
          localArchivePath: openResult.localArchivePath!,
          entryFileName: entryName,
        );
      } catch (error, stackTrace) {
        final reason = _compactReason(error.toString());
        failures.add(
          RemoteBooksImportFailure(
            fileName: '$archiveFileName::$entryName',
            remoteUrl: remoteUrl,
            message: '解压失败：$reason',
          ),
        );
        _exceptionLogService.record(
          node: 'remote_books.import.archive.extract.failed',
          message: '解压远程压缩包条目失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'archiveFileName': archiveFileName,
            'entryName': entryName,
          },
        );
        continue;
      }

      try {
        final result =
            await _importService.importLocalBookByPath(extractedPath);
        if (result.success && result.book != null) {
          successCount++;
          await _archiveLinkStore.upsertEntryLink(
            remoteArchiveUrl: remoteUrl,
            entryName: entryName,
            bookId: result.book!.id,
          );
          continue;
        }
        final reason = _compactReason(result.errorMessage ?? '导入失败');
        failures.add(
          RemoteBooksImportFailure(
            fileName: '$archiveFileName::$entryName',
            remoteUrl: remoteUrl,
            message: reason,
          ),
        );
        _exceptionLogService.record(
          node: 'remote_books.import.archive.entry.failed',
          message: '导入压缩包条目失败',
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'archiveFileName': archiveFileName,
            'entryName': entryName,
            'extractedPath': extractedPath,
            'reason': reason,
          },
        );
        await _tryDeleteFile(extractedPath);
      } catch (error, stackTrace) {
        final reason = _compactReason(error.toString());
        failures.add(
          RemoteBooksImportFailure(
            fileName: '$archiveFileName::$entryName',
            remoteUrl: remoteUrl,
            message: reason,
          ),
        );
        _exceptionLogService.record(
          node: 'remote_books.import.archive.entry.exception',
          message: '导入压缩包条目异常',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'archiveFileName': archiveFileName,
            'entryName': entryName,
            'extractedPath': extractedPath,
          },
        );
        await _tryDeleteFile(extractedPath);
      }
    }

    _exceptionLogService.record(
      node: 'remote_books.import.archive.summary',
      message: '远程压缩包导入完成',
      context: <String, dynamic>{
        'remoteUrl': remoteUrl,
        'archiveFileName': archiveFileName,
        'candidateCount': candidates.length,
        'successCount': successCount,
        'warning': openResult.warning,
      },
    );

    return successCount;
  }

  String _resolveRemoteFileName(RemoteBookEntry entry) {
    final name = entry.displayName.trim();
    if (name.isNotEmpty) return name;
    return _extractFileNameFromUrl(entry.path);
  }

  String _extractFileNameFromUrl(String remoteUrl) {
    final uri = Uri.tryParse(remoteUrl.trim());
    if (uri == null) return 'remote_book';
    if (uri.pathSegments.isEmpty) return 'remote_book';
    final last = uri.pathSegments.last.trim();
    return last.isEmpty ? 'remote_book' : last;
  }

  String _normalizeExtension(String rawExtension) {
    var ext = rawExtension.trim().toLowerCase();
    if (ext.startsWith('.')) ext = ext.substring(1);
    return ext;
  }

  String _compactReason(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  Future<String> _downloadRemoteBookToLocalFile({
    required AppSettings settings,
    required String remoteUrl,
    required String fileName,
  }) async {
    final uri = Uri.tryParse(remoteUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw Exception('远程地址无效，请检查 WebDav 列表返回的链接');
    }
    final normalizedFileName = _sanitizeFileName(fileName);
    if (normalizedFileName.isEmpty) {
      throw Exception('无法识别下载文件名');
    }

    final directory = await _ensureRemoteBooksDirectory();
    final targetPath = p.join(directory.path, normalizedFileName);
    final tempPath = '$targetPath.download';

    final response = await _dio.request<dynamic>(
      uri.toString(),
      options: Options(
        method: 'GET',
        headers: _buildAuthHeaders(settings),
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );

    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception(_formatDownloadHttpError(code));
    }

    final bytes = _responseBytes(response.data);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('下载内容为空');
    }

    await _atomicWriteBytes(
      targetPath: targetPath,
      tempPath: tempPath,
      bytes: bytes,
    );
    return targetPath;
  }

  String _formatDownloadHttpError(int statusCode) {
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

  Map<String, String> _buildAuthHeaders(AppSettings settings) {
    final account = settings.webDavAccount.trim();
    final password = settings.webDavPassword.trim();
    final payload = base64Encode(utf8.encode('$account:$password'));
    return <String, String>{
      'Authorization': 'Basic $payload',
    };
  }

  List<int>? _responseBytes(dynamic raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return raw;
    return null;
  }

  Future<Directory> _ensureRemoteBooksDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(docs.path, '.remote_books'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    if (!await target.exists()) {
      throw Exception('创建本地缓存目录失败');
    }
    return target;
  }

  String _sanitizeFileName(String value) {
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
    final safeName = normalizedName.isEmpty ? 'remote_book' : normalizedName;
    final safeExt = normalizedExt.toLowerCase();
    return safeExt.isEmpty ? safeName : '$safeName$safeExt';
  }

  Future<void> _atomicWriteBytes({
    required String targetPath,
    required String tempPath,
    required List<int> bytes,
  }) async {
    final tempFile = File(tempPath);
    final targetFile = File(targetPath);

    if (await tempFile.exists()) {
      await _tryDeleteFile(tempPath);
    }

    await tempFile.writeAsBytes(bytes, flush: true);

    if (await targetFile.exists()) {
      await _tryDeleteFile(targetPath);
    }

    await tempFile.rename(targetPath);
  }

  Future<void> _tryDeleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.import.cleanup.failed',
        message: '清理远程书籍临时文件失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'filePath': filePath,
        },
      );
    }
  }
}
