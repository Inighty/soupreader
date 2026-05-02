import '../database/repositories/book_repository.dart';
import '../database/repositories/replace_rule_repository.dart';
import '../database/repositories/source_repository.dart';
import '../models/app_settings.dart';
import '../models/backup_restore_ignore_config.dart';
import '../models/book.dart';
import 'settings_service.dart';

/// 当前备份格式版本号，写入 JSON 顶层 `version` 字段。
const int kBackupVersion = 1;

/// 把"当前 + 增量"的设置，按用户的忽略策略合并。
AppSettings mergeAppSettingsByIgnore({
  required AppSettings current,
  required AppSettings incoming,
  required BackupRestoreIgnoreConfig ignoreConfig,
}) {
  var merged = incoming.copyWith(
    backupPath: current.backupPath,
    webDavDeviceName: current.webDavDeviceName,
  );
  if (ignoreConfig.ignoreThemeMode) {
    merged = merged.copyWith(appearanceMode: current.appearanceMode);
  }
  if (ignoreConfig.ignoreBookshelfLayout) {
    merged = merged.copyWith(
      bookshelfViewMode: current.bookshelfViewMode,
      bookshelfLayoutIndex: current.bookshelfLayoutIndex,
    );
  }
  if (ignoreConfig.ignoreShowRss) {
    merged = merged.copyWith(showRss: current.showRss);
  }
  return merged;
}

/// 备份文件名规则：默认 `backup_YYYY-MM-DD[-deviceName].json`，
/// `onlyLatestBackup=true` 时固定为 `backup.json`（覆盖式备份）。
String buildBackupFileName({
  required bool onlyLatestBackup,
  required String deviceName,
}) {
  if (onlyLatestBackup) {
    return 'backup.json';
  }
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  var baseName = 'backup${now.year}-${two(now.month)}-${two(now.day)}';
  final normalizedDevice = _normalizeFileNameSegment(deviceName);
  if (normalizedDevice.isNotEmpty) {
    baseName = '$baseName-$normalizedDevice';
  }
  return '$baseName.json';
}

String _normalizeFileNameSegment(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final sanitized = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (sanitized.isEmpty) return '';
  return sanitized;
}

/// 序列化全部"设置 + 书源 + 书架（含本地书籍内容）"为可写出的 JSON 树。
Map<String, dynamic> buildBackupData({
  required bool includeOnlineCache,
  required SettingsService settingsService,
  required BookRepository bookRepo,
  required ChapterRepository chapterRepo,
  required SourceRepository sourceRepo,
  required ReplaceRuleRepository replaceRuleRepo,
}) {
  final books = bookRepo.getAllBooks();
  final sources = sourceRepo.getAllSources();

  final localBookIds = books.where((b) => b.isLocal).map((b) => b.id).toSet();
  final allChapters = <Chapter>[];
  for (final chapter in chapterRepo.getAllChapters()) {
    final isLocalBook = localBookIds.contains(chapter.bookId);
    if (!isLocalBook && !includeOnlineCache) continue;

    allChapters.add(
      Chapter(
        id: chapter.id,
        bookId: chapter.bookId,
        title: chapter.title,
        url: chapter.url,
        index: chapter.index,
        isDownloaded: chapter.isDownloaded,
        content: chapter.content,
      ),
    );
  }

  return {
    'version': kBackupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': {
      'appSettings': settingsService.appSettings.toJson(),
      'readingSettings': settingsService.readingSettings.toJson(),
    },
    'sources': sources.map((s) => s.toJson()).toList(),
    'books': books.map((b) => b.toJson()).toList(),
    'chapters': allChapters.map((c) => c.toJson()).toList(),
    'meta': {
      'includeOnlineCache': includeOnlineCache,
    },
  };
}
