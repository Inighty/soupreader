import '../models/book.dart';
import '../services/cache_download_task_service.dart';
import '../services/cache_export_task_service.dart';

/// 缓存/导出页用的旧版「书籍分组」枚举值。
class CacheBookGroupOption {
  final int id;
  final String title;
  final int order;

  const CacheBookGroupOption({
    required this.id,
    required this.title,
    required this.order,
  });
}

const int cacheGroupIdAll = -1;
const int cacheGroupIdLocal = -2;
const int cacheGroupIdAudio = -3;
const int cacheGroupIdNetNone = -4;
const int cacheGroupIdLocalNone = -5;
const int cacheGroupIdError = -11;

const List<CacheBookGroupOption> cacheLegacyBookGroups = <CacheBookGroupOption>[
  CacheBookGroupOption(id: cacheGroupIdAll, title: '全部', order: -10),
  CacheBookGroupOption(id: cacheGroupIdLocal, title: '本地', order: -9),
  CacheBookGroupOption(id: cacheGroupIdAudio, title: '音频', order: -8),
  CacheBookGroupOption(id: cacheGroupIdNetNone, title: '网络未分组', order: -7),
  CacheBookGroupOption(id: cacheGroupIdLocalNone, title: '本地未分组', order: -6),
  CacheBookGroupOption(id: cacheGroupIdError, title: '更新失败', order: -1),
];

String resolveCacheGroupTitle(int groupId) {
  for (final option in cacheLegacyBookGroups) {
    if (option.id == groupId) return option.title;
  }
  return '未分组';
}

List<Book> filterCacheBooksByGroup(List<Book> books, int groupId) {
  switch (groupId) {
    case cacheGroupIdAll:
      return List<Book>.from(books);
    case cacheGroupIdLocal:
      return books.where((book) => book.isLocal).toList(growable: false);
    case cacheGroupIdAudio:
    case cacheGroupIdError:
      // 当前模型未承载 legado 音频/更新失败类型位，先保持可选分组入口，列表回落空集。
      return const <Book>[];
    case cacheGroupIdNetNone:
      return books.where((book) => !book.isLocal).toList(growable: false);
    case cacheGroupIdLocalNone:
      return books.where((book) => book.isLocal).toList(growable: false);
    default:
      return const <Book>[];
  }
}

DateTime? _maxDateTime(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

void sortCacheBooksByRecentRead(List<Book> books) {
  books.sort((a, b) {
    final aTime = _maxDateTime(a.lastReadTime, a.addedTime);
    final bTime = _maxDateTime(b.lastReadTime, b.addedTime);
    final aMs = aTime?.millisecondsSinceEpoch ?? 0;
    final bMs = bTime?.millisecondsSinceEpoch ?? 0;
    return bMs.compareTo(aMs);
  });
}

String buildCacheDownloadSummaryMessage(CacheDownloadSummary summary) {
  final parts = <String>[
    '新增${summary.downloadedChapters}章',
    if (summary.skippedChapters > 0) '已缓存${summary.skippedChapters}章',
    if (summary.failedChapters > 0) '失败${summary.failedChapters}章',
  ];
  final prefix = summary.stoppedByUser ? '缓存已停止' : '缓存完成';
  return '$prefix（共${summary.requestedChapters}章）：${parts.join('，')}';
}

String buildCacheExportSummaryMessage(CacheExportSummary summary) {
  return '导出完成：成功${summary.exportedBooks}本，跳过${summary.skippedBooks}本，'
      '失败${summary.failedBooks}本，'
      '共导出${summary.exportedChapters}章\n目录：${summary.outputDirectory}';
}
