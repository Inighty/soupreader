import '../../../core/database/database_service.dart';
import '../../../core/services/exception_log_service.dart';

/// 远程书籍“已在书架”映射持久化：
/// - 记录 remoteUrl -> bookId，用于远程列表中判定“已在书架”并支持直接进入阅读；
/// - 当书籍被删除导致 bookId 不存在时，需要清理孤儿映射，避免误判。
class RemoteBooksShelfLinkStore {
  RemoteBooksShelfLinkStore({
    DatabaseService? database,
    ExceptionLogService? exceptionLogService,
  })  : _database = database ?? DatabaseService(),
        _exceptionLogService = exceptionLogService ?? ExceptionLogService();

  static const String _storageKey = 'remote_books.shelf_links_v1';

  final DatabaseService _database;
  final ExceptionLogService _exceptionLogService;

  /// 获取全部映射（remoteUrl -> bookId）。
  Map<String, String> getAllLinks() {
    try {
      final raw = _database.getSetting(
        _storageKey,
        defaultValue: const <String, dynamic>{},
      );
      if (raw is Map) {
        final out = <String, String>{};
        raw.forEach((key, value) {
          final remoteUrl = ('$key').trim();
          final bookId = (value?.toString() ?? '').trim();
          if (remoteUrl.isEmpty || bookId.isEmpty) return;
          out[remoteUrl] = bookId;
        });
        return out;
      }
      return const <String, String>{};
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.shelf_link_store.get_all.failed',
        message: '读取远程书籍书架映射失败',
        error: error,
        stackTrace: stackTrace,
      );
      return const <String, String>{};
    }
  }

  /// 通过 remoteUrl 查询已绑定的 bookId。
  String? getBookIdByRemoteUrl(String remoteUrl) {
    final key = _normalizeRemoteUrl(remoteUrl);
    if (key.isEmpty) return null;
    final links = getAllLinks();
    final bookId = (links[key] ?? '').trim();
    return bookId.isEmpty ? null : bookId;
  }

  /// 写入/更新 remoteUrl -> bookId 映射。
  Future<void> upsertLink({
    required String remoteUrl,
    required String bookId,
  }) async {
    final key = _normalizeRemoteUrl(remoteUrl);
    final normalizedBookId = bookId.trim();
    if (key.isEmpty || normalizedBookId.isEmpty) return;

    try {
      final links = getAllLinks();
      links[key] = normalizedBookId;
      await _database.putSetting(_storageKey, links);
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.shelf_link_store.upsert.failed',
        message: '保存远程书籍书架映射失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'remoteUrl': key,
          'bookId': normalizedBookId,
        },
      );
    }
  }

  /// 删除 remoteUrl 对应的映射（用于清理孤儿记录）。
  Future<void> removeLink(String remoteUrl) async {
    final key = _normalizeRemoteUrl(remoteUrl);
    if (key.isEmpty) return;

    try {
      final links = getAllLinks();
      if (!links.containsKey(key)) return;
      links.remove(key);
      await _database.putSetting(_storageKey, links);
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.shelf_link_store.remove.failed',
        message: '删除远程书籍书架映射失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'remoteUrl': key,
        },
      );
    }
  }

  /// 清理孤儿映射：当 bookId 不存在时移除 remoteUrl -> bookId。
  ///
  /// 返回移除数量；失败时返回 0（并记录日志）。
  Future<int> pruneOrphanLinks({
    required bool Function(String bookId) exists,
  }) async {
    try {
      final links = getAllLinks();
      if (links.isEmpty) return 0;
      final orphanUrls = <String>[];
      for (final entry in links.entries) {
        final bookId = entry.value.trim();
        if (bookId.isEmpty) {
          orphanUrls.add(entry.key);
          continue;
        }
        if (!exists(bookId)) {
          orphanUrls.add(entry.key);
        }
      }

      if (orphanUrls.isEmpty) return 0;
      for (final url in orphanUrls) {
        links.remove(url);
      }
      await _database.putSetting(_storageKey, links);
      return orphanUrls.length;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.shelf_link_store.prune.failed',
        message: '清理远程书籍书架孤儿映射失败',
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
}
