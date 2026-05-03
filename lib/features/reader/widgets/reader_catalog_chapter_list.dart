import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../core/models/book.dart';

/// 阅读器目录章节列表。
///
/// 主要由 [chapters] / [currentChapterIndex] / [searchQuery] / [isReversed]
/// 等参数驱动；外部需要保留 [scrollController] 与 [chapterKeyFor]，以便
/// 自动滚动到当前章节。
class ReaderCatalogChapterList extends StatelessWidget {
  const ReaderCatalogChapterList({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.searchQuery,
    required this.isReversed,
    required this.loadWordCount,
    required this.scrollController,
    required this.chapterKeyFor,
    required this.displayTitleFor,
    required this.accent,
    required this.textStrong,
    required this.textSubtle,
    required this.lineColor,
    required this.cardMutedBg,
    required this.isDark,
    required this.onChapterSelected,
  });

  final List<Chapter> chapters;
  final int currentChapterIndex;
  final String searchQuery;
  final bool isReversed;
  final bool loadWordCount;
  final ScrollController scrollController;
  final GlobalKey Function(int chapterIndex) chapterKeyFor;
  final String Function(Chapter chapter) displayTitleFor;
  final Color accent;
  final Color textStrong;
  final Color textSubtle;
  final Color lineColor;
  final Color cardMutedBg;
  final bool isDark;
  final ValueChanged<int> onChapterSelected;

  static const double _chapterListItemExtent = 60;

  List<Chapter> get filtered {
    var list = chapters;
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((c) => c.title.toLowerCase().contains(q))
          .toList(growable: false);
    }
    if (isReversed) {
      list = list.reversed.toList(growable: false);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    if (list.isEmpty) {
      return AppEmptyState(
        illustration: const AppEmptyPlanetIllustration(size: 82),
        title: searchQuery.trim().isNotEmpty ? '无匹配章节' : '暂无章节',
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: list.length,
      separatorBuilder: (context, index) => Container(
        height: 0.5,
        margin: const EdgeInsets.only(left: 42),
        color: lineColor.withValues(alpha: 0.6),
      ),
      itemBuilder: (context, index) {
        final chapter = list[index];
        return _buildChapterTile(chapter);
      },
    );
  }

  Widget _buildChapterTile(Chapter chapter) {
    final originalIndex = chapter.index;
    final isCurrent = originalIndex == currentChapterIndex;
    final hasCache =
        chapter.isDownloaded && (chapter.content?.isNotEmpty ?? false);
    final wordCount = _wordCountLabel(chapter);

    return CupertinoButton(
      key: chapterKeyFor(originalIndex),
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => onChapterSelected(originalIndex),
      child: Container(
        constraints: const BoxConstraints(minHeight: _chapterListItemExtent),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: isCurrent
            ? BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.12 : 0.1),
                borderRadius:
                    BorderRadius.circular(AppDesignTokens.radiusControl),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${originalIndex + 1}',
                style: TextStyle(
                  color: isCurrent ? accent : textSubtle,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                displayTitleFor(chapter),
                style: TextStyle(
                  color: isCurrent ? accent : textStrong,
                  fontSize: 14,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (wordCount != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  wordCount,
                  style: TextStyle(color: textSubtle, fontSize: 11),
                ),
              ),
            if (hasCache)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cardMutedBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已缓存',
                    style: TextStyle(color: textSubtle, fontSize: 10),
                  ),
                ),
              ),
            if (isCurrent)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: accent,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  String? _wordCountLabel(Chapter chapter) {
    if (!loadWordCount) return null;
    final content = chapter.content;
    if (content == null || content.isEmpty) return null;
    final words = content.length;
    if (words <= 0) return null;
    if (words > 10000) {
      final value = (words / 10000.0)
          .toStringAsFixed(1)
          .replaceFirst(RegExp(r'\.0$'), '');
      return '$value万字';
    }
    return '$words字';
  }
}
