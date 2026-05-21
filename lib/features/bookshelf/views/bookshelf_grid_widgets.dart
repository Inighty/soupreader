// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_book_status_helpers.dart';
import 'bookshelf_navigation.dart';
import 'bookshelf_view.dart';

extension BookshelfGridWidgets on BookshelfViewState {
  Widget buildGridSliver(List<Object> displayItems) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridCrossAxisCount,
          childAspectRatio: 0.56,
          crossAxisSpacing: 2,
          mainAxisSpacing: 6,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = displayItems[index];
            if (item is BookshelfBookGroup) {
              return buildGroupGridCard(item);
            }
            if (item is Book) {
              return buildBookCard(item);
            }
            return const SizedBox.shrink();
          },
          childCount: displayItems.length,
        ),
      ),
    );
  }

  Widget buildGroupGridCard(BookshelfBookGroup group) {
    return GestureDetector(
      onTap: () => onGroupTap(group),
      onLongPress: () => onGroupLongPress(group),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppUiTokens.resolve(context).colors.card,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusControl),
                ),
                child: AppCoverImage(
                  urlOrPath: group.cover,
                  title: group.groupName,
                  author: '',
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: AppDesignTokens.radiusControl,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 12 * 1.25 * 2,
              child: Text(
                group.groupName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBookCard(Book book) {
    final unreadCount = settingsService.appSettings.bookshelfShowUnread
        ? unreadCountLikeLegado(book)
        : 0;
    final bookUpdating = isUpdating(book);

    return GestureDetector(
      onTap: () => openReader(book),
      onLongPress: () => onBookLongPress(book),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppUiTokens.resolve(context).colors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppCoverImage(
                        urlOrPath: book.coverUrl,
                        title: book.title,
                        author: book.author,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: AppDesignTokens.radiusControl,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: bookUpdating
                        ? buildGridLoadingBadge()
                        : buildGridUnreadBadge(unreadCount),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 12 * 1.25 * 2,
              child: Text(
                book.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildGridLoadingBadge() => const _BookshelfGridLoadingBadge();

  Widget buildGridUnreadBadge(int unreadCount) =>
      _BookshelfGridUnreadBadge(unreadCount: unreadCount);
}

class _BookshelfGridLoadingBadge extends StatelessWidget {
  const _BookshelfGridLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color:
            CupertinoColors.label.resolveFrom(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const CupertinoActivityIndicator(radius: 6),
    );
  }
}

class _BookshelfGridUnreadBadge extends StatelessWidget {
  final int unreadCount;

  const _BookshelfGridUnreadBadge({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return const SizedBox.shrink();
    final label = unreadCount > 99 ? '99+' : '$unreadCount';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
