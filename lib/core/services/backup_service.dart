import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/book.dart';
import '../../features/replace/models/replace_rule.dart';
import '../../features/reader/models/reading_settings.dart';
import '../models/book_source.dart';
import '../database/database_service.dart';
import '../database/repositories/book_repository.dart';
import '../database/repositories/replace_rule_repository.dart';
import '../models/backup_restore_ignore_config.dart';
import '../database/repositories/source_repository.dart';
import 'backup_restore_ignore_service.dart';
import 'backup_service_legacy_parsers.dart';
import 'backup_service_models.dart';
import 'backup_service_serialization.dart';
import 'settings_service.dart';
import '../models/app_settings.dart';
import '../utils/file_picker_save_compat.dart';

export 'backup_service_models.dart';

/// 备份/恢复服务
///
/// 对标同类阅读器：
/// - 可以导出/导入“设置 + 书源 + 书架（含本地书籍内容）”
/// - 默认不备份在线书籍的章节缓存（体积巨大且可重新拉取）
class BackupService {
  static const int backupVersion = 1;

  final DatabaseService _db;
  final SettingsService _settingsService;
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;
  final SourceRepository _sourceRepo;
  final ReplaceRuleRepository _replaceRuleRepo;
  final BackupRestoreIgnoreService _backupRestoreIgnoreService;

  BackupService()
      : _db = DatabaseService(),
        _settingsService = SettingsService(),
        _bookRepo = BookRepository(DatabaseService()),
        _chapterRepo = ChapterRepository(DatabaseService()),
        _sourceRepo = SourceRepository(DatabaseService()),
        _replaceRuleRepo = ReplaceRuleRepository(DatabaseService()),
        _backupRestoreIgnoreService = BackupRestoreIgnoreService();

  BackupRestoreIgnoreConfig _resolveIgnoreConfig(
    BackupRestoreIgnoreConfig? override,
  ) {
    return override ?? _backupRestoreIgnoreService.load();
  }

  Future<BackupImportResult> importFromFileWithStoredIgnore({
    bool overwrite = false,
  }) async {
    final ignoreConfig = _backupRestoreIgnoreService.load();
    return importFromFile(
      overwrite: overwrite,
      ignoreConfig: ignoreConfig,
    );
  }

  Future<BackupImportResult> importFromBytesWithStoredIgnore(
    List<int> bytes, {
    bool overwrite = false,
  }) async {
    final ignoreConfig = _backupRestoreIgnoreService.load();
    return importFromBytes(
      bytes,
      overwrite: overwrite,
      ignoreConfig: ignoreConfig,
    );
  }

  Future<BackupExportResult> exportToFile({
    bool includeOnlineCache = false,
  }) async {
    try {
      final data = _buildBackupData(includeOnlineCache: includeOnlineCache);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出备份',
        fileName:
            'soupreader_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        allowedExtensions: const ['json'],
        text: jsonString,
      );

      if (outputPath == null) {
        return const BackupExportResult(cancelled: true);
      }
      return BackupExportResult(
        success: true,
        filePath: outputPath,
        fileName: p.basename(outputPath),
      );
    } catch (e) {
      debugPrint('备份导出失败: $e');
      return BackupExportResult(success: false, errorMessage: '$e');
    }
  }

  Future<BackupExportResult> exportToBackupPath({
    required String backupPath,
    required bool onlyLatestBackup,
    required String deviceName,
    bool includeOnlineCache = false,
  }) async {
    try {
      final normalizedPath = backupPath.trim();
      if (normalizedPath.isEmpty) {
        return const BackupExportResult(
          success: false,
          errorMessage: '备份路径为空',
        );
      }
      final outputDir = Directory(normalizedPath);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      final fileName = _buildBackupFileName(
        onlyLatestBackup: onlyLatestBackup,
        deviceName: deviceName,
      );
      final outputPath = p.join(outputDir.path, fileName);
      final data = _buildBackupData(includeOnlineCache: includeOnlineCache);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      await File(outputPath).writeAsString(jsonString);
      return BackupExportResult(
        success: true,
        filePath: outputPath,
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('备份导出失败: $e');
      return BackupExportResult(success: false, errorMessage: '$e');
    }
  }

  BackupUploadPayload buildUploadPayload({
    required bool onlyLatestBackup,
    required String deviceName,
    bool includeOnlineCache = false,
  }) {
    final fileName = _buildBackupFileName(
      onlyLatestBackup: onlyLatestBackup,
      deviceName: deviceName,
    );
    final data = _buildBackupData(includeOnlineCache: includeOnlineCache);
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    return BackupUploadPayload(
      fileName: fileName,
      bytes: utf8.encode(jsonString),
    );
  }

  Future<BackupImportResult> importFromFile({
    bool overwrite = false,
    BackupRestoreIgnoreConfig? ignoreConfig,
  }) async {
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
        allowMultiple: false,
      );
      if (pick == null || pick.files.isEmpty) {
        return const BackupImportResult(cancelled: true);
      }

      final file = pick.files.first;
      Uint8List bytes;

      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        return const BackupImportResult(
          success: false,
          errorMessage: '无法读取文件内容',
        );
      }
      return importFromBytes(
        bytes,
        overwrite: overwrite,
        ignoreConfig: ignoreConfig,
      );
    } catch (e) {
      debugPrint('备份导入失败: $e');
      return BackupImportResult(success: false, errorMessage: '$e');
    }
  }

  Future<BackupImportResult> importFromBytes(
    List<int> bytes, {
    bool overwrite = false,
    BackupRestoreIgnoreConfig? ignoreConfig,
  }) async {
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      return _importFromJsonText(
        content,
        overwrite: overwrite,
        ignoreConfig: ignoreConfig,
      );
    } catch (e) {
      debugPrint('备份导入失败: $e');
      return BackupImportResult(success: false, errorMessage: '$e');
    }
  }

  Future<BackupImportResult> _importFromJsonText(
    String content, {
    required bool overwrite,
    BackupRestoreIgnoreConfig? ignoreConfig,
  }) async {
    try {
      final raw = json.decode(content);
      if (raw is! Map) {
        return const BackupImportResult(
          success: false,
          errorMessage: '备份格式错误：根节点不是对象',
        );
      }

      final map = raw.map((k, v) => MapEntry('$k', v));
      final version = map['version'];
      if (version is! int || version != backupVersion) {
        return BackupImportResult(
          success: false,
          errorMessage: '备份版本不兼容：$version（当前支持 $backupVersion）',
        );
      }

      if (overwrite) {
        await _db.clearAll();
      }

      final restoredIgnore = _resolveIgnoreConfig(ignoreConfig);

      final settings = map['settings'];
      if (settings is Map) {
        final settingsMap = settings.map((k, v) => MapEntry('$k', v));
        final appSettings = settingsMap['appSettings'];
        final readingSettings = settingsMap['readingSettings'];

        AppSettings? importedAppSettings;
        if (appSettings is Map<String, dynamic>) {
          importedAppSettings = AppSettings.fromJson(appSettings);
        } else if (appSettings is Map) {
          importedAppSettings = AppSettings.fromJson(
              appSettings.map((k, v) => MapEntry('$k', v)));
        }

        if (importedAppSettings != null) {
          final merged = _mergeAppSettingsByIgnore(
            current: _settingsService.appSettings,
            incoming: importedAppSettings,
            ignoreConfig: restoredIgnore,
          );
          await _settingsService.saveAppSettings(merged);
        }

        if (!restoredIgnore.ignoreReadConfig) {
          if (readingSettings is Map<String, dynamic>) {
            await _settingsService.saveReadingSettings(
              ReadingSettings.fromJson(readingSettings),
            );
          } else if (readingSettings is Map) {
            await _settingsService.saveReadingSettings(
              ReadingSettings.fromJson(
                readingSettings.map((k, v) => MapEntry('$k', v)),
              ),
            );
          }
        }
      }

      var sourcesImported = 0;
      final sources = map['sources'];
      if (sources is List) {
        final sourceList = <BookSource>[];
        for (final item in sources) {
          if (item is Map<String, dynamic>) {
            sourceList.add(BookSource.fromJson(item));
          } else if (item is Map) {
            sourceList.add(
                BookSource.fromJson(item.map((k, v) => MapEntry('$k', v))));
          }
        }
        if (sourceList.isNotEmpty) {
          await _sourceRepo.addSources(sourceList);
          sourcesImported = sourceList.length;
        }
      }

      var booksImported = 0;
      final books = map['books'];
      final skippedLocalBookIds = <String>{};
      if (books is List) {
        for (final item in books) {
          Book? book;
          if (item is Map<String, dynamic>) {
            book = Book.fromJson(item);
          } else if (item is Map) {
            book = Book.fromJson(item.map((k, v) => MapEntry('$k', v)));
          }
          if (book != null) {
            if (restoredIgnore.ignoreLocalBook && book.isLocal) {
              skippedLocalBookIds.add(book.id);
              continue;
            }
            await _bookRepo.addBook(book);
            booksImported++;
          }
        }
      }

      var chaptersImported = 0;
      final chapters = map['chapters'];
      if (chapters is List) {
        final chapterList = <Chapter>[];
        for (final item in chapters) {
          Chapter? chapter;
          if (item is Map<String, dynamic>) {
            chapter = Chapter.fromJson(item);
          } else if (item is Map) {
            chapter = Chapter.fromJson(item.map((k, v) => MapEntry('$k', v)));
          }
          if (chapter == null) {
            continue;
          }
          if (restoredIgnore.ignoreLocalBook &&
              skippedLocalBookIds.contains(chapter.bookId)) {
            continue;
          }
          chapterList.add(chapter);
        }
        if (chapterList.isNotEmpty) {
          await _chapterRepo.addChapters(chapterList);
          chaptersImported = chapterList.length;
        }
      }

      return BackupImportResult(
        success: true,
        sourcesImported: sourcesImported,
        booksImported: booksImported,
        chaptersImported: chaptersImported,
        ignoredLocalBooks: skippedLocalBookIds.length,
        ignoredOptions: restoredIgnore.selectedTitles,
      );
    } catch (e) {
      debugPrint('备份导入失败: $e');
      return BackupImportResult(success: false, errorMessage: '$e');
    }
  }

  Future<LegacyImportResult> importOldVersionDirectory(
      String directoryPath) async {
    try {
      final rootPath = directoryPath.trim();
      if (rootPath.isEmpty) {
        return const LegacyImportResult(
          success: false,
          errorMessage: '目录路径为空',
        );
      }
      final root = Directory(rootPath);
      if (!await root.exists()) {
        return LegacyImportResult(
          success: false,
          errorMessage: '目录不存在：$rootPath',
        );
      }

      var booksImported = 0;
      var sourcesImported = 0;
      var replaceRulesImported = 0;

      final bookshelfFile = File(p.join(root.path, 'myBookShelf.json'));
      if (await bookshelfFile.exists()) {
        final decoded = json.decode(await bookshelfFile.readAsString());
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final book = _parseOldBook(item.map((k, v) => MapEntry('$k', v)));
            if (book == null) continue;
            await _bookRepo.addBook(book);
            booksImported++;
          }
        }
      }

      final sourceFile = File(p.join(root.path, 'myBookSource.json'));
      if (await sourceFile.exists()) {
        final decoded = json.decode(await sourceFile.readAsString());
        if (decoded is List) {
          final sourceList = <BookSource>[];
          for (final item in decoded) {
            if (item is! Map) continue;
            final source =
                _parseOldSource(item.map((k, v) => MapEntry('$k', v)));
            if (source == null) continue;
            sourceList.add(source);
          }
          if (sourceList.isNotEmpty) {
            await _sourceRepo.addSources(sourceList);
            sourcesImported = sourceList.length;
          }
        }
      }

      final replaceRuleFile = File(p.join(root.path, 'myBookReplaceRule.json'));
      if (await replaceRuleFile.exists()) {
        final decoded = json.decode(await replaceRuleFile.readAsString());
        if (decoded is List) {
          final rules = <ReplaceRule>[];
          for (var index = 0; index < decoded.length; index++) {
            final item = decoded[index];
            if (item is! Map) continue;
            final rule = _parseOldReplaceRule(
              item.map((k, v) => MapEntry('$k', v)),
              fallbackIdSeed: index,
            );
            if (rule == null) continue;
            rules.add(rule);
          }
          if (rules.isNotEmpty) {
            await _replaceRuleRepo.addRules(rules);
            replaceRulesImported = rules.length;
          }
        }
      }

      return LegacyImportResult(
        success: true,
        booksImported: booksImported,
        sourcesImported: sourcesImported,
        replaceRulesImported: replaceRulesImported,
      );
    } catch (e) {
      debugPrint('导入旧版数据失败: $e');
      return LegacyImportResult(
        success: false,
        errorMessage: '$e',
      );
    }
  }

  Book? _parseOldBook(Map<String, dynamic> map) =>
      parseLegacyBackupBook(map);

  BookSource? _parseOldSource(Map<String, dynamic> map) =>
      parseLegacyBackupSource(map);

  ReplaceRule? _parseOldReplaceRule(
    Map<String, dynamic> map, {
    required int fallbackIdSeed,
  }) =>
      parseLegacyBackupReplaceRule(map, fallbackIdSeed: fallbackIdSeed);

  AppSettings _mergeAppSettingsByIgnore({
    required AppSettings current,
    required AppSettings incoming,
    required BackupRestoreIgnoreConfig ignoreConfig,
  }) =>
      mergeAppSettingsByIgnore(
        current: current,
        incoming: incoming,
        ignoreConfig: ignoreConfig,
      );

  String _buildBackupFileName({
    required bool onlyLatestBackup,
    required String deviceName,
  }) =>
      buildBackupFileName(
        onlyLatestBackup: onlyLatestBackup,
        deviceName: deviceName,
      );

  Map<String, dynamic> _buildBackupData({required bool includeOnlineCache}) =>
      buildBackupData(
        includeOnlineCache: includeOnlineCache,
        settingsService: _settingsService,
        bookRepo: _bookRepo,
        chapterRepo: _chapterRepo,
        sourceRepo: _sourceRepo,
        replaceRuleRepo: _replaceRuleRepo,
      );
}

