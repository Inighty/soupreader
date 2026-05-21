import 'package:flutter/cupertino.dart';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book.dart';
import '../../../core/utils/chinese_script_converter.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../models/reading_settings.dart';
import '../services/reader_content_processor.dart';
import '../utils/chapter_progress_utils.dart';
import '../widgets/page_factory.dart';
import 'reader_state.dart';

/// 处理章节标题与正文（繁简转换、净化标题、ruby/h 标签清理、legado 风格格式化）。
({String title, String content}) processReaderChapterContent({
  required SettingsState settings,
  required ChineseScriptConverter chineseConverter,
  required String chapterId,
  required String rawTitle,
  required String rawContent,
}) {
  var title = _convertChinese(chineseConverter, settings, rawTitle);
  var content = rawContent;

  if (settings.settings.cleanChapterTitle) {
    content =
        ReaderContentProcessor.removeDuplicateTitle(content, title).content;
  }
  if (settings.delRubyTag) {
    content = ReaderContentProcessor.removeRubyTags(content);
  }
  if (settings.delHTag) {
    content = ReaderContentProcessor.removeHtmlHeaderTags(content);
  }
  content = _convertChinese(chineseConverter, settings, content);
  content = ReaderContentProcessor.formatContentLikeLegado(content);

  return (title: title, content: content);
}

String _convertChinese(
  ChineseScriptConverter converter,
  SettingsState settings,
  String text,
) {
  switch (settings.settings.chineseConverterType) {
    case ChineseConverterType.traditionalToSimplified:
      return converter.traditionalToSimplified(text);
    case ChineseConverterType.simplifiedToTraditional:
      return converter.simplifiedToTraditional(text);
    default:
      return text;
  }
}

/// 拉取章节正文：优先用缓存，再走 [RuleParserEngine]。
Future<String> fetchReaderChapterContent({
  required Chapter chapter,
  required String? sourceUrlHint,
  required SourceRepository sourceRepo,
  required RuleParserEngine ruleEngine,
}) async {
  final existing = chapter.content;
  if (existing != null && existing.isNotEmpty) return existing;

  final url = (chapter.url ?? '').trim();
  if (url.isEmpty) return '';

  final sourceUrl = sourceUrlHint ?? '';
  if (sourceUrl.isEmpty) return '';

  try {
    final source = sourceRepo.getSourceByUrl(sourceUrl);
    if (source == null) return '';
    return await ruleEngine.getContent(source, url);
  } catch (e) {
    debugPrint('[coordinator] fetchContent error: $e');
    return '';
  }
}

/// 计算分页布局并跳转到指定章节/进度。
///
/// 由于依赖 RenderBox 尺寸，[contentSize] 为 null 时表示尚未 layout，
/// 由调用方在下一帧重试。
void paginateAndJumpReaderPages({
  required PageFactory pageFactory,
  required Size? contentSize,
  required SettingsState settings,
  required ChapterState chapter,
  required int chapterIndex,
  required bool goToLastPage,
  required bool restoreOffset,
  double? targetProgress,
  required double Function() readChapterPageProgress,
}) {
  if (contentSize == null) return;

  final chapterDataList = List.generate(chapter.chapters.length, (i) {
    final ch = chapter.chapters[i];
    final content = (i == chapterIndex)
        ? chapter.currentContent
        : (ch.content ?? '');
    return ChapterData(title: ch.title, content: content);
  });
  pageFactory.setChapters(chapterDataList, chapterIndex);

  final s = settings.settings;
  final theme = settings.themeResolver;
  final contentW = contentSize.width - s.paddingLeft - s.paddingRight;
  final contentH = contentSize.height - s.paddingTop - s.paddingBottom;
  if (contentW > 50 && contentH > 100) {
    final titleFontSize = (s.fontSize + s.titleSize).clamp(10.0, 72.0);
    pageFactory.setLayoutParams(
      contentHeight: contentH,
      contentWidth: contentW,
      fontSize: s.fontSize,
      lineHeight: s.lineHeight,
      letterSpacing: s.letterSpacing,
      paragraphSpacing: s.paragraphSpacing,
      // 字体/字重/下划线/对齐方式/标题样式必须与渲染层 (ReaderContent.textStyle)
      // 完全一致，否则分页换行位置和渲染换行位置错位，会出现"翻页正文不连续、
      // 中间内容缺失"的现象。
      fontFamily: theme.fontFamily,
      fontFamilyFallback: theme.fontFamilyFallback,
      fontWeight: theme.fontWeight,
      underline: s.underline,
      paragraphIndent: s.paragraphIndent,
      textAlign: theme.bodyTextAlign,
      titleFontSize: titleFontSize.toDouble(),
      titleAlign: theme.titleTextAlign,
      titleTopSpacing: s.titleTopSpacing,
      titleBottomSpacing: s.titleBottomSpacing,
      showTitle: s.titleMode != 2,
      legacyImageStyle: settings.imageStyle,
    );
  }

  pageFactory.paginateAll();
  pageFactory.jumpToChapter(chapterIndex, goToLastPage: goToLastPage);

  if ((restoreOffset || targetProgress != null) && !goToLastPage) {
    final progress = targetProgress ?? readChapterPageProgress();
    final total = pageFactory.totalPages;
    if (total > 0) {
      final target = ChapterProgressUtils.pageIndexFromProgress(
        progress: progress,
        totalPages: total,
      );
      if (target != pageFactory.currentPageIndex) {
        pageFactory.jumpToPage(target);
      }
    }
  }
}

/// 根据章节内容估算滚动模式段高度。
double estimateScrollSegmentHeight(String content) {
  final lineCount = content.length / 30;
  return (lineCount * 20).clamp(100.0, 50000.0);
}

/// 异步预取前后各一章的正文（不抛错）。
Future<void> prefetchReaderNeighborChapters({
  required ChapterState chapter,
  required Future<String> Function(Chapter) fetch,
  required int centerIndex,
}) async {
  for (final offset in [-1, 1]) {
    final idx = centerIndex + offset;
    if (idx < 0 || idx >= chapter.readableCount) continue;
    final ch = chapter.chapters[idx];
    if (ch.content != null && ch.content!.isNotEmpty) continue;
    try {
      await fetch(ch);
    } catch (_) {}
  }
}

/// 写回章节阅读进度到 [BookRepository]。
Future<void> saveReaderBookProgress({
  required BookRepository bookRepo,
  required String bookId,
  required int chapterIndex,
  required double chapterProgress,
}) async {
  try {
    await bookRepo.updateReadProgress(
      bookId,
      currentChapter: chapterIndex,
      readProgress: chapterProgress,
    );
  } catch (_) {}
}
