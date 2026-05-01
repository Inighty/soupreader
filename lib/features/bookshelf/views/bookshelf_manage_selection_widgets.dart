import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../models/book.dart';

class BookshelfManageSelectionSummaryBar extends StatelessWidget {
  const BookshelfManageSelectionSummaryBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.allVisibleSelected,
    required this.changingSource,
    required this.clearingCache,
    required this.updatingCanUpdate,
    required this.addingToGroup,
    required this.deletingSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBatchChangeSource,
    required this.onClearCache,
    required this.onEnableUpdate,
    required this.onDisableUpdate,
    required this.onAddToGroup,
    required this.onCheckSelectedInterval,
    required this.onDeleteSelection,
  });

  final int selectedCount;
  final int totalCount;
  final bool allVisibleSelected;
  final bool changingSource;
  final bool clearingCache;
  final bool updatingCanUpdate;
  final bool addingToGroup;
  final bool deletingSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onBatchChangeSource;
  final VoidCallback? onClearCache;
  final VoidCallback? onEnableUpdate;
  final VoidCallback? onDisableUpdate;
  final VoidCallback? onAddToGroup;
  final VoidCallback? onCheckSelectedInterval;
  final VoidCallback? onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final textColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已选 $selectedCount / $totalCount',
            style: TextStyle(
              fontSize: 13,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onToggleSelectAll,
                child: Text(allVisibleSelected ? '取消全选' : '全选'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onClearSelection,
                child: const Text('清空'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton.filled(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(28, 28),
                onPressed: onBatchChangeSource,
                child: changingSource
                    ? const CupertinoActivityIndicator()
                    : const Text('批量换源'),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onClearCache,
                child: clearingCache
                    ? const CupertinoActivityIndicator()
                    : const Text('清理缓存'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onDeleteSelection,
                child: deletingSelection
                    ? const CupertinoActivityIndicator()
                    : Text(
                        '删除',
                        style: TextStyle(
                          color: CupertinoColors.destructiveRed
                              .resolveFrom(context),
                        ),
                      ),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onEnableUpdate,
                child: updatingCanUpdate
                    ? const CupertinoActivityIndicator()
                    : const Text('允许更新'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onDisableUpdate,
                child: updatingCanUpdate
                    ? const CupertinoActivityIndicator()
                    : const Text('禁止更新'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onAddToGroup,
                child: addingToGroup
                    ? const CupertinoActivityIndicator()
                    : const Text('加入分组'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onCheckSelectedInterval,
                child: const Text('选中所选区间'),
                minimumSize: Size(28, 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BookshelfManageBookSelectionTile extends StatelessWidget {
  const BookshelfManageBookSelectionTile({
    super.key,
    required this.book,
    required this.selected,
    required this.sourceLabel,
    required this.titleTapOpensDetail,
    this.onTitleTap,
    this.onTap,
  });

  final Book book;
  final bool selected;
  final String sourceLabel;
  final bool titleTapOpensDetail;
  final VoidCallback? onTitleTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = CupertinoColors.activeBlue.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final bgColor = selected
        ? activeColor.withValues(alpha: 0.12)
        : CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final borderColor =
        selected ? activeColor.withValues(alpha: 0.45) : separator;
    final author = book.author.trim().isEmpty ? '未知作者' : book.author.trim();
    final titleText = Text(
      book.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选择圆圈
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 20,
                color: selected
                    ? activeColor
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 10),
            // 封面图（对齐 legado 66×90）
            AppCoverImage(
              urlOrPath: book.coverUrl,
              title: book.title,
              author: book.author,
              width: 48,
              height: 67,
              borderRadius: 6,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleTapOpensDetail && onTitleTap != null
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onTitleTap,
                          child: titleText,
                        )
                      : titleText,
                  const SizedBox(height: 3),
                  Text(
                    '$author · $sourceLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
