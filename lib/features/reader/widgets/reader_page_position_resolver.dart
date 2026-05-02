import 'page_factory_models.dart';

/// 根据当前章节/页码上下文，计算 [PageRenderPosition]。
///
/// 抽出自 [PageFactory]，使主类聚焦于章节翻页与分页缓存管理。
class ReaderPagePositionResolver {
  final List<ChapterData> chapters;
  final int currentChapterIndex;
  final int currentPageIndex;
  final List<PageData> prevChapterPages;
  final List<PageData> currentChapterPages;
  final List<PageData> nextChapterPages;

  const ReaderPagePositionResolver({
    required this.chapters,
    required this.currentChapterIndex,
    required this.currentPageIndex,
    required this.prevChapterPages,
    required this.currentChapterPages,
    required this.nextChapterPages,
  });

  String get currentChapterTitle =>
      chapters.isNotEmpty && currentChapterIndex < chapters.length
          ? chapters[currentChapterIndex].title
          : '';

  PageRenderPosition resolveRenderPosition(PageRenderSlot slot) {
    switch (slot) {
      case PageRenderSlot.current:
        return _resolveCurrentRenderPosition();
      case PageRenderSlot.prev:
        return _resolvePrevRenderPosition();
      case PageRenderSlot.next:
        return _resolveNextRenderPosition();
    }
  }

  /// 双页模式：按逻辑页偏移量取 position（offset=1 为当前页的下一逻辑页）
  PageRenderPosition resolveRenderPositionByOffset(int offset) {
    final targetIndex = currentPageIndex + offset;
    if (targetIndex >= 0 && targetIndex < currentChapterPages.length) {
      final safeChapter = chapters.isEmpty
          ? 0
          : currentChapterIndex.clamp(0, chapters.length - 1);
      return PageRenderPosition(
        chapterIndex: safeChapter,
        pageIndex: targetIndex,
        totalPages: currentChapterPages.length,
        chapterTitle: currentChapterTitle,
      );
    }
    if (targetIndex < 0 && prevChapterPages.isNotEmpty) {
      final chapterIndex = chapters.isEmpty
          ? 0
          : (currentChapterIndex - 1).clamp(0, chapters.length - 1);
      final title = chapters.isNotEmpty
          ? chapters[chapterIndex].title
          : currentChapterTitle;
      final pageIndex = (prevChapterPages.length + targetIndex)
          .clamp(0, prevChapterPages.length - 1);
      return PageRenderPosition(
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
        totalPages: prevChapterPages.length,
        chapterTitle: title,
      );
    }
    if (targetIndex >= currentChapterPages.length &&
        nextChapterPages.isNotEmpty) {
      final chapterIndex = chapters.isEmpty
          ? 0
          : (currentChapterIndex + 1).clamp(0, chapters.length - 1);
      final title = chapters.isNotEmpty
          ? chapters[chapterIndex].title
          : currentChapterTitle;
      final pageIndex = (targetIndex - currentChapterPages.length)
          .clamp(0, nextChapterPages.length - 1);
      return PageRenderPosition(
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
        totalPages: nextChapterPages.length,
        chapterTitle: title,
      );
    }
    return _resolveCurrentRenderPosition();
  }

  PageRenderPosition _resolveCurrentRenderPosition() {
    final total = currentChapterPages.length;
    final safePage = total <= 0 ? 0 : currentPageIndex.clamp(0, total - 1);
    final safeChapter = chapters.isEmpty
        ? 0
        : currentChapterIndex.clamp(0, chapters.length - 1);
    return PageRenderPosition(
      chapterIndex: safeChapter,
      pageIndex: safePage,
      totalPages: total,
      chapterTitle: currentChapterTitle,
    );
  }

  PageRenderPosition _resolvePrevRenderPosition() {
    if (currentPageIndex > 0 && currentChapterPages.isNotEmpty) {
      final safeChapter = chapters.isEmpty
          ? 0
          : currentChapterIndex.clamp(0, chapters.length - 1);
      return PageRenderPosition(
        chapterIndex: safeChapter,
        pageIndex: currentPageIndex - 1,
        totalPages: currentChapterPages.length,
        chapterTitle: currentChapterTitle,
      );
    }

    if (prevChapterPages.isNotEmpty) {
      final chapterIndex = chapters.isEmpty
          ? 0
          : (currentChapterIndex - 1).clamp(0, chapters.length - 1);
      final title = chapters.isNotEmpty
          ? chapters[chapterIndex].title
          : currentChapterTitle;
      return PageRenderPosition(
        chapterIndex: chapterIndex,
        pageIndex: prevChapterPages.length - 1,
        totalPages: prevChapterPages.length,
        chapterTitle: title,
      );
    }

    return _resolveCurrentRenderPosition();
  }

  PageRenderPosition _resolveNextRenderPosition() {
    if (currentPageIndex < currentChapterPages.length - 1 &&
        currentChapterPages.isNotEmpty) {
      final safeChapter = chapters.isEmpty
          ? 0
          : currentChapterIndex.clamp(0, chapters.length - 1);
      return PageRenderPosition(
        chapterIndex: safeChapter,
        pageIndex: currentPageIndex + 1,
        totalPages: currentChapterPages.length,
        chapterTitle: currentChapterTitle,
      );
    }

    if (nextChapterPages.isNotEmpty) {
      final chapterIndex = chapters.isEmpty
          ? 0
          : (currentChapterIndex + 1).clamp(0, chapters.length - 1);
      final title = chapters.isNotEmpty
          ? chapters[chapterIndex].title
          : currentChapterTitle;
      return PageRenderPosition(
        chapterIndex: chapterIndex,
        pageIndex: 0,
        totalPages: nextChapterPages.length,
        chapterTitle: title,
      );
    }

    return _resolveCurrentRenderPosition();
  }
}
