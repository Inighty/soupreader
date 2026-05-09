import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/models/book_source.dart';
import '../../../core/services/exception_log_service.dart';
import '../../source/services/source/cover_loader.dart';
import '../models/book.dart';
import 'cache_export_file_name_helpers.dart';
import 'cache_export_models.dart';
import 'cache_export_txt_writer.dart';

/// 把 TXT 中收集到的图片下载到「书名_作者/images/章节」目录下。
Future<CacheImageExportSummary> exportCacheTxtImages({
  required Book book,
  required List<CacheExportImageRef> refs,
  required String outputDirectory,
  required int concurrency,
  required BookSource? source,
  required SourceCoverLoader sourceCoverLoader,
}) async {
  if (refs.isEmpty) return const CacheImageExportSummary();

  final author = book.author.trim().isEmpty ? '未知' : book.author.trim();
  final bookFolder = safeExportFolderName('${book.title}_$author');
  final outcomes = await mapWithConcurrencyOrdered<CacheExportImageRef, bool>(
    items: refs,
    concurrency: concurrency,
    mapper: (ref, _) async {
      try {
        final bytes = await resolveCacheExportImageBytes(
          source: source,
          imageUrl: ref.src,
          sourceCoverLoader: sourceCoverLoader,
        );
        if (bytes == null || bytes.isEmpty) return false;

        final chapterFolder = safeExportFolderName(ref.chapterTitle);
        final fileName = '${ref.index}-${stableExportHash16(ref.src)}.jpg';
        final filePath = p.join(
          outputDirectory,
          bookFolder,
          'images',
          chapterFolder,
          fileName,
        );
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        return true;
      } catch (error, stackTrace) {
        ExceptionLogService().record(
          node: 'bookshelf.cache.export_all.image_write_failed',
          message: '导出章节图片失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'bookId': book.id,
            'bookTitle': book.title,
            'chapterTitle': ref.chapterTitle,
            'imageUrl': ref.src,
          },
        );
        return false;
      }
    },
  );
  final exported = outcomes.where((ok) => ok).length;
  return CacheImageExportSummary(
    exportedCount: exported,
    failedCount: outcomes.length - exported,
  );
}

Future<Uint8List?> resolveCacheExportImageBytes({
  required BookSource? source,
  required String imageUrl,
  required SourceCoverLoader sourceCoverLoader,
}) async {
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme == 'data') {
    return _tryDecodeDataImage(trimmed);
  }
  if (uri != null && uri.scheme == 'file') {
    final file = File.fromUri(uri);
    if (await file.exists()) return file.readAsBytes();
    return null;
  }

  if (source != null) {
    final sourceBytes = await sourceCoverLoader.load(
      imageUrl: trimmed,
      source: source,
    );
    if (sourceBytes != null && sourceBytes.isNotEmpty) return sourceBytes;
  }

  return _fetchImageBytesFallback(trimmed);
}

Future<Uint8List?> _fetchImageBytesFallback(String imageUrl) async {
  final uri = Uri.tryParse(imageUrl);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }

  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode >= 400) return null;
    final bytes = await response.fold<List<int>>(
      <int>[],
      (prev, element) => prev..addAll(element),
    );
    if (bytes.isEmpty) return null;
    return Uint8List.fromList(bytes);
  } catch (_) {
    return null;
  } finally {
    client?.close(force: true);
  }
}

Uint8List? _tryDecodeDataImage(String dataUrl) {
  final match = RegExp(r'^data:[^;]+;base64,(.*)$', caseSensitive: false)
      .firstMatch(dataUrl.trim());
  if (match == null) return null;
  final raw = (match.group(1) ?? '').trim();
  if (raw.isEmpty) return null;
  final normalized = raw.replaceAll(RegExp(r'\s+'), '');
  final rem = normalized.length % 4;
  final padded = rem == 0
      ? normalized
      : normalized.padRight(normalized.length + (4 - rem), '=');
  try {
    return Uint8List.fromList(base64Decode(padded));
  } catch (_) {
    return null;
  }
}
