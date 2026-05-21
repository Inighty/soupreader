// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_book_status_helpers.dart';
import 'bookshelf_navigation.dart';
import 'bookshelf_view.dart';

const int _bookshelfUnreadMaxLabelCount = 99;

extension BookshelfGridWidgets on BookshelfViewState {
  Widget buildGridSliver(List<Object> displayItems) {
    final uiTokens = AppUiTokens.resolve(context);
    return SliverPadding(
      padding: uiTokens.spacings.bookshelfGridPadding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridCrossAxisCount,
          childAspectRatio: 0.56,
          crossAxisSpacing: uiTokens.spacings.gridCrossAxisGap,
          mainAxisSpacing: uiTokens.spacings.gridMainAxisGap,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = displayItems[index];
            if (item is BookshelfBookGroup) {
              return buildGroupGridCard(item, uiTokens);
            }
            if (item is Book) {
              return buildBookCard(item, uiTokens);
            }
            return const SizedBox.shrink();
          },
          childCount: displayItems.length,
        ),
      ),
    );
  }

  Widget buildGroupGridCard(
    BookshelfBookGroup group,
    AppUiTokens uiTokens,
  ) {
    return Semantics(
      button: true,
      label: '打开分组 ${group.groupName}',
      hint: '双击进入分组，长按打开分组菜单',
      child: GestureDetector(
        onTap: () => onGroupTap(group),
        onLongPress: () => onGroupLongPress(group),
        child: Padding(
          padding: uiTokens.spacings.bookshelfGridItemPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildGroupCover(group, uiTokens)),
              SizedBox(height: uiTokens.spacings.cardGap - 2),
              _buildGridTitle(
                group.groupName,
                uiTokens: uiTokens,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBookCard(Book book, AppUiTokens uiTokens) {
    final unreadCount = settingsService.appSettings.bookshelfShowUnread
        ? unreadCountLikeLegado(book)
        : 0;
    final bookUpdating = isUpdating(book);

    return Semantics(
      button: true,
      label: '打开《${book.title}》',
      hint: '双击打开阅读，长按打开书籍菜单',
      child: GestureDetector(
        onTap: () => openReader(book),
        onLongPress: () => onBookLongPress(book),
        child: Padding(
          padding: uiTokens.spacings.bookshelfGridItemPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildBookCoverStack(
                  book: book,
                  uiTokens: uiTokens,
                  bookUpdating: bookUpdating,
                  unreadCount: unreadCount,
                ),
              ),
              SizedBox(height: uiTokens.spacings.cardGap - 2),
              _buildGridTitle(
                book.title,
                uiTokens: uiTokens,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGridLoadingBadge() => const _BookshelfGridLoadingBadge();

  Widget buildGridUnreadBadge(int unreadCount) =>
      _BookshelfGridUnreadBadge(unreadCount: unreadCount);

  Widget _buildGroupCover(
    BookshelfBookGroup group,
    AppUiTokens uiTokens,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: uiTokens.colors.card,
        borderRadius: BorderRadius.circular(uiTokens.radii.cover),
      ),
      child: AppCoverImage(
        urlOrPath: group.cover,
        title: group.groupName,
        author: '',
        width: double.infinity,
        height: double.infinity,
        borderRadius: uiTokens.radii.cover,
      ),
    );
  }

  Widget _buildBookCoverStack({
    required Book book,
    required AppUiTokens uiTokens,
    required bool bookUpdating,
    required int unreadCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _buildBookCover(book, uiTokens)),
        Positioned(
          top: -2,
          right: -2,
          child: bookUpdating
              ? buildGridLoadingBadge()
              : buildGridUnreadBadge(unreadCount),
        ),
      ],
    );
  }

  Widget _buildBookCover(Book book, AppUiTokens uiTokens) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: uiTokens.colors.card,
        borderRadius: BorderRadius.circular(uiTokens.radii.cover),
      ),
      child: AppCoverImage(
        urlOrPath: book.coverUrl,
        title: book.title,
        author: book.author,
        width: double.infinity,
        height: double.infinity,
        borderRadius: uiTokens.radii.cover,
      ),
    );
  }

  Widget _buildGridTitle(
    String text, {
    required AppUiTokens uiTokens,
    required FontWeight fontWeight,
  }) {
    return SizedBox(
      height: uiTokens.sizes.bookshelfTitleMaxHeight,
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: uiTokens.sizes.bookshelfTitleFontSize,
          height: uiTokens.sizes.bookshelfTitleLineHeight,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}

class _BookshelfGridLoadingBadge extends StatelessWidget {
  const _BookshelfGridLoadingBadge();

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color:
            CupertinoColors.label.resolveFrom(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(uiTokens.radii.badge + 2),
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
    final uiTokens = AppUiTokens.resolve(context);
    final label = unreadCount > _bookshelfUnreadMaxLabelCount
        ? '$_bookshelfUnreadMaxLabelCount+'
        : '$unreadCount';
    return Container(
      constraints: BoxConstraints(
        minWidth: uiTokens.sizes.badgeMinSize,
        minHeight: uiTokens.sizes.badgeMinSize,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(uiTokens.radii.badge),
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
