import 'dart:io';

import '../../../core/services/exception_log_service.dart';
import '../models/book.dart';

/// 删除已被移出书架的本地书籍的封面 / 原文件。
///
/// 与 legado `BookshelfActivity#deleteBook` 中的「删除源文件」语义对齐：
/// - 永远尝试删除「封面文件」（仅限 file:// 等本地路径）
/// - [deleteOriginal] 为 true 时再删除 `localPath` 或 `bookUrl`
Future<void> deleteBookshelfManageLocalBookArtifacts({
  required Book book,
  required bool deleteOriginal,
  required ExceptionLogService exceptionLogService,
}) async {
  final coverPath = _normalizeLocalFilePath(book.coverUrl);
  await _deleteFileIfExists(
    book: book,
    filePath: coverPath,
    nodeSuffix: 'delete_cover',
    exceptionLogService: exceptionLogService,
  );
  if (!deleteOriginal) return;

  final localPath = _normalizeLocalFilePath(book.localPath);
  final originalPath = localPath ?? _normalizeLocalFilePath(book.bookUrl);
  await _deleteFileIfExists(
    book: book,
    filePath: originalPath,
    nodeSuffix: 'delete_original',
    exceptionLogService: exceptionLogService,
  );
}

String? _normalizeLocalFilePath(String? rawValue) {
  final raw = (rawValue ?? '').trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return raw;
  if (!uri.hasScheme) return raw;
  if (uri.scheme.toLowerCase() == 'file') {
    try {
      final filePath = uri.toFilePath();
      final normalized = filePath.trim();
      return normalized.isEmpty ? null : normalized;
    } catch (_) {
      return null;
    }
  }
  return null;
}

Future<void> _deleteFileIfExists({
  required Book book,
  required String? filePath,
  required String nodeSuffix,
  required ExceptionLogService exceptionLogService,
}) async {
  final normalizedPath = (filePath ?? '').trim();
  if (normalizedPath.isEmpty) return;
  try {
    final file = File(normalizedPath);
    if (await file.exists()) await file.delete();
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'bookshelf_manage.menu_del_selection.$nodeSuffix',
      message: '书架管理删除本地文件失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'bookId': book.id,
        'bookTitle': book.title,
        'filePath': normalizedPath,
      },
    );
  }
}
