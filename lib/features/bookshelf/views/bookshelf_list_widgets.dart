// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_book_status_helpers.dart';
import 'bookshelf_navigation.dart';
import 'bookshelf_text_helpers.dart';
import 'bookshelf_view.dart';

extension BookshelfListWidgets on BookshelfViewState {
  BoxDecoration buildListCardDecoration(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return BoxDecoration(
      color: uiTokens.colors.card,
      borderRadius: BorderRadius.circular(uiTokens.radii.card),
    );
  }

  TextStyle buildListTitleStyle() {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.label.resolveFrom(context),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
  }

  TextStyle buildListMetaStyle() {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontSize: 12,
        );
  }

  Widget buildListSliver(List<Object> displayItems) {
    final theme = CupertinoTheme.of(context);
    final metaTextStyle = buildListMetaStyle();
    final titleTextStyle = buildListTitleStyle();
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    final showLastUpdateTime =
        settingsService.appSettings.bookshelfShowLastUpdateTime;
    final sliverItemCount =
        displayItems.isEmpty ? 0 : displayItems.length * 2 - 1;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) return const SizedBox(height: 8);
            final item = displayItems[index ~/ 2];
            if (item is BookshelfBookGroup) {
              return buildGroupListTile(item);
            }
            if (item is! Book) return const SizedBox.shrink();
            final book = item;
            final readAgo = formatReadAgo(book.lastReadTime);
            final bookUpdating = isUpdating(book);
            return GestureDetector(
              onTap: () => openReader(book),
              onLongPress: () => onBookLongPress(book),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: buildListCardDecoration(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCoverImage(
                      urlOrPath: book.coverUrl,
                      title: book.title,
                      author: book.author,
                      width: 66,
                      height: 90,
                      borderRadius: AppDesignTokens.radiusControl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: titleTextStyle,
                                ),
                              ),
                              if (book.isReading)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    book.progressText,
                                    style: metaTextStyle.copyWith(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.person,
                                size: 13,
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  book.author.trim().isEmpty
                                      ? '未知作者'
                                      : book.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                              ),
                              if (showLastUpdateTime && readAgo != null)
                                Text(
                                  readAgo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock,
                                size: 13,
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  buildReadLine(book),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.book,
                                size: 13,
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  buildLatestLine(book),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: bookUpdating
                          ? const CupertinoActivityIndicator(radius: 8)
                          : Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: secondaryLabel,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: sliverItemCount,
        ),
      ),
    );
  }

  Widget buildGroupListTile(BookshelfBookGroup group) {
    final metaTextStyle = buildListMetaStyle();
    final titleTextStyle = buildListTitleStyle();
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      onTap: () => onGroupTap(group),
      onLongPress: () => onGroupLongPress(group),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: buildListCardDecoration(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCoverImage(
              urlOrPath: group.cover,
              title: group.groupName,
              author: '',
              width: 66,
              height: 90,
              borderRadius: AppDesignTokens.radiusControl,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleTextStyle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '分组',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metaTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
