// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../reader/views/reader_view.dart';
import '../../search/views/search_book_info_view.dart';
import '../../search/views/search_view.dart';
import '../../settings/views/app_log_dialog.dart';
import 'bookshelf_group_manage_placeholder_dialog.dart';
import 'bookshelf_group_switch_sheet.dart';
import 'bookshelf_manage_placeholder_view.dart';
import 'cache_export_placeholder_view.dart';
import 'remote_books_servers_view.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_display_engine.dart';
import 'bookshelf_group_store_engine.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfNavigation on BookshelfViewState {
  Future<void> openGlobalSearch() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SearchView(),
      ),
    );
    if (!mounted) return;
    loadBooks();
  }

  Future<void> openRemoteBook() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const RemoteBooksServersView(),
      ),
    );
    if (!mounted) return;
    loadBooks();
  }

  Future<void> openBookshelfManage() async {
    final groupId = selectedGroupId;
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => BookshelfManagePlaceholderView(
          initialGroupId: groupId,
        ),
      ),
    );
    if (!mounted) return;
    await reloadBookGroupContext(showError: true);
    loadBooks();
  }

  Future<void> openCacheExport() async {
    final groupId = selectedGroupId;
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => CacheExportPlaceholderView(
          initialGroupId: groupId,
        ),
      ),
    );
  }

  Future<void> openBookshelfGroupManageDialog() async {
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (_) => const BookshelfGroupManagePlaceholderDialog(),
    );
    if (!mounted) return;
    await reloadBookGroupContext(showError: true);
    loadBooks();
  }

  Future<void> openGroupSwitchSheet() async {
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (_) => BookshelfGroupSwitchSheet(
        groups: bookGroups,
        selectedGroupId: selectedGroupId,
        groupStore: bookGroupStore,
        onGroupSelected: (groupId) {
          setState(() => selectedGroupId = groupId);
          scrollToTop();
        },
        onGroupsChanged: () {
          unawaited(reloadBookGroupContext(showError: true));
          loadBooks();
        },
      ),
    );
  }

  Future<void> openAppLogDialog() async {
    await showAppLogDialog(context);
  }

  void onGroupTap(BookshelfBookGroup group) {
    if (!isStyle2Enabled) return;
    if (selectedGroupId == group.groupId) return;
    debugPrint(
      '[bookshelf] style2 enter group id=${group.groupId}, name=${group.groupName}',
    );
    setState(() => selectedGroupId = group.groupId);
    scrollToTop();
  }

  void onGroupLongPress(BookshelfBookGroup _) {
    if (!isStyle2Enabled) return;
    // 当前迁移阶段以“分组管理”作为分组编辑统一入口。
    openBookshelfGroupManageDialog();
  }

  void onStyle1GroupTap(int index, BookshelfBookGroup group) {
    final groups = visibleGroupsForStyle1();
    final currentIndex = resolveStyle1SelectedTabIndex(groups);
    if (index == currentIndex) {
      final count = filterBooksByGroup(books, group.groupId).length;
      debugPrint(
        '[bookshelf] style1 reselect group=${group.groupName} count=$count',
      );
      showBottomHint('${group.groupName}($count)');
      return;
    }
    debugPrint(
      '[bookshelf] style1 select tab index=$index group=${group.groupName}',
    );
    setState(() => style1SelectedTabIndex = index);
    scrollToTop();
    unawaited(persistStyle1SelectedTabIndex(index));
  }

  void onStyle1GroupLongPress(BookshelfBookGroup group) {
    debugPrint(
      '[bookshelf] style1 long press group id=${group.groupId} name=${group.groupName}',
    );
    // 当前迁移阶段以“分组管理”作为分组编辑统一入口。
    openBookshelfGroupManageDialog();
  }

  void openReader(Book book) {
    Navigator.of(context, rootNavigator: true)
        .push(
          CupertinoPageRoute(
            builder: (context) => ReaderView(
              bookId: book.id,
              bookTitle: book.title,
              initialChapter: book.currentChapter,
            ),
          ),
        )
        .then((_) => loadBooks()); // 返回时刷新列表
  }

  void onBookLongPress(Book book) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoActionSheet(
        title: Text(book.title),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('书籍详情'),
            onPressed: () {
              Navigator.pop(context);
              showBookInfo(book);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('移除书籍'),
            onPressed: () async {
              Navigator.pop(context);
              await bookRepo.deleteBook(book.id);
              loadBooks();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> showBookInfo(Book book) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    if (!mounted) return;
    loadBooks();
  }
}
