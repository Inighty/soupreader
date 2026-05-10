import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/settings_service.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';

const String bookshelfManageGroupMembershipKey = 'bookshelf.manage.book_group_membership';

const List<BookshelfBookGroup> bookshelfManageDefaultBookGroups =
    <BookshelfBookGroup>[
  BookshelfBookGroup(
    groupId: BookshelfBookGroup.idAll,
    groupName: '全部',
    show: true,
    order: -10,
    bookSort: -1,
    enableRefresh: true,
  ),
  BookshelfBookGroup(
    groupId: BookshelfBookGroup.idLocal,
    groupName: '本地',
    show: true,
    order: -9,
    bookSort: -1,
    enableRefresh: true,
  ),
  BookshelfBookGroup(
    groupId: BookshelfBookGroup.idAudio,
    groupName: '音频',
    show: true,
    order: -8,
    bookSort: -1,
    enableRefresh: true,
  ),
  BookshelfBookGroup(
    groupId: BookshelfBookGroup.idNetNone,
    groupName: '网络未分组',
    show: true,
    order: -7,
    bookSort: -1,
    enableRefresh: true,
  ),
  BookshelfBookGroup(
    groupId: BookshelfBookGroup.idLocalNone,
    groupName: '本地未分组',
    show: true,
    order: -6,
    bookSort: -1,
    enableRefresh: true,
  ),
  BookshelfBookGroup(
    groupId: BookshelfBookGroup.idError,
    groupName: '更新失败',
    show: true,
    order: -1,
    bookSort: -1,
    enableRefresh: true,
  ),
];

List<BookshelfBookGroup> normalizeBookshelfManageGroups(
  List<BookshelfBookGroup> groups,
) {
  final byId = <int, BookshelfBookGroup>{
    for (final group in groups) group.groupId: group,
  };
  for (final fallback in bookshelfManageDefaultBookGroups) {
    byId.putIfAbsent(fallback.groupId, () => fallback);
  }
  final normalized = byId.values.toList(growable: false);
  normalized.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    return a.groupId.compareTo(b.groupId);
  });
  return normalized;
}

Map<String, int> readBookshelfManageGroupMembershipMap(
  DatabaseService database,
) {
  final raw = database.getSetting(
    bookshelfManageGroupMembershipKey,
    defaultValue: const <String, dynamic>{},
  );
  if (raw is! Map) return const <String, int>{};
  final parsed = <String, int>{};
  raw.forEach((key, value) {
    final bookId = '$key'.trim();
    if (bookId.isEmpty) return;
    parsed[bookId] = _parseGroupBits(value);
  });
  return parsed;
}

int _parseGroupBits(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

String resolveBookshelfManageGroupTitleById(
  int groupId,
  List<BookshelfBookGroup> groups,
) {
  for (final group in groups) {
    if (group.groupId == groupId) return group.groupName;
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

int resolveBookshelfManageCustomGroupMask(List<BookshelfBookGroup> groups) {
  var mask = 0;
  for (final group in groups) {
    if (group.groupId > 0) mask |= group.groupId;
  }
  return mask;
}

List<Book> filterBookshelfManageBooksByGroup({
  required List<Book> books,
  required int groupId,
  required List<BookshelfBookGroup> groups,
  required Map<String, int> membership,
}) {
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
      final customMask = resolveBookshelfManageCustomGroupMask(groups);
      return books.where((book) {
        if (book.isLocal) return false;
        return ((membership[book.id] ?? 0) & customMask) == 0;
      }).toList(growable: false);
    case BookshelfBookGroup.idLocalNone:
      final customMask = resolveBookshelfManageCustomGroupMask(groups);
      return books.where((book) {
        if (!book.isLocal) return false;
        return ((membership[book.id] ?? 0) & customMask) == 0;
      }).toList(growable: false);
    default:
      if (groupId == BookshelfBookGroup.longMinValue) {
        return books.where((book) {
          return (membership[book.id] ?? 0) == groupId;
        }).toList(growable: false);
      }
      if (groupId > 0) {
        return books.where((book) {
          return ((membership[book.id] ?? 0) & groupId) > 0;
        }).toList(growable: false);
      }
      return const <Book>[];
  }
}

List<Book> sortBookshelfManageBooks({
  required List<Book> books,
  required SettingsService settingsService,
}) {
  final list = List<Book>.from(books);
  final sortIndex = settingsService.appSettings.bookshelfSortIndex;

  int compareDateTimeDesc(DateTime? a, DateTime? b) {
    final aTime = a ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  }

  DateTime? maxDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  final normalizedSort = sortIndex.clamp(0, 5);
  if (normalizedSort == 3) {
    // 手动排序依赖遗留 order 字段，当前模型未迁移该字段，保持数据库顺序。
    return list;
  }

  list.sort((a, b) {
    switch (normalizedSort) {
      case 0:
        return compareDateTimeDesc(
          a.lastReadTime ?? a.addedTime,
          b.lastReadTime ?? b.addedTime,
        );
      case 1:
        return compareDateTimeDesc(a.addedTime, b.addedTime);
      case 2:
        return a.title.compareTo(b.title);
      case 4:
        return compareDateTimeDesc(
          maxDate(a.lastReadTime, a.addedTime),
          maxDate(b.lastReadTime, b.addedTime),
        );
      case 5:
        return a.author.compareTo(b.author);
      default:
        return 0;
    }
  });

  return list;
}

String compactBookshelfManageReason(String text, {int maxLength = 120}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength)}…';
}

/// 解析单本书在书架管理列表中显示的「书源」标签。
String resolveBookshelfManageSourceDisplayName({
  required Book book,
  required SourceRepository sourceRepository,
}) {
  if (book.isLocal) return '本地书籍';
  final sourceUrl = (book.sourceUrl ?? book.sourceId ?? '').trim();
  if (sourceUrl.isEmpty) return '未知书源';
  final source = sourceRepository.getSourceByUrl(sourceUrl);
  if (source == null) return '未知书源';
  final group = (source.bookSourceGroup ?? '').trim();
  if (group.isEmpty) return source.bookSourceName;
  return '${source.bookSourceName} · $group';
}

/// 把 `_allBooks` 按当前分组 + 搜索关键字过滤一次，返回最终展示的书籍列表。
List<Book> filterBookshelfManageDisplayBooks({
  required List<Book> allBooks,
  required int selectedGroupId,
  required List<BookshelfBookGroup> groups,
  required Map<String, int> membership,
  required String searchText,
  required String Function(Book book) resolveSourceLabel,
}) {
  final groupedBooks = filterBookshelfManageBooksByGroup(
    books: allBooks,
    groupId: selectedGroupId,
    groups: groups,
    membership: membership,
  );
  final keyword = searchText.trim().toLowerCase();
  if (keyword.isEmpty) return groupedBooks;
  return groupedBooks.where((book) {
    final title = book.title.toLowerCase();
    final author = book.author.toLowerCase();
    final sourceName = resolveSourceLabel(book).toLowerCase();
    return title.contains(keyword) ||
        author.contains(keyword) ||
        sourceName.contains(keyword);
  }).toList(growable: false);
}

/// 「选中所选区间」：把当前可见列表中首次/最后一个被选中之间的所有书也加入选中集。
void checkBookshelfManageSelectedInterval({
  required List<Book> visibleBooks,
  required Set<String> selectedBookIds,
}) {
  if (visibleBooks.isEmpty) return;
  var firstSelected = -1;
  var lastSelected = -1;
  for (var i = 0; i < visibleBooks.length; i += 1) {
    if (selectedBookIds.contains(visibleBooks[i].id)) {
      if (firstSelected == -1) firstSelected = i;
      lastSelected = i;
    }
  }
  if (firstSelected == -1 || lastSelected == -1) return;
  for (var i = firstSelected; i <= lastSelected; i += 1) {
    selectedBookIds.add(visibleBooks[i].id);
  }
}
