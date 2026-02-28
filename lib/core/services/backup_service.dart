import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../features/bookshelf/models/book.dart';
import '../../features/replace/models/replace_rule.dart';
import '../../features/reader/models/reading_settings.dart';
import '../../features/source/models/book_source.dart';
import '../database/database_service.dart';
import '../database/repositories/book_repository.dart';
import '../database/repositories/replace_rule_repository.dart';
import '../models/backup_restore_ignore_config.dart';
import '../database/repositories/source_repository.dart';
import 'backup_restore_ignore_service.dart';
import 'settings_service.dart';
import '../models/app_settings.dart';
import '../utils/file_picker_save_compat.dart';

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

  Book? _parseOldBook(Map<String, dynamic> map) {
    String readText(dynamic raw) {
      if (raw == null) return '';
      return raw.toString().trim();
    }

    int readInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    }

    double readDouble(dynamic raw) {
      if (raw is double) return raw;
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw.trim()) ?? 0.0;
      return 0.0;
    }

    DateTime? readDate(dynamic raw) {
      final ms = readInt(raw);
      if (ms <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }

    final infoRaw = map['bookInfoBean'];
    final info = infoRaw is Map
        ? infoRaw.map((k, v) => MapEntry('$k', v))
        : const <String, dynamic>{};

    var title = readText(map['title']);
    if (title.isEmpty) title = readText(info['name']);
    var author = readText(map['author']);
    if (author.isEmpty) author = readText(info['author']);
    final bookUrl = readText(map['bookUrl']).isNotEmpty
        ? readText(map['bookUrl'])
        : readText(map['noteUrl']);
    if (title.isEmpty && bookUrl.isEmpty) return null;
    final idCandidate = readText(map['id']);
    final resolvedId = idCandidate.isNotEmpty
        ? idCandidate
        : (bookUrl.isNotEmpty
            ? bookUrl
            : '${title}_${author}_${DateTime.now().millisecondsSinceEpoch}');
    final totalChapters = readInt(map['totalChapters']) > 0
        ? readInt(map['totalChapters'])
        : readInt(map['chapterListSize']);
    final currentChapter = readInt(map['currentChapter']) > 0
        ? readInt(map['currentChapter'])
        : readInt(map['durChapter']);

    final explicitProgress = readDouble(map['readProgress']);
    final readProgress = explicitProgress > 0
        ? explicitProgress.clamp(0.0, 1.0)
        : (totalChapters > 0 ? (currentChapter / totalChapters) : 0.0)
            .clamp(0.0, 1.0);

    final origin = readText(map['origin']);
    final isLocal = map['isLocal'] == true || origin == 'loc_book';
    final coverUrl = readText(map['coverUrl']).isNotEmpty
        ? readText(map['coverUrl'])
        : readText(info['coverUrl']);
    final latestChapter = readText(map['latestChapter']).isNotEmpty
        ? readText(map['latestChapter'])
        : readText(map['lastChapterName']);
    final intro = readText(map['intro']).isNotEmpty
        ? readText(map['intro'])
        : readText(info['introduce']);

    return Book(
      id: resolvedId,
      title: title.isEmpty ? '未命名书籍' : title,
      author: author.isEmpty ? '未知' : author,
      coverUrl: coverUrl.isEmpty ? null : coverUrl,
      intro: intro.isEmpty ? null : intro,
      sourceUrl: readText(map['sourceUrl']).isEmpty
          ? null
          : readText(map['sourceUrl']),
      bookUrl: bookUrl.isEmpty ? null : bookUrl,
      latestChapter: latestChapter.isEmpty ? null : latestChapter,
      totalChapters: totalChapters < 0 ? 0 : totalChapters,
      currentChapter: currentChapter < 0 ? 0 : currentChapter,
      readProgress: readProgress,
      lastReadTime:
          readDate(map['lastReadTime']) ?? readDate(map['durChapterTime']),
      addedTime: readDate(map['addedTime']) ?? readDate(map['finalDate']),
      isLocal: isLocal,
      localPath: readText(map['localPath']).isEmpty
          ? null
          : readText(map['localPath']),
    );
  }

  BookSource? _parseOldSource(Map<String, dynamic> map) {
    try {
      final source = BookSource.fromJson(map);
      if (source.bookSourceUrl.trim().isEmpty) {
        return null;
      }
      return source;
    } catch (_) {
      return null;
    }
  }

  ReplaceRule? _parseOldReplaceRule(
    Map<String, dynamic> map, {
    required int fallbackIdSeed,
  }) {
    try {
      final withId = Map<String, dynamic>.from(map);
      final rawId = withId['id'];
      final hasValidId = rawId is num ||
          (rawId is String && int.tryParse(rawId.trim()) != null);
      if (!hasValidId) {
        withId['id'] = DateTime.now().millisecondsSinceEpoch + fallbackIdSeed;
      }
      return ReplaceRule.fromJson(withId);
    } catch (_) {
      return null;
    }
  }

  AppSettings _mergeAppSettingsByIgnore({
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

  String _buildBackupFileName({
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

  Map<String, dynamic> _buildBackupData({required bool includeOnlineCache}) {
    final books = _bookRepo.getAllBooks();
    final sources = _sourceRepo.getAllSources();

    final localBookIds = books.where((b) => b.isLocal).map((b) => b.id).toSet();
    final allChapters = <Chapter>[];
    for (final chapter in _chapterRepo.getAllChapters()) {
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
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'appSettings': _settingsService.appSettings.toJson(),
        'readingSettings': _settingsService.readingSettings.toJson(),
      },
      'sources': sources.map((s) => s.toJson()).toList(),
      'books': books.map((b) => b.toJson()).toList(),
      'chapters': allChapters.map((c) => c.toJson()).toList(),
      'meta': {
        'includeOnlineCache': includeOnlineCache,
      },
    };
  }
}

class BackupExportResult {
  final bool success;
  final bool cancelled;
  final String? filePath;
  final String? fileName;
  final String? errorMessage;

  const BackupExportResult({
    this.success = false,
    this.cancelled = false,
    this.filePath,
    this.fileName,
    this.errorMessage,
  });
}

class BackupUploadPayload {
  final String fileName;
  final List<int> bytes;

  const BackupUploadPayload({
    required this.fileName,
    required this.bytes,
  });
}

class BackupImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final int sourcesImported;
  final int booksImported;
  final int chaptersImported;
  final int ignoredLocalBooks;
  final List<String> ignoredOptions;

  const BackupImportResult({
    this.success = false,
    this.cancelled = false,
    this.errorMessage,
    this.sourcesImported = 0,
    this.booksImported = 0,
    this.chaptersImported = 0,
    this.ignoredLocalBooks = 0,
    this.ignoredOptions = const <String>[],
  });
}

class LegacyImportResult {
  final bool success;
  final String? errorMessage;
  final int booksImported;
  final int sourcesImported;
  final int replaceRulesImported;

  const LegacyImportResult({
    this.success = false,
    this.errorMessage,
    this.booksImported = 0,
    this.sourcesImported = 0,
    this.replaceRulesImported = 0,
  });
}
