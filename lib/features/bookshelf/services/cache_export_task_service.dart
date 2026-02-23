import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epub;
import 'package:fast_gbk/fast_gbk.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/js_runtime.dart';
import '../../../core/services/settings_service.dart';
import '../../replace/models/replace_rule.dart';
import '../../replace/services/replace_rule_engine.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_cover_loader.dart';
import '../models/book.dart';

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
class CacheExportTaskService {
  static const String _exportDirectorySettingKey =
      'bookshelf.cache.export_directory';
  static const String _enableCustomExportSettingKey = 'enableCustomExport';
  static const String _exportToWebDavSettingKey = 'webDavCacheBackup';
  static const String _exportNoChapterNameSettingKey = 'exportNoChapterName';
  static const String _exportUseReplaceSettingKey = 'exportUseReplace';
  static const String _exportPictureFileSettingKey = 'exportPictureFile';
  static const String _parallelExportBookSettingKey = 'parallelExportBook';
  static const String _bookExportFileNameSettingKey = 'bookExportFileName';
  static const String _exportTypeSettingKey = 'exportType';
  static const String _exportCharsetSettingKey = 'exportCharset';
  static const List<String> _legacyExportTypes = <String>['txt', 'epub'];
  static const String defaultExportCharset = 'UTF-8';
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
  static const String _exportFileNameEvalErrorPrefix =
      '__SOUP_EXPORT_FILE_NAME_EVAL_ERROR__';
  static final RegExp _imgSrcPattern = RegExp(
    r'''<img[^>]*\bsrc\s*=\s*["']?([^"'>\s]+)["']?[^>]*>''',
    caseSensitive: false,
  );

  final DatabaseService _database;
  final ChapterRepository _chapterRepo;
  final SourceRepository _sourceRepo;
  final SourceCoverLoader _sourceCoverLoader;
  final JsRuntime _jsRuntime;
  final SettingsService _settingsService;
  final ReplaceRuleService _replaceRuleService;
  final ReplaceRuleEngine _replaceRuleEngine;

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
  })  : _database = database,
        _chapterRepo = chapterRepo ?? ChapterRepository(database),
        _sourceRepo = sourceRepo ?? SourceRepository(database),
        _sourceCoverLoader = sourceCoverLoader ?? SourceCoverLoader.instance,
        _jsRuntime = jsRuntime ?? createJsRuntime(),
        _settingsService = settingsService ?? SettingsService(),
        _replaceRuleService =
            replaceRuleService ?? ReplaceRuleService(database),
        _replaceRuleEngine = replaceRuleEngine ?? ReplaceRuleEngine();

  String? getSavedExportDirectory() {
    final raw = _database.getSetting(
      _exportDirectorySettingKey,
      defaultValue: null,
    );
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveExportDirectory(String directoryPath) async {
    final normalized = directoryPath.trim();
    if (normalized.isEmpty) return;
    await _database.putSetting(_exportDirectorySettingKey, normalized);
  }

  bool getEnableCustomExport() {
    final raw = _database.getSetting(
      _enableCustomExportSettingKey,
      defaultValue: false,
    );
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return false;
  }

  Future<void> saveEnableCustomExport(bool enabled) async {
    await _database.putSetting(_enableCustomExportSettingKey, enabled);
  }

  bool getExportToWebDav() {
    final raw = _database.getSetting(
      _exportToWebDavSettingKey,
      defaultValue: false,
    );
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return false;
  }

  Future<void> saveExportToWebDav(bool enabled) async {
    await _database.putSetting(_exportToWebDavSettingKey, enabled);
  }

  bool getExportNoChapterName() {
    final raw = _database.getSetting(
      _exportNoChapterNameSettingKey,
      defaultValue: false,
    );
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return false;
  }

  Future<void> saveExportNoChapterName(bool enabled) async {
    await _database.putSetting(_exportNoChapterNameSettingKey, enabled);
  }

  bool getExportUseReplace() {
    final raw = _database.getSetting(
      _exportUseReplaceSettingKey,
      defaultValue: true,
    );
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return true;
  }

  Future<void> saveExportUseReplace(bool enabled) async {
    await _database.putSetting(_exportUseReplaceSettingKey, enabled);
  }

  bool getExportPictureFile() {
    final raw = _database.getSetting(
      _exportPictureFileSettingKey,
      defaultValue: false,
    );
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return false;
  }

  Future<void> saveExportPictureFile(bool enabled) async {
    await _database.putSetting(_exportPictureFileSettingKey, enabled);
  }

  bool getParallelExportBook() {
    final raw = _database.getSetting(
      _parallelExportBookSettingKey,
      defaultValue: false,
    );
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return false;
  }

  Future<void> saveParallelExportBook(bool enabled) async {
    await _database.putSetting(_parallelExportBookSettingKey, enabled);
  }

  String? getBookExportFileName() {
    final raw = _database.getSetting(
      _bookExportFileNameSettingKey,
      defaultValue: null,
    );
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString();
  }

  Future<void> saveBookExportFileName(String? jsRule) async {
    await _database.putSetting(_bookExportFileNameSettingKey, jsRule);
  }

  int getExportTypeIndex() {
    final raw = _database.getSetting(
      _exportTypeSettingKey,
      defaultValue: 0,
    );
    if (raw is num) {
      return _normalizeExportTypeIndex(raw.toInt());
    }
    if (raw is bool) {
      return raw ? 1 : 0;
    }
    final text = raw?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) {
      return 0;
    }
    final numeric = int.tryParse(text);
    if (numeric != null) {
      return _normalizeExportTypeIndex(numeric);
    }
    final index = _legacyExportTypes.indexOf(text);
    if (index >= 0) {
      return index;
    }
    return 0;
  }

  String getExportTypeName() {
    return _legacyExportTypes[getExportTypeIndex()];
  }

  List<String> getExportTypeOptions() {
    return List<String>.unmodifiable(_legacyExportTypes);
  }

  Future<void> saveExportTypeIndex(int index) async {
    await _database.putSetting(
      _exportTypeSettingKey,
      _normalizeExportTypeIndex(index),
    );
  }

  String getExportCharset() {
    final raw = _database.getSetting(
      _exportCharsetSettingKey,
      defaultValue: null,
    );
    final value = raw?.toString() ?? '';
    if (value.trim().isEmpty) {
      return defaultExportCharset;
    }
    return value;
  }

  Future<void> saveExportCharset(String charset) async {
    await _database.putSetting(_exportCharsetSettingKey, charset);
  }

  Future<bool> isWritableDirectory(String directoryPath) async {
    final normalized = directoryPath.trim();
    if (normalized.isEmpty) return false;

    final dir = Directory(normalized);
    if (!await dir.exists()) return false;

    final probePath = p.join(
      normalized,
      '.soupreader_export_probe_${DateTime.now().millisecondsSinceEpoch}.tmp',
    );
    final probeFile = File(probePath);
    try {
      await probeFile.writeAsString('probe', flush: true);
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
      return true;
    } catch (_) {
      return false;
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
        late final String outputPath;
        String? note;
        if (exportType == 'epub') {
          final fileName = _buildExportFileName(book, suffix: 'epub');
          outputPath = await _resolveUniqueOutputPath(
            normalized,
            fileName,
          );
          final bytes = await _buildEpubBytes(
            book,
            cachedChapters,
            replaceContext: replaceContext,
          );
          await File(outputPath).writeAsBytes(bytes, flush: true);
          note = '导出格式：epub';
        } else {
          final fileName = _buildExportFileName(book, suffix: 'txt');
          outputPath = await _resolveUniqueOutputPath(
            normalized,
            fileName,
          );
          final payload = await _buildTxtPayload(
            book,
            cachedChapters,
            includeChapterTitle: !exportNoChapterName,
            includeImages: enableExportPictures,
            concurrency: exportConcurrency,
            replaceContext: replaceContext,
          );
          final txtBytes = _encodeTxtContentByCharset(
            payload.content,
            charset: exportCharset,
          );
          await File(outputPath).writeAsBytes(txtBytes, flush: true);
          final imageSummary = enableExportPictures
              ? await _exportTxtImages(
                  book: book,
                  refs: payload.imageRefs,
                  outputDirectory: normalized,
                  concurrency: exportConcurrency,
                )
              : const _ImageExportSummary();
          note = _buildExportNote(
            enableExportPictures: enableExportPictures,
            exportedImages: imageSummary.exportedCount,
            failedImages: imageSummary.failedCount,
          );
        }
        exportedBooks += 1;
        exportedChapters += cachedChapters.length;
        bookResults.add(
          CacheExportBookResult(
            bookId: book.id,
            bookTitle: book.title,
            exportedChapters: cachedChapters.length,
            outputPath: outputPath,
            note: note,
          ),
        );
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

  String _safeFileName(String raw) {
    final trimmed = raw.trim();
    final sanitized = trimmed
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitized.isEmpty) {
      return '未命名书籍';
    }
    if (sanitized.length <= 80) {
      return sanitized;
    }
    return sanitized.substring(0, 80);
  }

  String _buildExportFileName(
    Book book, {
    required String suffix,
  }) {
    final defaultName = _buildDefaultExportFileName(
      book,
      suffix: suffix,
    );
    final jsRule = getBookExportFileName();
    if (jsRule == null || jsRule.trim().isEmpty) {
      return defaultName;
    }
    final evalName = _evaluateExportFileNameRule(
      jsRule: jsRule,
      name: book.title,
      author: _normalizeAuthorForFileName(book.author),
    );
    if (evalName == null || evalName.trim().isEmpty) {
      return defaultName;
    }
    return '${_safeFileName(evalName)}.$suffix';
  }

  String _buildDefaultExportFileName(
    Book book, {
    required String suffix,
  }) {
    final author = _normalizeAuthorForFileName(book.author);
    final fileName = '${book.title} 作者：$author';
    return '${_safeFileName(fileName)}.$suffix';
  }

  String _normalizeAuthorForFileName(String author) {
    return author.trim();
  }

  int _normalizeExportTypeIndex(int index) {
    if (index < 0 || index >= _legacyExportTypes.length) {
      return 0;
    }
    return index;
  }

  Future<List<int>> _buildEpubBytes(
    Book book,
    List<Chapter> cachedChapters, {
    required _BookExportReplaceContext replaceContext,
  }) async {
    final title = book.title.trim().isEmpty ? '未命名书籍' : book.title.trim();
    final author = _normalizeAuthorForFileName(book.author).isEmpty
        ? '未知'
        : _normalizeAuthorForFileName(book.author);

    final content = epub.EpubContent();
    content.AllFiles!['Styles/main.css'] = epub.EpubTextContentFile()
      ..FileName = 'Styles/main.css'
      ..ContentType = epub.EpubContentType.CSS
      ..ContentMimeType = 'text/css'
      ..Content = _defaultEpubCss;

    final manifestItems = <epub.EpubManifestItem>[
      epub.EpubManifestItem()
        ..Id = 'ncx'
        ..Href = 'toc.ncx'
        ..MediaType = 'application/x-dtbncx+xml',
      epub.EpubManifestItem()
        ..Id = 'style'
        ..Href = 'Styles/main.css'
        ..MediaType = 'text/css',
    ];
    final spineItems = <epub.EpubSpineItemRef>[];
    final navPoints = <String>[];

    for (var i = 0; i < cachedChapters.length; i += 1) {
      final chapter = cachedChapters[i];
      final chapterNumber = i + 1;
      final chapterId = 'chapter_$chapterNumber';
      final chapterHref = 'Text/$chapterId.xhtml';
      final rawChapterTitle = chapter.title.trim().isEmpty
          ? '第$chapterNumber章'
          : chapter.title.trim();
      final chapterTitle = await _applyReplaceToTitle(
        rawChapterTitle,
        replaceContext: replaceContext,
      );
      final chapterContent = await _applyReplaceToContent(
        chapter.content ?? '',
        replaceContext: replaceContext,
      );
      manifestItems.add(
        epub.EpubManifestItem()
          ..Id = chapterId
          ..Href = chapterHref
          ..MediaType = 'application/xhtml+xml',
      );
      spineItems.add(
        epub.EpubSpineItemRef()
          ..IdRef = chapterId
          ..IsLinear = true,
      );
      navPoints.add(
        '<navPoint id="navPoint-$chapterNumber" playOrder="$chapterNumber">'
        '<navLabel><text>${_xmlEscapeText(chapterTitle)}</text></navLabel>'
        '<content src="${_xmlEscapeAttr(chapterHref)}" />'
        '</navPoint>',
      );
      content.AllFiles![chapterHref] = epub.EpubTextContentFile()
        ..FileName = chapterHref
        ..ContentType = epub.EpubContentType.XHTML_1_1
        ..ContentMimeType = 'application/xhtml+xml'
        ..Content = _buildEpubChapterDocument(
          title: chapterTitle,
          content: chapterContent,
        );
    }

    content.AllFiles!['toc.ncx'] = epub.EpubTextContentFile()
      ..FileName = 'toc.ncx'
      ..ContentType = epub.EpubContentType.DTBOOK_NCX
      ..ContentMimeType = 'application/x-dtbncx+xml'
      ..Content = _buildEpubTocNcx(
        title: title,
        navPoints: navPoints,
      );

    final metadata = epub.EpubMetadata()
      ..Titles = <String>[title]
      ..Creators = <epub.EpubMetadataCreator>[
        epub.EpubMetadataCreator()..Creator = author,
      ]
      ..Publishers = <String>['SoupReader']
      ..Languages = <String>['zh'];
    final intro = (book.intro ?? '').trim();
    if (intro.isNotEmpty) {
      metadata.Description = intro;
    }

    final package = epub.EpubPackage()
      ..Version = epub.EpubVersion.Epub2
      ..Metadata = metadata
      ..Manifest = (epub.EpubManifest()..Items = manifestItems)
      ..Spine = (epub.EpubSpine()
        ..TableOfContents = 'ncx'
        ..Items = spineItems)
      ..Guide = epub.EpubGuide();
    final schema = epub.EpubSchema()
      ..Package = package
      ..ContentDirectoryPath = 'OEBPS';

    final epubBook = epub.EpubBook()
      ..Title = title
      ..Author = author
      ..Schema = schema
      ..Content = content;
    final bytes = epub.EpubWriter.writeBook(epubBook);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Epub 文件生成失败');
    }
    return bytes;
  }

  String _buildEpubTocNcx({
    required String title,
    required List<String> navPoints,
  }) {
    final navPointText = navPoints.join('\n');
    return '''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="${_xmlEscapeAttr(title)}" />
    <meta name="dtb:depth" content="1" />
    <meta name="dtb:totalPageCount" content="0" />
    <meta name="dtb:maxPageNumber" content="0" />
  </head>
  <docTitle>
    <text>${_xmlEscapeText(title)}</text>
  </docTitle>
  <navMap>
$navPointText
  </navMap>
</ncx>
''';
  }

  String _buildEpubChapterDocument({
    required String title,
    required String content,
  }) {
    final lines = content.split('\n');
    final paragraphBuffer = StringBuffer();
    if (lines.isEmpty) {
      paragraphBuffer.writeln('    <p>&#160;</p>');
    } else {
      var hasVisibleContent = false;
      for (final line in lines) {
        final text = line.trimRight();
        if (text.isEmpty) {
          paragraphBuffer.writeln('    <p>&#160;</p>');
          continue;
        }
        hasVisibleContent = true;
        paragraphBuffer.writeln('    <p>${_xmlEscapeText(text)}</p>');
      }
      if (!hasVisibleContent) {
        paragraphBuffer.writeln('    <p>&#160;</p>');
      }
    }
    return '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="zh-CN">
  <head>
    <title>${_xmlEscapeText(title)}</title>
    <meta charset="utf-8" />
    <link rel="stylesheet" type="text/css" href="../Styles/main.css" />
  </head>
  <body>
    <h1>${_xmlEscapeText(title)}</h1>
${paragraphBuffer.toString()}  </body>
</html>
''';
  }

  String _xmlEscapeText(String raw) {
    return raw
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  String _xmlEscapeAttr(String raw) {
    return _xmlEscapeText(raw)
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static const String _defaultEpubCss = '''
body {
  margin: 0;
  padding: 1.2em;
  line-height: 1.8;
  font-size: 1em;
  color: #111;
  background: #fff;
  font-family: "Noto Serif SC", serif;
}
h1 {
  margin: 0 0 1em 0;
  font-size: 1.25em;
  line-height: 1.45;
}
p {
  margin: 0 0 0.8em 0;
  text-indent: 2em;
  white-space: pre-wrap;
  word-break: break-word;
}
''';

  String? _evaluateExportFileNameRule({
    required String jsRule,
    required String name,
    required String author,
  }) {
    final safeRule = jsonEncode(jsRule);
    final safeName = jsonEncode(name);
    final safeAuthor = jsonEncode(author);
    final script = '''
      (function() {
        try {
          var name = $safeName;
          var author = $safeAuthor;
          var epubIndex = "";
          var __res = eval($safeRule);
          if (__res === undefined || __res === null) return '';
          if (typeof __res === 'string') return __res;
          try { return JSON.stringify(__res); } catch(_jsonErr) { return String(__res); }
        } catch(e) {
          try {
            return "$_exportFileNameEvalErrorPrefix" + String(e && (e.stack || e.message || e));
          } catch(_e) {
            return "$_exportFileNameEvalErrorPrefix";
          }
        }
      })()
    ''';
    final output = _decodeMaybeJsonString(_jsRuntime.evaluate(script).trim());
    if (output.isEmpty) {
      return null;
    }
    if (output.startsWith(_exportFileNameEvalErrorPrefix)) {
      final error = output.substring(_exportFileNameEvalErrorPrefix.length);
      ExceptionLogService().record(
        node: 'bookshelf.cache.export_file_name.eval_failed',
        message: '导出文件名规则解析失败，已回退默认规则',
        error: error.isEmpty ? null : error,
        context: <String, dynamic>{
          'rule': jsRule,
          'bookName': name,
          'bookAuthor': author,
        },
      );
      return null;
    }
    return output;
  }

  String _decodeMaybeJsonString(String text) {
    final trimmed = text.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded.trim();
        }
      } catch (_) {
        // noop
      }
    }
    return trimmed;
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

  List<int> _encodeTxtContentByCharset(
    String content, {
    required String charset,
  }) {
    final normalized = _normalizeExportCharset(charset);
    switch (normalized.toUpperCase()) {
      case 'UTF-8':
        return utf8.encode(content);
      case 'GB2312':
      case 'GB18030':
      case 'GBK':
        return gbk.encode(content);
      case 'UNICODE':
      case 'UTF-16':
        return _encodeUtf16(
          content,
          littleEndian: false,
          includeBom: true,
        );
      case 'UTF-16LE':
        return _encodeUtf16(
          content,
          littleEndian: true,
          includeBom: false,
        );
      case 'ASCII':
        return const AsciiCodec(allowInvalid: true).encode(content);
      default:
        throw StateError('不支持的导出编码：$charset');
    }
  }

  String _normalizeExportCharset(String charset) {
    final value = charset.trim();
    if (value.isEmpty) {
      return defaultExportCharset;
    }
    final upper = value.toUpperCase().replaceAll('_', '-');
    switch (upper) {
      case 'UTF8':
      case 'UTF-8':
        return 'UTF-8';
      case 'GB2312':
        return 'GB2312';
      case 'GB18030':
        return 'GB18030';
      case 'GBK':
        return 'GBK';
      case 'UNICODE':
        return 'Unicode';
      case 'UTF16':
      case 'UTF-16':
        return 'UTF-16';
      case 'UTF16LE':
      case 'UTF-16LE':
        return 'UTF-16LE';
      case 'ASCII':
        return 'ASCII';
      default:
        return value;
    }
  }

  List<int> _encodeUtf16(
    String content, {
    required bool littleEndian,
    required bool includeBom,
  }) {
    final codeUnits = content.codeUnits;
    final totalLength = codeUnits.length * 2 + (includeBom ? 2 : 0);
    final data = ByteData(totalLength);
    final endian = littleEndian ? Endian.little : Endian.big;
    var offset = 0;
    if (includeBom) {
      data.setUint16(offset, 0xFEFF, endian);
      offset += 2;
    }
    for (final unit in codeUnits) {
      data.setUint16(offset, unit, endian);
      offset += 2;
    }
    return data.buffer.asUint8List();
  }

  Future<_TxtExportPayload> _buildTxtPayload(
    Book book,
    List<Chapter> cachedChapters, {
    required bool includeChapterTitle,
    required bool includeImages,
    required int concurrency,
    required _BookExportReplaceContext replaceContext,
  }) async {
    final chapterPayloads =
        await _mapWithConcurrencyOrdered<Chapter, _TxtChapterPayload>(
      items: cachedChapters,
      concurrency: concurrency,
      mapper: (chapter, _) async {
        final rawTitle = chapter.title.trim().isEmpty ? '未命名章节' : chapter.title;
        final title = await _applyReplaceToTitle(
          rawTitle,
          replaceContext: replaceContext,
        );
        final rawContent = (chapter.content ?? '').trim();
        final content = await _applyReplaceToContent(
          rawContent,
          replaceContext: replaceContext,
        );
        final buffer = StringBuffer();
        if (includeChapterTitle) {
          buffer.writeln(title);
        }
        buffer
          ..writeln(content)
          ..writeln();
        return _TxtChapterPayload(
          textBlock: buffer.toString(),
          imageRefs:
              includeImages ? _extractImageRefsFromChapter(chapter) : const [],
        );
      },
    );

    final buffer = StringBuffer()
      ..writeln(book.title)
      ..writeln('作者：${book.author.isEmpty ? '未知' : book.author}')
      ..writeln();
    final imageRefs = <_ExportImageRef>[];
    for (final payload in chapterPayloads) {
      buffer.write(payload.textBlock);
      if (payload.imageRefs.isNotEmpty) {
        imageRefs.addAll(payload.imageRefs);
      }
    }
    return _TxtExportPayload(
      content: buffer.toString(),
      imageRefs: imageRefs,
    );
  }

  _BookExportReplaceContext _resolveReplaceContext(
    Book book, {
    required bool exportUseReplace,
  }) {
    final bookUseReplaceRule = _settingsService.getBookUseReplaceRule(
      book.id,
      fallback: true,
    );
    final enabled = exportUseReplace && bookUseReplaceRule;
    if (!enabled) {
      return _BookExportReplaceContext(
        enabled: false,
        bookUseReplaceRule: bookUseReplaceRule,
        rules: const <ReplaceRule>[],
      );
    }
    final rules = _replaceRuleService.getEffectiveRules(
      bookName: book.title,
      sourceUrl: book.sourceUrl,
    );
    return _BookExportReplaceContext(
      enabled: true,
      bookUseReplaceRule: bookUseReplaceRule,
      rules: List<ReplaceRule>.unmodifiable(rules),
    );
  }

  Future<String> _applyReplaceToTitle(
    String title, {
    required _BookExportReplaceContext replaceContext,
  }) async {
    if (!replaceContext.enabled ||
        replaceContext.rules.isEmpty ||
        title.isEmpty) {
      return title;
    }
    return _replaceRuleEngine.applyToTitle(title, replaceContext.rules);
  }

  Future<String> _applyReplaceToContent(
    String content, {
    required _BookExportReplaceContext replaceContext,
  }) async {
    if (!replaceContext.enabled ||
        replaceContext.rules.isEmpty ||
        content.isEmpty) {
      return content;
    }
    return _replaceRuleEngine.applyToContent(content, replaceContext.rules);
  }

  String? _buildExportNote({
    required bool enableExportPictures,
    required int exportedImages,
    required int failedImages,
  }) {
    if (!enableExportPictures) return null;
    if (failedImages <= 0) {
      return 'TXT 导出图片：$exportedImages 张';
    }
    return 'TXT 导出图片：成功$exportedImages张，失败$failedImages张';
  }

  Future<_ImageExportSummary> _exportTxtImages({
    required Book book,
    required List<_ExportImageRef> refs,
    required String outputDirectory,
    required int concurrency,
  }) async {
    final source = _resolveSourceForBook(book);
    if (refs.isEmpty) return const _ImageExportSummary();

    final author = book.author.trim().isEmpty ? '未知' : book.author.trim();
    final bookFolder = _safeFolderName('${book.title}_$author');
    final outcomes = await _mapWithConcurrencyOrdered<_ExportImageRef, bool>(
      items: refs,
      concurrency: concurrency,
      mapper: (ref, _) async {
        try {
          final bytes = await _resolveImageBytes(
            source: source,
            imageUrl: ref.src,
          );
          if (bytes == null || bytes.isEmpty) {
            return false;
          }

          final chapterFolder = _safeFolderName(ref.chapterTitle);
          final fileName = '${ref.index}-${_stableHash16(ref.src)}.jpg';
          final filePath = p.join(
            outputDirectory,
            bookFolder,
            'images',
            chapterFolder,
            fileName,
          );
          final file = File(filePath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
          return true;
        } catch (error, stackTrace) {
          ExceptionLogService().record(
            node: 'bookshelf.cache.export_all.image_write_failed',
            message: '导出章节图片失败',
            error: error,
            stackTrace: stackTrace,
            context: <String, dynamic>{
              'bookId': book.id,
              'bookTitle': book.title,
              'chapterTitle': ref.chapterTitle,
              'imageUrl': ref.src,
            },
          );
          return false;
        }
      },
    );
    final exported = outcomes.where((ok) => ok).length;
    return _ImageExportSummary(
      exportedCount: exported,
      failedCount: outcomes.length - exported,
    );
  }

  List<_ExportImageRef> _extractImageRefsFromChapter(Chapter chapter) {
    final refs = <_ExportImageRef>[];
    final content = chapter.content ?? '';
    if (content.trim().isEmpty) return refs;
    final lines = content.split('\n');
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      for (final match in _imgSrcPattern.allMatches(line)) {
        final rawSrc = (match.group(1) ?? '').trim();
        if (rawSrc.isEmpty) continue;
        refs.add(
          _ExportImageRef(
            chapterTitle: chapter.title,
            index: index,
            src: _resolveImageUrl(
              baseUrl: chapter.url,
              src: rawSrc,
            ),
          ),
        );
      }
    }
    return refs;
  }

  Future<List<R>> _mapWithConcurrencyOrdered<T, R>({
    required List<T> items,
    required int concurrency,
    required Future<R> Function(T item, int index) mapper,
  }) async {
    if (items.isEmpty) return <R>[];
    final workerCount = math.min(
      math.max(1, concurrency),
      items.length,
    );
    if (workerCount == 1) {
      final results = <R>[];
      for (var index = 0; index < items.length; index += 1) {
        results.add(await mapper(items[index], index));
      }
      return results;
    }

    final results = List<R?>.filled(items.length, null);
    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        if (nextIndex >= items.length) return;
        final index = nextIndex;
        nextIndex += 1;
        results[index] = await mapper(items[index], index);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return results.cast<R>();
  }

  String _resolveImageUrl({
    required String? baseUrl,
    required String src,
  }) {
    final trimmedSrc = src.trim();
    if (trimmedSrc.isEmpty) return '';
    final sourceUri = Uri.tryParse(trimmedSrc);
    if (sourceUri != null && sourceUri.hasScheme) {
      return sourceUri.toString();
    }
    final base = (baseUrl ?? '').trim();
    if (base.isEmpty) return trimmedSrc;
    final baseUri = Uri.tryParse(base);
    if (baseUri == null) return trimmedSrc;
    return baseUri.resolve(trimmedSrc).toString();
  }

  Future<Uint8List?> _resolveImageBytes({
    required BookSource? source,
    required String imageUrl,
  }) async {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'data') {
      return _tryDecodeDataImage(trimmed);
    }
    if (uri != null && uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (await file.exists()) {
        return file.readAsBytes();
      }
      return null;
    }

    if (source != null) {
      final sourceBytes = await _sourceCoverLoader.load(
        imageUrl: trimmed,
        source: source,
      );
      if (sourceBytes != null && sourceBytes.isNotEmpty) {
        return sourceBytes;
      }
    }

    return _fetchImageBytesFallback(trimmed);
  }

  Future<Uint8List?> _fetchImageBytesFallback(String imageUrl) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode >= 400) return null;
      final bytes = await response.fold<List<int>>(
        <int>[],
        (prev, element) => prev..addAll(element),
      );
      if (bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Uint8List? _tryDecodeDataImage(String dataUrl) {
    final match = RegExp(r'^data:[^;]+;base64,(.*)$', caseSensitive: false)
        .firstMatch(dataUrl.trim());
    if (match == null) return null;
    final raw = (match.group(1) ?? '').trim();
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    final rem = normalized.length % 4;
    final padded = rem == 0
        ? normalized
        : normalized.padRight(normalized.length + (4 - rem), '=');
    try {
      return Uint8List.fromList(base64Decode(padded));
    } catch (_) {
      return null;
    }
  }

  String _safeFolderName(String raw) {
    final safe = _safeFileName(raw);
    final normalized = safe.replaceAll(RegExp(r'\.+$'), '').trim();
    return normalized.isEmpty ? '未命名' : normalized;
  }

  String _stableHash16(String input) {
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xFFFFFFFFFFFFFFFF;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * prime) & mask;
    }
    final hex = hash.toRadixString(16).padLeft(16, '0');
    return hex.substring(0, 16);
  }

  BookSource? _resolveSourceForBook(Book book) {
    final sourceUrl = (book.sourceUrl ?? '').trim();
    if (sourceUrl.isEmpty) return null;
    return _sourceRepo.getSourceByUrl(sourceUrl);
  }
}

class _ExportImageRef {
  final String chapterTitle;
  final int index;
  final String src;

  const _ExportImageRef({
    required this.chapterTitle,
    required this.index,
    required this.src,
  });
}

class _ImageExportSummary {
  final int exportedCount;
  final int failedCount;

  const _ImageExportSummary({
    this.exportedCount = 0,
    this.failedCount = 0,
  });
}

class _TxtExportPayload {
  final String content;
  final List<_ExportImageRef> imageRefs;

  const _TxtExportPayload({
    required this.content,
    required this.imageRefs,
  });
}

class _TxtChapterPayload {
  final String textBlock;
  final List<_ExportImageRef> imageRefs;

  const _TxtChapterPayload({
    required this.textBlock,
    required this.imageRefs,
  });
}

class _BookExportReplaceContext {
  final bool enabled;
  final bool bookUseReplaceRule;
  final List<ReplaceRule> rules;

  const _BookExportReplaceContext({
    required this.enabled,
    required this.bookUseReplaceRule,
    required this.rules,
  });
}
