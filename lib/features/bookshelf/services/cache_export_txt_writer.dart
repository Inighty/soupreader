import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

import '../models/book.dart';
import 'cache_export_models.dart';
import 'cache_export_settings_store.dart';

/// 把 TXT 全本拼接为单字符串（含书名 / 作者 / 各章正文），并收集图片引用。
Future<CacheTxtExportPayload> buildCacheExportTxtPayload({
  required Book book,
  required List<Chapter> cachedChapters,
  required bool includeChapterTitle,
  required bool includeImages,
  required int concurrency,
  required Future<String> Function(String title) applyReplaceToTitle,
  required Future<String> Function(String content) applyReplaceToContent,
}) async {
  final chapterPayloads =
      await mapWithConcurrencyOrdered<Chapter, CacheTxtChapterPayload>(
    items: cachedChapters,
    concurrency: concurrency,
    mapper: (chapter, _) async {
      final rawTitle =
          chapter.title.trim().isEmpty ? '未命名章节' : chapter.title;
      final title = await applyReplaceToTitle(rawTitle);
      final rawContent = (chapter.content ?? '').trim();
      final content = await applyReplaceToContent(rawContent);
      final buffer = StringBuffer();
      if (includeChapterTitle) {
        buffer.writeln(title);
      }
      buffer
        ..writeln(content)
        ..writeln();
      return CacheTxtChapterPayload(
        textBlock: buffer.toString(),
        imageRefs: includeImages
            ? extractCacheExportImageRefsFromChapter(chapter)
            : const [],
      );
    },
  );

  final buffer = StringBuffer()
    ..writeln(book.title)
    ..writeln('作者：${book.author.isEmpty ? '未知' : book.author}')
    ..writeln();
  final imageRefs = <CacheExportImageRef>[];
  for (final payload in chapterPayloads) {
    buffer.write(payload.textBlock);
    if (payload.imageRefs.isNotEmpty) {
      imageRefs.addAll(payload.imageRefs);
    }
  }
  return CacheTxtExportPayload(
    content: buffer.toString(),
    imageRefs: imageRefs,
  );
}

List<int> encodeTxtContentByCharset(
  String content, {
  required String charset,
}) {
  final normalized = normalizeExportCharset(charset);
  switch (normalized.toUpperCase()) {
    case 'UTF-8':
      return utf8.encode(content);
    case 'GB2312':
    case 'GB18030':
    case 'GBK':
      return gbk.encode(content);
    case 'UNICODE':
    case 'UTF-16':
      return _encodeUtf16(content, littleEndian: false, includeBom: true);
    case 'UTF-16LE':
      return _encodeUtf16(content, littleEndian: true, includeBom: false);
    case 'ASCII':
      return const AsciiCodec(allowInvalid: true).encode(content);
    default:
      throw StateError('不支持的导出编码：$charset');
  }
}

String normalizeExportCharset(String charset) {
  final value = charset.trim();
  if (value.isEmpty) {
    return CacheExportSettingsStore.defaultExportCharset;
  }
  final upper = value.toUpperCase().replaceAll('_', '-');
  switch (upper) {
    case 'UTF8':
    case 'UTF-8':
      return 'UTF-8';
    case 'GB2312':
      return 'GB2312';
    case 'GB18030':
      return 'GB18030';
    case 'GBK':
      return 'GBK';
    case 'UNICODE':
      return 'Unicode';
    case 'UTF16':
    case 'UTF-16':
      return 'UTF-16';
    case 'UTF16LE':
    case 'UTF-16LE':
      return 'UTF-16LE';
    case 'ASCII':
      return 'ASCII';
    default:
      return value;
  }
}

List<int> _encodeUtf16(
  String content, {
  required bool littleEndian,
  required bool includeBom,
}) {
  final codeUnits = content.codeUnits;
  final totalLength = codeUnits.length * 2 + (includeBom ? 2 : 0);
  final data = ByteData(totalLength);
  final endian = littleEndian ? Endian.little : Endian.big;
  var offset = 0;
  if (includeBom) {
    data.setUint16(offset, 0xFEFF, endian);
    offset += 2;
  }
  for (final unit in codeUnits) {
    data.setUint16(offset, unit, endian);
    offset += 2;
  }
  return data.buffer.asUint8List();
}

/// 限流并发的 ordered map：保留输入顺序，并行度由 [concurrency] 控制。
Future<List<R>> mapWithConcurrencyOrdered<T, R>({
  required List<T> items,
  required int concurrency,
  required Future<R> Function(T item, int index) mapper,
}) async {
  if (items.isEmpty) return <R>[];
  final workerCount = concurrency < 1
      ? 1
      : (concurrency > items.length ? items.length : concurrency);
  if (workerCount == 1) {
    final results = <R>[];
    for (var index = 0; index < items.length; index += 1) {
      results.add(await mapper(items[index], index));
    }
    return results;
  }

  final results = List<R?>.filled(items.length, null);
  var nextIndex = 0;
  Future<void> worker() async {
    while (true) {
      if (nextIndex >= items.length) return;
      final index = nextIndex;
      nextIndex += 1;
      results[index] = await mapper(items[index], index);
    }
  }

  await Future.wait(
    List<Future<void>>.generate(workerCount, (_) => worker()),
  );
  return results.cast<R>();
}
