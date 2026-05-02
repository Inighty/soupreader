import 'legacy_justified_text.dart';

/// 一页的数据，包含文本内容和可选的预排版行缓存。
///
/// [precomposedLines] 不为 null 时表示纯文本页，绘制时可直接复用，
/// 跳过二次排版；为 null 时表示含图片页，走原有逻辑。
class PageData {
  final String text;
  final List<LegacyComposedLine>? precomposedLines;

  const PageData(this.text, {this.precomposedLines});

  /// 纯文本页（携带预排版行）
  const PageData.text(this.text, this.precomposedLines);

  /// 含图片页（无预排版行）
  const PageData.image(this.text) : precomposedLines = null;
}

/// 阅读器一帧上同时存在的三个页面槽位（上一页/当前页/下一页）。
enum PageRenderSlot { prev, current, next }

/// 当前页在书内的位置信息（章节、页索引、总页数、章节标题）。
class PageRenderPosition {
  final int chapterIndex;
  final int pageIndex;
  final int totalPages;
  final String chapterTitle;

  const PageRenderPosition({
    required this.chapterIndex,
    required this.pageIndex,
    required this.totalPages,
    required this.chapterTitle,
  });
}

/// 章节数据
class ChapterData {
  final String title;
  final String content;

  ChapterData({required this.title, required this.content});
}
