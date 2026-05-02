import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../import/import_service.dart';
import 'remote_books_archive_link_store.dart';
import 'remote_books_archive_service.dart';
import 'remote_books_import_helpers.dart';
import 'remote_books_import_models.dart';
import 'remote_books_service.dart';
import 'remote_books_shelf_link_store.dart';

export 'remote_books_import_models.dart';

/// 远程书籍导入服务（WebDav -> 下载 -> 本地导入 -> 加入书架）。
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

  /// 当前 SoupReader 侧可导入的格式。
  static const Set<String> _supportedExtensions = <String>{
    'txt',
    'epub',
  };

  static const Set<String> _supportedArchiveExtensions = <String>{
    'zip',
    'rar',
    '7z',
  };

  /// 导入远程文件列表（按传入顺序串行执行）。
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
      final fileName = resolveRemoteBookFileName(entry);
      final extension = normalizeRemoteBookExtension(p.extension(fileName));

      // 压缩包：下载 -> 枚举候选 -> 逐个导入。
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
          final reason = compactRemoteBookErrorReason(error.toString());
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
        localPath = await downloadRemoteBookToLocalFile(
          dio: _dio,
          settings: settings,
          remoteUrl: remoteUrl,
          fileName: fileName,
          tryDelete: _tryDeleteFile,
        );
      } catch (error, stackTrace) {
        final reason = compactRemoteBookErrorReason(error.toString());
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
        final reason =
            compactRemoteBookErrorReason(result.errorMessage ?? '导入失败');
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
        final reason = compactRemoteBookErrorReason(error.toString());
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
      total: success + failures.length,
      success: success,
      failures: failures,
    );
  }

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

    final entryExt = normalizeRemoteBookExtension(p.extension(entryName));
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
      return ImportResult.error(
        '解压失败：${compactRemoteBookErrorReason(error.toString())}',
      );
    }

    try {
      final result = await _importService.importLocalBookByPath(extractedPath);
      if (!result.success || result.book == null) {
        final reason =
            compactRemoteBookErrorReason(result.errorMessage ?? '导入失败');
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
      return ImportResult.error(compactRemoteBookErrorReason(error.toString()));
    }
  }

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
      final reason =
          compactRemoteBookErrorReason(openResult.errorMessage ?? '解析失败');
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
        final reason = compactRemoteBookErrorReason(error.toString());
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
        final reason =
            compactRemoteBookErrorReason(result.errorMessage ?? '导入失败');
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
        final reason = compactRemoteBookErrorReason(error.toString());
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
