import '../../../core/database/database_service.dart';
import '../../../core/services/exception_log_service.dart';

/// 远程书籍“压缩包已导入/条目映射”持久化：
///
/// - 记录 remoteArchiveUrl -> (entryName -> bookId)；
/// - 用于：
///   1) 远程列表中判定压缩包“已在书架”（只要该压缩包曾导入过至少一本书）；
///   2) 点击压缩包后，选择内部条目可直接定位到已导入的 bookId 并开始阅读；
/// - 当书籍被删除导致 bookId 不存在时，需要清理孤儿映射，避免误判“已在书架”。
class RemoteBooksArchiveLinkStore {
  RemoteBooksArchiveLinkStore({
    DatabaseService? database,
    ExceptionLogService? exceptionLogService,
  })  : _database = database ?? DatabaseService(),
        _exceptionLogService = exceptionLogService ?? ExceptionLogService();

  static const String _storageKey = 'remote_books.archive_links_v1';

  final DatabaseService _database;
  final ExceptionLogService _exceptionLogService;

  /// 获取全部映射（remoteArchiveUrl -> entryName -> bookId）。
  Map<String, Map<String, String>> getAllLinks() {
    try {
      final raw = _database.getSetting(
        _storageKey,
        defaultValue: const <String, dynamic>{},
      );
      if (raw is! Map) return const <String, Map<String, String>>{};

      final out = <String, Map<String, String>>{};
      raw.forEach((archiveUrlRaw, entryMapRaw) {
        final archiveUrl = _normalizeRemoteUrl('$archiveUrlRaw');
        if (archiveUrl.isEmpty) return;

        if (entryMapRaw is! Map) return;
        final entryMap = <String, String>{};
        entryMapRaw.forEach((entryNameRaw, bookIdRaw) {
          final entryName = _normalizeEntryName('$entryNameRaw');
          final bookId = (bookIdRaw?.toString() ?? '').trim();
          if (entryName.isEmpty || bookId.isEmpty) return;
          entryMap[entryName] = bookId;
        });
        if (entryMap.isEmpty) return;
        out[archiveUrl] = entryMap;
      });

      return out;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive_link_store.get_all.failed',
        message: '读取远程书籍压缩包映射失败',
        error: error,
        stackTrace: stackTrace,
      );
      return const <String, Map<String, String>>{};
    }
  }

  /// 获取某个压缩包的全部条目映射（entryName -> bookId）。
  Map<String, String> getEntryLinksByArchiveUrl(String remoteArchiveUrl) {
    final key = _normalizeRemoteUrl(remoteArchiveUrl);
    if (key.isEmpty) return const <String, String>{};
    final all = getAllLinks();
    return all[key] ?? const <String, String>{};
  }

  /// 是否存在该压缩包的任何导入记录（用于判定“已在书架”）。
  bool hasArchiveImported(String remoteArchiveUrl) {
    final key = _normalizeRemoteUrl(remoteArchiveUrl);
    if (key.isEmpty) return false;
    final all = getAllLinks();
    final mapping = all[key];
    return mapping != null && mapping.isNotEmpty;
  }

  /// 获取某个压缩包内部条目的 bookId（若不存在则返回 null）。
  String? getBookIdByEntryName({
    required String remoteArchiveUrl,
    required String entryName,
  }) {
    final archiveKey = _normalizeRemoteUrl(remoteArchiveUrl);
    final entryKey = _normalizeEntryName(entryName);
    if (archiveKey.isEmpty || entryKey.isEmpty) return null;
    final all = getAllLinks();
    final mapping = all[archiveKey];
    if (mapping == null || mapping.isEmpty) return null;
    final bookId = (mapping[entryKey] ?? '').trim();
    return bookId.isEmpty ? null : bookId;
  }

  /// 写入/更新：remoteArchiveUrl + entryName -> bookId。
  Future<void> upsertEntryLink({
    required String remoteArchiveUrl,
    required String entryName,
    required String bookId,
  }) async {
    final archiveKey = _normalizeRemoteUrl(remoteArchiveUrl);
    final entryKey = _normalizeEntryName(entryName);
    final normalizedBookId = bookId.trim();
    if (archiveKey.isEmpty || entryKey.isEmpty || normalizedBookId.isEmpty) {
      return;
    }

    try {
      final all = getAllLinks();
      final nextEntryMap = <String, String>{...?(all[archiveKey])};
      nextEntryMap[entryKey] = normalizedBookId;
      all[archiveKey] = nextEntryMap;
      await _database.putSetting(_storageKey, all);
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive_link_store.upsert.failed',
        message: '保存远程书籍压缩包映射失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'remoteArchiveUrl': archiveKey,
          'entryName': entryKey,
          'bookId': normalizedBookId,
        },
      );
    }
  }

  /// 删除某个压缩包的所有映射。
  Future<void> removeArchive(String remoteArchiveUrl) async {
    final archiveKey = _normalizeRemoteUrl(remoteArchiveUrl);
    if (archiveKey.isEmpty) return;

    try {
      final all = getAllLinks();
      if (!all.containsKey(archiveKey)) return;
      all.remove(archiveKey);
      await _database.putSetting(_storageKey, all);
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive_link_store.remove_archive.failed',
        message: '删除远程书籍压缩包映射失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'remoteArchiveUrl': archiveKey,
        },
      );
    }
  }

  /// 清理孤儿映射：当 bookId 不存在时移除该条目；
  /// 若压缩包下已无任何条目，则移除该压缩包记录。
  ///
  /// 返回移除数量；失败时返回 0（并记录日志）。
  Future<int> pruneOrphanLinks({
    required bool Function(String bookId) exists,
  }) async {
    try {
      final all = getAllLinks();
      if (all.isEmpty) return 0;

      var removed = 0;
      final nextAll = <String, Map<String, String>>{};

      for (final archiveEntry in all.entries) {
        final archiveUrl = archiveEntry.key;
        final entryMap = archiveEntry.value;
        if (entryMap.isEmpty) continue;

        final nextEntryMap = <String, String>{};
        for (final entry in entryMap.entries) {
          final entryName = entry.key;
          final bookId = entry.value.trim();
          if (bookId.isEmpty || !exists(bookId)) {
            removed++;
            continue;
          }
          nextEntryMap[entryName] = bookId;
        }
        if (nextEntryMap.isNotEmpty) {
          nextAll[archiveUrl] = nextEntryMap;
        } else {
          // 该压缩包已无有效映射，整体移除。
          removed++;
        }
      }

      if (removed <= 0) return 0;
      await _database.putSetting(_storageKey, nextAll);
      return removed;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive_link_store.prune.failed',
        message: '清理远程书籍压缩包孤儿映射失败',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  String _normalizeRemoteUrl(String raw) {
    var url = raw.trim();
    while (url.length > 1 && url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String _normalizeEntryName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return '';
    // 压缩包内文件名按“忽略大小写”处理，避免不同平台大小写差异导致无法命中。
    return name.toLowerCase();
  }
}
