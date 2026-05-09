import '../models/book.dart';

/// TXT 导出中收集到的图片引用。
class CacheExportImageRef {
  final String chapterTitle;
  final int index;
  final String src;

  const CacheExportImageRef({
    required this.chapterTitle,
    required this.index,
    required this.src,
  });
}

/// 单本书图片导出统计。
class CacheImageExportSummary {
  final int exportedCount;
  final int failedCount;

  const CacheImageExportSummary({
    this.exportedCount = 0,
    this.failedCount = 0,
  });
}

/// TXT 全本导出 payload（含拼好的正文 + 收集到的图片引用列表）。
class CacheTxtExportPayload {
  final String content;
  final List<CacheExportImageRef> imageRefs;

  const CacheTxtExportPayload({
    required this.content,
    required this.imageRefs,
  });
}

/// 单章 TXT 导出片段（含本章正文块 + 本章引用的图片）。
class CacheTxtChapterPayload {
  final String textBlock;
  final List<CacheExportImageRef> imageRefs;

  const CacheTxtChapterPayload({
    required this.textBlock,
    required this.imageRefs,
  });
}

/// 替换规则上下文：决定单本书在导出时是否真正应用替换规则。
class CacheBookExportReplaceContext {
  final bool enabled;
  final bool bookUseReplaceRule;
  final List<dynamic> rules; // ReplaceRule 列表（dynamic 避免循环依赖）

  const CacheBookExportReplaceContext({
    required this.enabled,
    required this.bookUseReplaceRule,
    required this.rules,
  });
}

final RegExp cacheExportImgSrcPattern = RegExp(
  r'''<img[^>]*\bsrc\s*=\s*["']?([^"'>\s]+)["']?[^>]*>''',
  caseSensitive: false,
);

/// 从单章正文里抓取所有 `<img src="...">` 的图片引用。
List<CacheExportImageRef> extractCacheExportImageRefsFromChapter(
  Chapter chapter,
) {
  final refs = <CacheExportImageRef>[];
  final content = chapter.content ?? '';
  if (content.trim().isEmpty) return refs;
  final lines = content.split('\n');
  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];
    for (final match in cacheExportImgSrcPattern.allMatches(line)) {
      final rawSrc = (match.group(1) ?? '').trim();
      if (rawSrc.isEmpty) continue;
      refs.add(
        CacheExportImageRef(
          chapterTitle: chapter.title,
          index: index,
          src: resolveCacheExportImageUrl(
            baseUrl: chapter.url,
            src: rawSrc,
          ),
        ),
      );
    }
  }
  return refs;
}

String resolveCacheExportImageUrl({
  required String? baseUrl,
  required String src,
}) {
  final trimmedSrc = src.trim();
  if (trimmedSrc.isEmpty) return '';
  final sourceUri = Uri.tryParse(trimmedSrc);
  if (sourceUri != null && sourceUri.hasScheme) {
    return sourceUri.toString();
  }
  final base = (baseUrl ?? '').trim();
  if (base.isEmpty) return trimmedSrc;
  final baseUri = Uri.tryParse(base);
  if (baseUri == null) return trimmedSrc;
  return baseUri.resolve(trimmedSrc).toString();
}
