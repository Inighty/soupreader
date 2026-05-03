import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/entities/bookmark_entity.dart';

/// 阅读器目录的书签列表 Tab。
class ReaderCatalogBookmarkList extends StatelessWidget {
  const ReaderCatalogBookmarkList({
    super.key,
    required this.bookmarks,
    required this.searchQuery,
    required this.accent,
    required this.textStrong,
    required this.textSubtle,
    required this.lineColor,
    required this.onBookmarkSelected,
    required this.onDeleteBookmark,
    this.onEditBookmark,
  });

  final List<BookmarkEntity> bookmarks;
  final String searchQuery;
  final Color accent;
  final Color textStrong;
  final Color textSubtle;
  final Color lineColor;
  final ValueChanged<BookmarkEntity> onBookmarkSelected;
  final Future<void> Function(BookmarkEntity bookmark) onDeleteBookmark;
  final Future<void> Function(BookmarkEntity bookmark)? onEditBookmark;

  List<BookmarkEntity> get filtered {
    var list = bookmarks;
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((b) =>
              b.chapterTitle.toLowerCase().contains(q) ||
              b.content.toLowerCase().contains(q))
          .toList(growable: false);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    if (list.isEmpty) {
      return AppEmptyState(
        illustration: const AppEmptyPlanetIllustration(size: 82),
        title: searchQuery.trim().isNotEmpty ? '无匹配书签' : '暂无书签',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: list.length,
      separatorBuilder: (_, __) => Container(
        height: 0.5,
        color: lineColor,
      ),
      itemBuilder: (context, index) {
        final bookmark = list[index];
        return _buildBookmarkTile(context, bookmark);
      },
    );
  }

  Widget _buildBookmarkTile(BuildContext context, BookmarkEntity bookmark) {
    return Dismissible(
      key: ValueKey(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: CupertinoColors.destructiveRed
            .resolveFrom(context)
            .withValues(alpha: 0.18),
        child: Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.destructiveRed.resolveFrom(context),
          size: 20,
        ),
      ),
      confirmDismiss: (_) async => _confirmDelete(context, bookmark),
      onDismissed: (_) => onDeleteBookmark(bookmark),
      child: GestureDetector(
        onLongPress: onEditBookmark != null
            ? () => onEditBookmark!(bookmark)
            : null,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => onBookmarkSelected(bookmark),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark.chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bookmark.content.trim().isNotEmpty
                            ? bookmark.content.trim()
                            : '（无预览内容）',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_forward,
                  color: textSubtle,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    BookmarkEntity bookmark,
  ) async {
    return await showCupertinoBottomSheetDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('删除书签'),
            content: Text('\n确定删除该书签吗？\n\n${bookmark.chapterTitle}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
