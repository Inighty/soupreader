import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book_source.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/js_runtime.dart';
import '../../../core/services/settings_service.dart';
import '../../replace/models/replace_rule.dart';
import '../../replace/services/replace_rule_engine.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../source/services/source/cover_loader.dart';
import '../models/book.dart';
import 'cache_export_epub_writer.dart';
import 'cache_export_file_name_helpers.dart';
import 'cache_export_image_writer.dart';
import 'cache_export_models.dart';
import 'cache_export_settings_store.dart';
import 'cache_export_txt_writer.dart';

class CacheExportBookResult {
  final String bookId;
  final String bookTitle;
  final int exportedChapters;
  final String? outputPath;
  final String? note;

  const CacheExportBookResult({
    required this.bookId,
    required this.bookTitle,
    required this.exportedChapters,
    this.outputPath,
    this.note,
  });
}

class CacheExportSummary {
  final int requestedBooks;
  final int exportedBooks;
  final int skippedBooks;
  final int failedBooks;
  final int exportedChapters;
  final String outputDirectory;
  final List<CacheExportBookResult> bookResults;

  const CacheExportSummary({
    required this.requestedBooks,
    required this.exportedBooks,
    required this.skippedBooks,
    required this.failedBooks,
    required this.exportedChapters,
    required this.outputDirectory,
    required this.bookResults,
  });
}

/// 书架“缓存/导出”页导出任务（对齐 legado `book_cache/menu_export_all`）。
///
/// 大块逻辑已抽出：
/// - 设置读写：[CacheExportSettingsStore]
/// - 文件名/Hash：`cache_export_file_name_helpers.dart`
/// - EPUB 写出：`cache_export_epub_writer.dart`
/// - TXT 写出 + 编码：`cache_export_txt_writer.dart`
/// - 图片下载：`cache_export_image_writer.dart`
class CacheExportTaskService {
  static const String defaultExportCharset =
      CacheExportSettingsStore.defaultExportCharset;
  static const List<String> legacyExportCharsetOptions = <String>[
    'UTF-8',
    'GB2312',
    'GB18030',
    'GBK',
    'Unicode',
    'UTF-16',
    'UTF-16LE',
    'ASCII',
  ];
  static const int _legacyMaxParallelExportThreads = 9;

  final ChapterRepository _chapterRepo;
  final SourceRepository _sourceRepo;
  final SourceCoverLoader _sourceCoverLoader;
  final JsRuntime _jsRuntime;
  final SettingsService _settingsService;
  final ReplaceRuleService _replaceRuleService;
  final ReplaceRuleEngine _replaceRuleEngine;
  final CacheExportSettingsStore _settings;

  CacheExportTaskService({
    DatabaseService? database,
    ChapterRepository? chapterRepo,
    SourceRepository? sourceRepo,
    SourceCoverLoader? sourceCoverLoader,
    JsRuntime? jsRuntime,
    SettingsService? settingsService,
    ReplaceRuleService? replaceRuleService,
    ReplaceRuleEngine? replaceRuleEngine,
  }) : this._(
          database ?? DatabaseService(),
          chapterRepo: chapterRepo,
          sourceRepo: sourceRepo,
          sourceCoverLoader: sourceCoverLoader,
          jsRuntime: jsRuntime,
          settingsService: settingsService,
          replaceRuleService: replaceRuleService,
          replaceRuleEngine: replaceRuleEngine,
        );

  CacheExportTaskService._(
    DatabaseService database, {
    ChapterRepository? chapterRepo,
    SourceRepository? sourceRepo,
    SourceCoverLoader? sourceCoverLoader,
    JsRuntime? jsRuntime,
    SettingsService? settingsService,
    ReplaceRuleService? replaceRuleService,
    ReplaceRuleEngine? replaceRuleEngine,
  })  : _chapterRepo = chapterRepo ?? ChapterRepository(database),
        _sourceRepo = sourceRepo ?? SourceRepository(database),
        _sourceCoverLoader = sourceCoverLoader ?? SourceCoverLoader.instance,
        _jsRuntime = jsRuntime ?? createJsRuntime(),
        _settingsService = settingsService ?? SettingsService(),
        _replaceRuleService =
            replaceRuleService ?? ReplaceRuleService(database),
        _replaceRuleEngine = replaceRuleEngine ?? ReplaceRuleEngine(),
        _settings = CacheExportSettingsStore(database);

  // ── 设置读写：薄壳委托给 _settings ──
  String? getSavedExportDirectory() => _settings.getSavedExportDirectory();
  Future<void> saveExportDirectory(String path) =>
      _settings.saveExportDirectory(path);
  bool getEnableCustomExport() => _settings.getEnableCustomExport();
  Future<void> saveEnableCustomExport(bool v) =>
      _settings.saveEnableCustomExport(v);
  bool getExportToWebDav() => _settings.getExportToWebDav();
  Future<void> saveExportToWebDav(bool v) => _settings.saveExportToWebDav(v);
  bool getExportNoChapterName() => _settings.getExportNoChapterName();
  Future<void> saveExportNoChapterName(bool v) =>
      _settings.saveExportNoChapterName(v);
  bool getExportUseReplace() => _settings.getExportUseReplace();
  Future<void> saveExportUseReplace(bool v) =>
      _settings.saveExportUseReplace(v);
  bool getExportPictureFile() => _settings.getExportPictureFile();
  Future<void> saveExportPictureFile(bool v) =>
      _settings.saveExportPictureFile(v);
  bool getParallelExportBook() => _settings.getParallelExportBook();
  Future<void> saveParallelExportBook(bool v) =>
      _settings.saveParallelExportBook(v);
  String? getBookExportFileName() => _settings.getBookExportFileName();
  Future<void> saveBookExportFileName(String? v) =>
      _settings.saveBookExportFileName(v);
  int getExportTypeIndex() => _settings.getExportTypeIndex();
  String getExportTypeName() => _settings.getExportTypeName();
  List<String> getExportTypeOptions() => _settings.getExportTypeOptions();
  Future<void> saveExportTypeIndex(int index) =>
      _settings.saveExportTypeIndex(index);
  String getExportCharset() => _settings.getExportCharset();
  Future<void> saveExportCharset(String v) => _settings.saveExportCharset(v);

  Future<bool> isWritableDirectory(String directoryPath) async {
    final normalized = directoryPath.trim();
    if (normalized.isEmpty) return false;

    final dir = Directory(normalized);
    if (!await dir.exists()) return false;

    final probePath = p.join(
      normalized,
      '.soupreader_writable_${DateTime.now().millisecondsSinceEpoch}',
    );
    final probeFile = File(probePath);
    try {
      await probeFile.writeAsString('soupreader probe', flush: true);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        if (await probeFile.exists()) await probeFile.delete();
      } catch (_) {
        // noop
      }
    }
  }

  Future<CacheExportSummary> exportAllToDirectory(
    Iterable<Book> books,
    String directoryPath, {
    bool? exportPictureFile,
  }) async {
    final normalized = directoryPath.trim();
    if (normalized.isEmpty) {
      throw StateError('导出目录为空');
    }
    final requestedBooks = books.toList(growable: false);
    final bookResults = <CacheExportBookResult>[];

    var exportedBooks = 0;
    var skippedBooks = 0;
    var failedBooks = 0;
    var exportedChapters = 0;
    final exportNoChapterName = getExportNoChapterName();
    final enableExportPictures = exportPictureFile ?? getExportPictureFile();
    final parallelExportBook = getParallelExportBook();
    final exportUseReplace = getExportUseReplace();
    final exportType = getExportTypeName();
    final exportCharset = getExportCharset();
    final exportConcurrency = _resolveExportConcurrency(parallelExportBook);

    for (final book in requestedBooks) {
      final cachedChapters =
          _chapterRepo.getChaptersForBook(book.id).where((chapter) {
        final content = (chapter.content ?? '').trim();
        return chapter.isDownloaded && content.isNotEmpty;
      }).toList(growable: false);

      if (cachedChapters.isEmpty) {
        skippedBooks += 1;
        bookResults.add(
          CacheExportBookResult(
            bookId: book.id,
            bookTitle: book.title,
            exportedChapters: 0,
            note: '无已缓存章节，已跳过',
          ),
        );
        continue;
      }

      final replaceContext = _resolveReplaceContext(
        book,
        exportUseReplace: exportUseReplace,
      );
      try {
        final result = await _exportSingleBook(
          book: book,
          cachedChapters: cachedChapters,
          directoryPath: normalized,
          exportType: exportType,
          exportCharset: exportCharset,
          exportNoChapterName: exportNoChapterName,
          enableExportPictures: enableExportPictures,
          exportConcurrency: exportConcurrency,
          replaceContext: replaceContext,
        );
        exportedBooks += 1;
        exportedChapters += cachedChapters.length;
        bookResults.add(result);
      } catch (error, stackTrace) {
        failedBooks += 1;
        ExceptionLogService().record(
          node: 'bookshelf.cache.export_all.write_failed',
          message: '导出书籍失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'bookId': book.id,
            'bookTitle': book.title,
            'directoryPath': normalized,
            'exportType': exportType,
            'exportCharset': exportCharset,
            'exportPictureFile': enableExportPictures,
            'parallelExportBook': parallelExportBook,
            'exportUseReplace': exportUseReplace,
            'bookUseReplaceRule': replaceContext.bookUseReplaceRule,
            'effectiveReplaceRuleCount': replaceContext.rules.length,
          },
        );
        bookResults.add(
          CacheExportBookResult(
            bookId: book.id,
            bookTitle: book.title,
            exportedChapters: 0,
            note: '导出失败：$error',
          ),
        );
      }
    }

    return CacheExportSummary(
      requestedBooks: requestedBooks.length,
      exportedBooks: exportedBooks,
      skippedBooks: skippedBooks,
      failedBooks: failedBooks,
      exportedChapters: exportedChapters,
      outputDirectory: normalized,
      bookResults: bookResults,
    );
  }

  Future<CacheExportBookResult> _exportSingleBook({
    required Book book,
    required List<Chapter> cachedChapters,
    required String directoryPath,
    required String exportType,
    required String exportCharset,
    required bool exportNoChapterName,
    required bool enableExportPictures,
    required int exportConcurrency,
    required CacheBookExportReplaceContext replaceContext,
  }) async {
    if (exportType == 'epub') {
      final fileName = _buildExportFileName(book, suffix: 'epub');
      final outputPath = await _resolveUniqueOutputPath(
        directoryPath,
        fileName,
      );
      final bytes = await buildCacheExportEpubBytes(
        book: book,
        cachedChapters: cachedChapters,
        applyReplaceToTitle: (title) =>
            _applyReplaceToTitle(title, replaceContext: replaceContext),
        applyReplaceToContent: (content) =>
            _applyReplaceToContent(content, replaceContext: replaceContext),
      );
      await File(outputPath).writeAsBytes(bytes, flush: true);
      return CacheExportBookResult(
        bookId: book.id,
        bookTitle: book.title,
        exportedChapters: cachedChapters.length,
        outputPath: outputPath,
        note: '导出格式：epub',
      );
    }

    final fileName = _buildExportFileName(book, suffix: 'txt');
    final outputPath =
        await _resolveUniqueOutputPath(directoryPath, fileName);
    final payload = await buildCacheExportTxtPayload(
      book: book,
      cachedChapters: cachedChapters,
      includeChapterTitle: !exportNoChapterName,
      includeImages: enableExportPictures,
      concurrency: exportConcurrency,
      applyReplaceToTitle: (title) =>
          _applyReplaceToTitle(title, replaceContext: replaceContext),
      applyReplaceToContent: (content) =>
          _applyReplaceToContent(content, replaceContext: replaceContext),
    );
    final txtBytes = encodeTxtContentByCharset(
      payload.content,
      charset: exportCharset,
    );
    await File(outputPath).writeAsBytes(txtBytes, flush: true);
    final imageSummary = enableExportPictures
        ? await exportCacheTxtImages(
            book: book,
            refs: payload.imageRefs,
            outputDirectory: directoryPath,
            concurrency: exportConcurrency,
            source: _resolveSourceForBook(book),
            sourceCoverLoader: _sourceCoverLoader,
          )
        : const CacheImageExportSummary();
    return CacheExportBookResult(
      bookId: book.id,
      bookTitle: book.title,
      exportedChapters: cachedChapters.length,
      outputPath: outputPath,
      note: _buildExportNote(
        enableExportPictures: enableExportPictures,
        exportedImages: imageSummary.exportedCount,
        failedImages: imageSummary.failedCount,
      ),
    );
  }

  String _buildExportFileName(Book book, {required String suffix}) {
    return buildExportFileName(
      book: book,
      suffix: suffix,
      jsRule: getBookExportFileName(),
      jsRuntime: _jsRuntime,
    );
  }

  Future<String> _resolveUniqueOutputPath(
    String directoryPath,
    String fileName,
  ) async {
    final baseName = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = p.join(directoryPath, '$baseName$extension');
    var suffix = 1;
    while (await File(candidate).exists()) {
      suffix += 1;
      candidate = p.join(directoryPath, '$baseName($suffix)$extension');
    }
    return candidate;
  }

  int _resolveExportConcurrency(bool parallelExportBook) {
    return parallelExportBook ? _legacyMaxParallelExportThreads : 1;
  }

  CacheBookExportReplaceContext _resolveReplaceContext(
    Book book, {
    required bool exportUseReplace,
  }) {
    final bookUseReplaceRule = _settingsService.getBookUseReplaceRule(
      book.id,
      fallback: true,
    );
    final enabled = exportUseReplace && bookUseReplaceRule;
    if (!enabled) {
      return CacheBookExportReplaceContext(
        enabled: false,
        bookUseReplaceRule: bookUseReplaceRule,
        rules: const <ReplaceRule>[],
      );
    }
    final rules = _replaceRuleService.getEffectiveRules(
      bookName: book.title,
      sourceUrl: book.sourceUrl,
    );
    return CacheBookExportReplaceContext(
      enabled: true,
      bookUseReplaceRule: bookUseReplaceRule,
      rules: List<ReplaceRule>.unmodifiable(rules),
    );
  }

  Future<String> _applyReplaceToTitle(
    String title, {
    required CacheBookExportReplaceContext replaceContext,
  }) async {
    if (!replaceContext.enabled ||
        replaceContext.rules.isEmpty ||
        title.isEmpty) {
      return title;
    }
    return _replaceRuleEngine.applyToTitle(
      title,
      replaceContext.rules.cast<ReplaceRule>(),
    );
  }

  Future<String> _applyReplaceToContent(
    String content, {
    required CacheBookExportReplaceContext replaceContext,
  }) async {
    if (!replaceContext.enabled ||
        replaceContext.rules.isEmpty ||
        content.isEmpty) {
      return content;
    }
    return _replaceRuleEngine.applyToContent(
      content,
      replaceContext.rules.cast<ReplaceRule>(),
    );
  }

  String? _buildExportNote({
    required bool enableExportPictures,
    required int exportedImages,
    required int failedImages,
  }) {
    if (!enableExportPictures) return null;
    if (failedImages <= 0) return 'TXT 导出图片：$exportedImages 张';
    return 'TXT 导出图片：成功$exportedImages张，失败$failedImages张';
  }

  BookSource? _resolveSourceForBook(Book book) {
    final sourceUrl = (book.sourceUrl ?? '').trim();
    if (sourceUrl.isEmpty) return null;
    return _sourceRepo.getSourceByUrl(sourceUrl);
  }
}
