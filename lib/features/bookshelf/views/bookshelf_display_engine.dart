// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_group_store_engine.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfDisplayEngine on BookshelfViewState {
  bool get isStyle2Enabled {
    return settingsService.appSettings.bookshelfGroupStyle == 1;
  }

  List<Book> filterBooksByGroup(List<Book> books, int groupId) {
    switch (groupId) {
      case BookshelfBookGroup.idAll:
        return books;
      case BookshelfBookGroup.idLocal:
        return books.where((book) => book.isLocal).toList(growable: false);
      case BookshelfBookGroup.idAudio:
      case BookshelfBookGroup.idError:
        // 当前模型未承载 legado 音频/更新失败类型位，保持入口但回落空集。
        return const <Book>[];
      case BookshelfBookGroup.idNetNone:
        final customMask = resolveCustomGroupMask();
        return books.where((book) {
          if (book.isLocal) return false;
          final membership = bookGroupMembershipMap[book.id] ?? 0;
          return (membership & customMask) == 0;
        }).toList(growable: false);
      case BookshelfBookGroup.idLocalNone:
        final customMask = resolveCustomGroupMask();
        return books.where((book) {
          if (!book.isLocal) return false;
          final membership = bookGroupMembershipMap[book.id] ?? 0;
          return (membership & customMask) == 0;
        }).toList(growable: false);
      default:
        if (groupId == BookshelfBookGroup.longMinValue) {
          return books.where((book) {
            final membership = bookGroupMembershipMap[book.id] ?? 0;
            return membership == groupId;
          }).toList(growable: false);
        }
        if (groupId > 0) {
          return books.where((book) {
            final membership = bookGroupMembershipMap[book.id] ?? 0;
            return (membership & groupId) > 0;
          }).toList(growable: false);
        }
        return const <Book>[];
    }
  }

  List<BookshelfBookGroup> visibleGroupsForRoot() {
    final visible = bookGroups
        .where((group) => shouldShowGroupOnRoot(group))
        .toList(growable: false);
    visible.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
    return visible;
  }

  /// 与 legado style1 的 TabLayout 数据源一致：复用 `bookGroupDao.show` 语义。
  List<BookshelfBookGroup> visibleGroupsForStyle1() {
    final visible = visibleGroupsForRoot();
    if (visible.isNotEmpty) return visible;
    for (final group in bookGroups) {
      if (group.groupId == BookshelfBookGroup.idAll) {
        return <BookshelfBookGroup>[group];
      }
    }
    return const <BookshelfBookGroup>[];
  }

  int resolveStyle1SelectedTabIndex(List<BookshelfBookGroup> groups) {
    if (groups.isEmpty) return 0;
    return style1SelectedTabIndex.clamp(0, groups.length - 1);
  }

  BookshelfBookGroup? selectedStyle1GroupOrNull() {
    final groups = visibleGroupsForStyle1();
    if (groups.isEmpty) return null;
    return groups[resolveStyle1SelectedTabIndex(groups)];
  }

  /// 与 legado `bookGroupDao.show` 对齐：
  /// 根态只展示“可见且存在匹配书籍”的分组；`全部`分组始终展示。
  bool shouldShowGroupOnRoot(BookshelfBookGroup group) {
    if (!group.show) return false;
    if (group.groupId == BookshelfBookGroup.idAll) return true;
    return filterBooksByGroup(books, group.groupId).isNotEmpty;
  }

  int resolveSortIndexForCurrentGroup() {
    var sortIndex = settingsService.appSettings.bookshelfSortIndex;
    if (isStyle2Enabled) {
      if (selectedGroupId == BookshelfBookGroup.idRoot) {
        return sortIndex;
      }
      BookshelfBookGroup? selectedGroup;
      for (final group in bookGroups) {
        if (group.groupId == selectedGroupId) {
          selectedGroup = group;
          break;
        }
      }
      if (selectedGroup != null && selectedGroup.bookSort >= 0) {
        sortIndex = selectedGroup.bookSort;
      }
      return sortIndex;
    }
    // style1 每个分组也支持独立排序配置（与 legado BooksFragment 对齐）。
    final selectedStyle1Group = selectedStyle1GroupOrNull();
    if (selectedStyle1Group != null && selectedStyle1Group.bookSort >= 0) {
      sortIndex = selectedStyle1Group.bookSort;
    }
    return sortIndex;
  }

  List<Book> displayBooks() {
    final source = List<Book>.from(books);
    late final List<Book> grouped;
    if (isStyle2Enabled) {
      if (selectedGroupId == BookshelfBookGroup.idRoot) {
        // 与 legado flowRoot() 对齐：根态只展示未归入任何自定义分组的网络书。
        // 若「网络未分组」分组本身已显示（show=true），根态不再重复展示这些书。
        final netNoneGroup = bookGroups
            .where(
              (g) => g.groupId == BookshelfBookGroup.idNetNone,
            )
            .firstOrNull;
        final netNoneShown = netNoneGroup?.show ?? false;
        if (netNoneShown) {
          grouped = const <Book>[];
        } else {
          grouped = filterBooksByGroup(source, BookshelfBookGroup.idNetNone);
        }
      } else {
        grouped = filterBooksByGroup(source, selectedGroupId);
      }
    } else {
      final selectedStyle1Group = selectedStyle1GroupOrNull();
      grouped = selectedStyle1Group == null
          ? source
          : filterBooksByGroup(source, selectedStyle1Group.groupId);
    }
    final sorted = List<Book>.from(grouped);
    sortBookList(sorted, resolveSortIndexForCurrentGroup());
    return sorted;
  }

  List<Object> displayItems() {
    final books = displayBooks();
    // style2 根态（IdRoot）展示“分组卡 + 书籍列表”；子分组只展示书籍。
    if (!isStyle2Enabled || selectedGroupId != BookshelfBookGroup.idRoot) {
      return books;
    }
    final groups = visibleGroupsForRoot();
    return <Object>[...groups, ...books];
  }

  String resolveGroupTitleById(int groupId) {
    for (final group in bookGroups) {
      if (group.groupId == groupId) {
        return group.groupName;
      }
    }
    switch (groupId) {
      case BookshelfBookGroup.idAll:
        return '全部';
      case BookshelfBookGroup.idLocal:
        return '本地';
      case BookshelfBookGroup.idAudio:
        return '音频';
      case BookshelfBookGroup.idNetNone:
        return '网络未分组';
      case BookshelfBookGroup.idLocalNone:
        return '本地未分组';
      case BookshelfBookGroup.idError:
        return '更新失败';
      default:
        return '未分组';
    }
  }

  String currentBookshelfTitle() {
    if (!isStyle2Enabled || selectedGroupId == BookshelfBookGroup.idRoot) {
      return '书架';
    }
    return '书架(${resolveGroupTitleById(selectedGroupId)})';
  }

  bool tryHandleStyle2Back() {
    if (!isStyle2Enabled) return false;
    if (selectedGroupId == BookshelfBookGroup.idRoot) return false;
    debugPrint('[bookshelf] style2 back to root from group=$selectedGroupId');
    setState(() => selectedGroupId = BookshelfBookGroup.idRoot);
    return true;
  }
}
