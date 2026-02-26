import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';

class MaintenanceActionResult {
  final bool success;
  final String message;
  final String? detail;

  const MaintenanceActionResult({
    required this.success,
    required this.message,
    this.detail,
  });
}

class OtherMaintenanceService {
  final DatabaseService _database;
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;

  OtherMaintenanceService({
    DatabaseService? database,
    BookRepository? bookRepository,
    ChapterRepository? chapterRepository,
  })  : _database = database ?? DatabaseService(),
        _bookRepo =
            bookRepository ?? BookRepository(database ?? DatabaseService()),
        _chapterRepo = chapterRepository ??
            ChapterRepository(database ?? DatabaseService());

  Future<MaintenanceActionResult> cleanCache() async {
    try {
      final localBookIds = _bookRepo
          .getAllBooks()
          .where((book) => book.isLocal)
          .map((book) => book.id)
          .toSet();
      final chapterResult =
          await _chapterRepo.clearDownloadedCache(protectBookIds: localBookIds);

      final cacheDirs = await _resolveCacheDirectories();
      var removedEntries = 0;
      for (final dir in cacheDirs) {
        removedEntries += await _clearDirectoryChildren(dir);
      }

      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.clear();
      imageCache.clearLiveImages();

      final hasChapterCleaned = chapterResult.chapters > 0;
      final hasDirectoryCleaned = removedEntries > 0;
      if (!hasChapterCleaned && !hasDirectoryCleaned) {
        return const MaintenanceActionResult(
          success: true,
          message: '没有可清理的缓存',
        );
      }

      final fragments = <String>[];
      if (hasChapterCleaned) {
        fragments.add(
          '章节缓存 ${_formatBytes(chapterResult.bytes)}（${chapterResult.chapters} 章）',
        );
      }
      if (hasDirectoryCleaned) {
        fragments.add('目录缓存 $removedEntries 项');
      }
      return MaintenanceActionResult(
        success: true,
        message: '已清理 ${fragments.join('，')}',
      );
    } catch (error) {
      return MaintenanceActionResult(
        success: false,
        message: '清理缓存失败',
        detail: '$error',
      );
    }
  }

  Future<MaintenanceActionResult> clearWebViewData() async {
    try {
      final cookiesCleared = await WebViewCookieManager().clearCookies();
      final webViewDirs = await _resolveWebViewDirectories();
      var removedDirs = 0;
      for (final dir in webViewDirs) {
        if (!await dir.exists()) continue;
        await dir.delete(recursive: true);
        removedDirs += 1;
      }

      final parts = <String>[];
      if (cookiesCleared) {
        parts.add('Cookie 已清除');
      }
      if (removedDirs > 0) {
        parts.add('已删除 $removedDirs 个 WebView 目录');
      }
      if (parts.isEmpty) {
        parts.add('未发现可清理的 WebView 数据');
      }
      return MaintenanceActionResult(
        success: true,
        message: parts.join('，'),
      );
    } catch (error) {
      return MaintenanceActionResult(
        success: false,
        message: '清除 WebView 数据失败',
        detail: '$error',
      );
    }
  }

  Future<MaintenanceActionResult> shrinkDatabase() async {
    try {
      await _database.driftDb.customStatement('VACUUM');
      return const MaintenanceActionResult(
        success: true,
        message: '数据库压缩完成',
      );
    } catch (error) {
      return MaintenanceActionResult(
        success: false,
        message: '压缩数据库失败',
        detail: '$error',
      );
    }
  }

  Future<Set<Directory>> _resolveCacheDirectories() async {
    final dirs = <Directory>{};
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      dirs.add(await getApplicationCacheDirectory());
    } catch (_) {}
    return dirs;
  }

  Future<Set<Directory>> _resolveWebViewDirectories() async {
    final dirs = <Directory>{};
    Directory? tempDir;
    Directory? supportDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {}
    try {
      supportDir = await getApplicationSupportDirectory();
    } catch (_) {}

    if (tempDir != null) {
      dirs.add(Directory(p.join(tempDir.path, 'webview')));
      dirs.add(Directory(p.join(tempDir.path, 'app_webview')));
    }
    if (supportDir != null) {
      dirs.add(Directory(p.join(supportDir.path, 'webview')));
      final appDataRoot = supportDir.parent;
      dirs.add(Directory(p.join(appDataRoot.path, 'app_webview')));
      dirs.add(Directory(p.join(appDataRoot.path, 'webview')));
      dirs.add(Directory(p.join(appDataRoot.path, 'hws_webview')));
    }
    return dirs;
  }

  Future<int> _clearDirectoryChildren(Directory directory) async {
    if (!await directory.exists()) return 0;
    var removed = 0;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        await entity.delete(recursive: true);
        removed += 1;
      }
    } catch (_) {
      rethrow;
    }
    return removed;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = <String>['KB', 'MB', 'GB'];
    var value = bytes / 1024;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : (value >= 10 ? 1 : 2))} ${units[unitIndex]}';
  }
}
