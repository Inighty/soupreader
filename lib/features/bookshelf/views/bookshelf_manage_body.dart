import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_manage_search_field.dart';
import '../models/book.dart';
import 'bookshelf_manage_widgets.dart';

/// 主体 Column：搜索栏 + 选择栏 + 列表 / 空态。
class BookshelfManageBody extends StatelessWidget {
  const BookshelfManageBody({
    super.key,
    required this.searchController,
    required this.selectedGroupTitle,
    required this.onSearchChanged,
    required this.filteredBooks,
    required this.allBooks,
    required this.selectedCount,
    required this.allVisibleSelected,
    required this.changingSource,
    required this.clearingCache,
    required this.updatingCanUpdate,
    required this.addingToGroup,
    required this.deletingSelection,
    required this.selectionBlocked,
    required this.openBookInfoByClickTitle,
    required this.selectedBookIds,
    required this.resolveSourceLabel,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBatchChangeSource,
    required this.onClearCache,
    required this.onDeleteSelection,
    required this.onEnableUpdate,
    required this.onDisableUpdate,
    required this.onAddToGroup,
    required this.onCheckSelectedInterval,
    required this.onToggleBookSelection,
    required this.onOpenBookInfo,
  });

  final TextEditingController searchController;
  final String selectedGroupTitle;
  final ValueChanged<String> onSearchChanged;
  final List<Book> filteredBooks;
  final List<Book> allBooks;
  final int selectedCount;
  final bool allVisibleSelected;
  final bool changingSource;
  final bool clearingCache;
  final bool updatingCanUpdate;
  final bool addingToGroup;
  final bool deletingSelection;
  final bool selectionBlocked;
  final bool openBookInfoByClickTitle;
  final Set<String> selectedBookIds;
  final String Function(Book book) resolveSourceLabel;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onBatchChangeSource;
  final VoidCallback? onClearCache;
  final VoidCallback? onDeleteSelection;
  final VoidCallback? onEnableUpdate;
  final VoidCallback? onDisableUpdate;
  final VoidCallback? onAddToGroup;
  final VoidCallback? onCheckSelectedInterval;
  final ValueChanged<String> onToggleBookSelection;
  final ValueChanged<Book> onOpenBookInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: AppManageSearchField.outerPadding,
          child: AppManageSearchField(
            controller: searchController,
            placeholder: '筛选 • $selectedGroupTitle',
            onChanged: onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: SelectionSummaryBar(
            selectedCount: selectedCount,
            totalCount: filteredBooks.length,
            allVisibleSelected: allVisibleSelected,
            changingSource: changingSource,
            clearingCache: clearingCache,
            updatingCanUpdate: updatingCanUpdate,
            addingToGroup: addingToGroup,
            onToggleSelectAll: onToggleSelectAll,
            onClearSelection: onClearSelection,
            onBatchChangeSource: onBatchChangeSource,
            onClearCache: onClearCache,
            onDeleteSelection: onDeleteSelection,
            onEnableUpdate: onEnableUpdate,
            onDisableUpdate: onDisableUpdate,
            onAddToGroup: onAddToGroup,
            onCheckSelectedInterval: onCheckSelectedInterval,
            deletingSelection: deletingSelection,
          ),
        ),
        Expanded(
          child: filteredBooks.isEmpty
              ? Center(
                  child: Text(
                    allBooks.isEmpty ? '书架暂无书籍' : '没有匹配的书籍',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filteredBooks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    return BookSelectionTile(
                      book: book,
                      selected: selectedBookIds.contains(book.id),
                      sourceLabel: resolveSourceLabel(book),
                      titleTapOpensDetail: openBookInfoByClickTitle,
                      onTitleTap: selectionBlocked
                          ? null
                          : openBookInfoByClickTitle
                              ? () => onOpenBookInfo(book)
                              : null,
                      onTap: selectionBlocked
                          ? null
                          : () => onToggleBookSelection(book.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 顶部「分组按钮 + 更多按钮」。
class BookshelfManageTopActions extends StatelessWidget {
  const BookshelfManageTopActions({
    super.key,
    required this.disableNavActions,
    required this.busy,
    required this.onShowGroupMenu,
    required this.onShowMoreMenu,
  });

  final bool disableNavActions;
  final bool busy;
  final VoidCallback onShowGroupMenu;
  final VoidCallback onShowMoreMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: disableNavActions ? null : onShowGroupMenu,
          child: const Icon(CupertinoIcons.square_grid_2x2, size: 22),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: disableNavActions ? null : onShowMoreMenu,
          child: busy
              ? const CupertinoActivityIndicator(radius: 8)
              : const Icon(CupertinoIcons.ellipsis_circle, size: 22),
        ),
      ],
    );
  }
}
