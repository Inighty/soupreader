import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/models/book.dart';
import '../../core/database/database_service.dart';
import '../../core/database/repositories/book_repository.dart';
import '../../core/services/exception_log_service.dart';
import '../reader/services/reader_charset_service.dart';
import '../reader/services/txt_toc_rule_store.dart';
import 'book_import_file_name_rule_service.dart';
import 'import_directory_service.dart';
import 'import_file_support.dart';
import 'import_results.dart';
import 'txt_parser.dart';
import 'epub_parser.dart';

export 'import_results.dart';

/// 书籍导入服务
class ImportService {
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;
  final ReaderCharsetService _charsetService;
  final TxtTocRuleStore _txtTocRuleStore;
  final BookImportFileNameRuleService _bookImportFileNameRuleService;
  final ImportDirectoryService _directoryService;

  ImportService()
      : _bookRepo = BookRepository(DatabaseService()),
        _chapterRepo = ChapterRepository(DatabaseService()),
        _charsetService = ReaderCharsetService(),
        _txtTocRuleStore = TxtTocRuleStore(),
        _bookImportFileNameRuleService = BookImportFileNameRuleService(),
        _directoryService = ImportDirectoryService();

  String? getSavedImportDirectory() {
    return _directoryService.getSavedImportDirectory();
  }

  Future<ImportDirectorySelectionResult> selectImportDirectory({
    String? initialDirectory,
  }) async {
    return _directoryService.selectImportDirectory(
      initialDirectory: initialDirectory,
    );
  }

  Future<ImportDirectoryCreateResult> createImportDirectory({
    required String parentDirectoryPath,
    required String folderName,
  }) async {
    return _directoryService.createImportDirectory(
      parentDirectoryPath: parentDirectoryPath,
      folderName: folderName,
    );
  }

  Future<ImportScanResult> scanImportDirectory() async {
    return _directoryService.scanImportDirectory();
  }

  Future<BatchImportResult> importLocalBooksByPaths(
      List<String> filePaths) async {
    final uniquePaths = <String>{};
    for (final rawPath in filePaths) {
      final normalizedPath = p.normalize(rawPath.trim());
      if (normalizedPath.isEmpty) continue;
      uniquePaths.add(normalizedPath);
    }
    if (uniquePaths.isEmpty) {
      return const BatchImportResult(
        totalCount: 0,
        successCount: 0,
        importedBooks: <Book>[],
        failures: <BatchImportFailure>[],
      );
    }

    final importedBooks = <Book>[];
    final failures = <BatchImportFailure>[];

    for (final filePath in uniquePaths) {
      final result = await importLocalBookByPath(filePath);
      if (result.success && result.book != null) {
        importedBooks.add(result.book!);
        continue;
      }
      failures.add(
        BatchImportFailure(
          filePath: filePath,
          errorMessage: result.errorMessage ?? '导入失败',
        ),
      );
    }

    return BatchImportResult(
      totalCount: uniquePaths.length,
      successCount: importedBooks.length,
      importedBooks: importedBooks,
      failures: failures,
    );
  }

  Future<BatchDeleteResult> deleteLocalBooksByPaths(
      List<String> filePaths) async {
    return _directoryService.deleteLocalBooksByPaths(filePaths);
  }

  Future<ImportResult> importLocalBookByPath(String filePath) async {
    final normalizedPath = p.normalize(filePath.trim());
    if (normalizedPath.isEmpty) {
      return ImportResult.error('文件路径为空');
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      return ImportResult.error('文件不存在: $normalizedPath');
    }

    final extension = normalizeImportExtension(p.extension(normalizedPath));
    switch (extension) {
      case 'txt':
        return _importTxtByPath(
          normalizedPath,
          sourceFileName: p.basename(normalizedPath),
        );
      case 'epub':
        return _importEpubByPath(
          normalizedPath,
          sourceFileName: p.basename(normalizedPath),
        );
      default:
        return ImportResult.error('不支持的文件格式: $extension');
    }
  }

  /// 选择并导入本地书籍（支持 TXT 和 EPUB）
  Future<ImportResult> importLocalBook() async {
    try {
      // 打开文件选择器 - 支持 TXT 和 EPUB
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub'],
        allowMultiple: false,
        initialDirectory: getSavedImportDirectory(),
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase() ?? '';

      if (extension == 'txt') {
        return _importTxt(file);
      } else if (extension == 'epub') {
        return _importEpub(file);
      } else {
        return ImportResult.error('不支持的文件格式: $extension');
      }
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  /// 导入 TXT 文件
  Future<ImportResult> importTxtFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
        initialDirectory: getSavedImportDirectory(),
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      return _importTxt(result.files.first);
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  /// 导入 EPUB 文件
  Future<ImportResult> importEpubFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        allowMultiple: false,
        initialDirectory: getSavedImportDirectory(),
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      return _importEpub(result.files.first);
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  /// 内部：导入 TXT
  Future<ImportResult> _importTxt(PlatformFile file) async {
    try {
      final tocRuleRegexCandidates =
          await _loadEnabledTxtTocRuleRegexCandidates();
      if (file.bytes != null) {
        final parseResult = TxtParser.importFromBytes(
          file.bytes!,
          file.name,
          tocRuleRegexCandidates: tocRuleRegexCandidates,
        );
        return _persistTxtImport(
          parseResult: parseResult,
          sourceFileName: file.name,
        );
      }
      if (file.path != null) {
        return _importTxtByPath(
          file.path!,
          sourceFileName: file.name,
          tocRuleRegexCandidates: tocRuleRegexCandidates,
        );
      }
      return ImportResult.error('无法读取文件');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.import_txt.failed',
        message: '导入 TXT 失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportResult.error(error.toString());
    }
  }

  /// 内部：导入 EPUB
  Future<ImportResult> _importEpub(PlatformFile file) async {
    if (file.bytes != null) {
      final parseResult =
          await EpubParser.importFromBytes(file.bytes!, file.name, null);
      return _persistEpubImport(
        parseResult: parseResult,
        sourceFileName: file.name,
      );
    }
    if (file.path != null) {
      return _importEpubByPath(
        file.path!,
        sourceFileName: file.name,
      );
    }
    return ImportResult.error('无法读取文件');
  }

  Future<ImportResult> _importTxtByPath(
    String filePath, {
    required String sourceFileName,
    List<String>? tocRuleRegexCandidates,
  }) async {
    try {
      final parseResult = await TxtParser.importFromFile(
        filePath,
        tocRuleRegexCandidates: tocRuleRegexCandidates,
      );
      return _persistTxtImport(
        parseResult: parseResult,
        sourceFileName: sourceFileName,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.scan_folder.import_txt.failed',
        message: '导入 TXT 失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportResult.error(error.toString());
    }
  }

  Future<List<String>?> _loadEnabledTxtTocRuleRegexCandidates() async {
    try {
      final enabledRules = await _txtTocRuleStore.loadEnabledRules();
      final candidates = <String>[];
      for (final rule in enabledRules) {
        final regex = rule.rule.trim();
        if (regex.isEmpty) continue;
        if (!_isValidRegexPattern(regex)) {
          ExceptionLogService().record(
            node: 'bookshelf.import.txt_toc_rule.invalid_regex',
            message: 'TXT 目录规则正则无效，已跳过',
            context: <String, dynamic>{
              'ruleId': rule.id,
              'ruleName': rule.name,
              'ruleRegex': regex,
            },
          );
          continue;
        }
        candidates.add(regex);
      }
      return candidates;
    } catch (error, stackTrace) {
      // 目录规则加载失败不应阻断导入主链路，回退到解析器内置自动识别策略。
      ExceptionLogService().record(
        node: 'bookshelf.import.txt_toc_rule.load.failed',
        message: '加载 TXT 目录规则失败，已回退默认自动识别',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  bool _isValidRegexPattern(String regex) {
    try {
      RegExp(regex, multiLine: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ImportResult> _importEpubByPath(
    String filePath, {
    required String sourceFileName,
  }) async {
    try {
      final parseResult = await EpubParser.importFromFile(filePath);
      return _persistEpubImport(
        parseResult: parseResult,
        sourceFileName: sourceFileName,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.scan_folder.import_epub.failed',
        message: '导入 EPUB 失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportResult.error(error.toString());
    }
  }

  Future<ImportResult> _persistTxtImport({
    required TxtImportResult parseResult,
    required String sourceFileName,
  }) async {
    final normalizedBook = _applyFileNameRule(
      book: parseResult.book,
      sourceFileName: sourceFileName,
    );
    await _bookRepo.addBook(normalizedBook);
    await _chapterRepo.addChapters(parseResult.chapters);
    await _charsetService.setBookCharset(
      normalizedBook.id,
      parseResult.charset,
    );
    return ImportResult.success(
      book: normalizedBook,
      chapterCount: parseResult.chapters.length,
    );
  }

  Future<ImportResult> _persistEpubImport({
    required EpubImportResult parseResult,
    required String sourceFileName,
  }) async {
    final fallbackTitle = _fallbackTitleByFileName(sourceFileName);
    final shouldUseFileNameRuleForTitle =
        parseResult.book.title.trim() == fallbackTitle;
    final shouldUseFileNameRuleForAuthor =
        parseResult.book.author.trim().isEmpty ||
            parseResult.book.author.trim() == '未知作者';
    final normalizedBook = _applyFileNameRule(
      book: parseResult.book,
      sourceFileName: sourceFileName,
      allowTitleOverride: shouldUseFileNameRuleForTitle,
      allowAuthorOverride: shouldUseFileNameRuleForAuthor,
    );
    await _bookRepo.addBook(normalizedBook);
    await _chapterRepo.addChapters(parseResult.chapters);
    return ImportResult.success(
      book: normalizedBook,
      chapterCount: parseResult.chapters.length,
    );
  }

  Book _applyFileNameRule({
    required Book book,
    required String sourceFileName,
    bool allowTitleOverride = true,
    bool allowAuthorOverride = true,
  }) {
    final result = _bookImportFileNameRuleService.evaluateByFileName(
      sourceFileName,
    );
    if (!result.hasAnyField) return book;

    final nextTitle =
        (result.hasName && allowTitleOverride && result.name.isNotEmpty)
            ? result.name
            : book.title;
    final nextAuthor =
        (result.hasAuthor && allowAuthorOverride) ? result.author : book.author;

    if (nextTitle == book.title && nextAuthor == book.author) {
      return book;
    }
    return book.copyWith(
      title: nextTitle,
      author: nextAuthor,
    );
  }

  String _fallbackTitleByFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'\.epub$', caseSensitive: false), '')
        .trim();
  }

  /// 检查书籍是否已存在
  bool hasBook(String bookId) => _bookRepo.hasBook(bookId);
}
