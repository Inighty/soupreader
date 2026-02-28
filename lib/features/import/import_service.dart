import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../bookshelf/models/book.dart';
import '../../core/database/database_service.dart';
import '../../core/database/repositories/book_repository.dart';
import '../../core/services/exception_log_service.dart';
import '../reader/services/reader_charset_service.dart';
import '../reader/services/txt_toc_rule_store.dart';
import 'book_import_file_name_rule_service.dart';
import 'txt_parser.dart';
import 'epub_parser.dart';

/// 书籍导入服务
class ImportService {
  static const String _importBookPathKey = 'importBookPath';
  static const Set<String> _supportedImportExtensions = <String>{
    'txt',
    'epub',
  };

  final DatabaseService _database;
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;
  final ReaderCharsetService _charsetService;
  final TxtTocRuleStore _txtTocRuleStore;
  final BookImportFileNameRuleService _bookImportFileNameRuleService;

  ImportService()
      : _database = DatabaseService(),
        _bookRepo = BookRepository(DatabaseService()),
        _chapterRepo = ChapterRepository(DatabaseService()),
        _charsetService = ReaderCharsetService(),
        _txtTocRuleStore = TxtTocRuleStore(),
        _bookImportFileNameRuleService = BookImportFileNameRuleService();

  String? getSavedImportDirectory() {
    final raw = _database.getSetting(_importBookPathKey, defaultValue: null);
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return p.normalize(text);
  }

  Future<ImportDirectorySelectionResult> selectImportDirectory({
    String? initialDirectory,
  }) async {
    try {
      final normalizedInitialDirectory =
          (initialDirectory?.trim().isNotEmpty ?? false)
              ? p.normalize(initialDirectory!.trim())
              : getSavedImportDirectory();
      final selected = await FilePicker.platform.getDirectoryPath(
        initialDirectory: normalizedInitialDirectory,
      );
      final normalized = (selected ?? '').trim();
      if (normalized.isEmpty) {
        return ImportDirectorySelectionResult.cancelled();
      }
      final directoryPath = p.normalize(normalized);
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        return ImportDirectorySelectionResult.error('所选文件夹不存在');
      }
      if (!await _isAllowedImportDirectory(directoryPath)) {
        return ImportDirectorySelectionResult.error(
          '请选择应用目录之外的文件夹',
        );
      }
      await _database.putSetting(_importBookPathKey, directoryPath);
      return ImportDirectorySelectionResult.success(
        directoryPath: directoryPath,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.select_folder.failed',
        message: '选择导入文件夹失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportDirectorySelectionResult.error(error.toString());
    }
  }

  Future<ImportDirectoryCreateResult> createImportDirectory({
    required String parentDirectoryPath,
    required String folderName,
  }) async {
    final normalizedParent = p.normalize(parentDirectoryPath.trim());
    final normalizedName = folderName.trim();
    if (normalizedName.isEmpty) {
      return ImportDirectoryCreateResult.error('文件夹名不能为空');
    }
    if (normalizedName == '.' || normalizedName == '..') {
      return ImportDirectoryCreateResult.error('非法文件夹名');
    }
    if (normalizedName.contains(RegExp(r'[\\/]'))) {
      return ImportDirectoryCreateResult.error('文件夹名不能包含路径分隔符');
    }

    try {
      final parentDirectory = Directory(normalizedParent);
      if (!await parentDirectory.exists()) {
        return ImportDirectoryCreateResult.error('父文件夹不存在');
      }
      if (!await _isAllowedImportDirectory(normalizedParent)) {
        return ImportDirectoryCreateResult.error('请选择应用目录之外的文件夹');
      }

      final normalizedTarget =
          p.normalize(p.join(normalizedParent, normalizedName));
      if (normalizedTarget == normalizedParent ||
          !p.isWithin(normalizedParent, normalizedTarget)) {
        return ImportDirectoryCreateResult.error('非法文件夹名');
      }

      final targetDirectory = Directory(normalizedTarget);
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: false);
      }
      if (!await targetDirectory.exists()) {
        return ImportDirectoryCreateResult.error('创建文件夹失败');
      }
      if (!await _isAllowedImportDirectory(normalizedTarget)) {
        return ImportDirectoryCreateResult.error('请选择应用目录之外的文件夹');
      }
      await _database.putSetting(_importBookPathKey, normalizedTarget);

      return ImportDirectoryCreateResult.success(
        directoryPath: normalizedTarget,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.create_folder.failed',
        message: '创建导入文件夹失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportDirectoryCreateResult.error(error.toString());
    }
  }

  Future<ImportScanResult> scanImportDirectory() async {
    final savedDirectory = getSavedImportDirectory();
    if (savedDirectory == null || savedDirectory.trim().isEmpty) {
      return ImportScanResult.error('请先选择文件夹');
    }

    final normalizedRoot = p.normalize(savedDirectory);
    final rootDirectory = Directory(normalizedRoot);
    if (!await rootDirectory.exists()) {
      return ImportScanResult.error('所选文件夹不存在');
    }

    final candidates = <ImportScanCandidate>[];
    try {
      await for (final entity
          in rootDirectory.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final extension = _normalizeImportExtension(p.extension(entity.path));
        if (!_supportedImportExtensions.contains(extension)) {
          continue;
        }
        final normalizedPath = p.normalize(entity.path);
        FileStat stat;
        try {
          stat = await entity.stat();
        } catch (_) {
          stat = FileStat.statSync(normalizedPath);
        }
        candidates.add(
          ImportScanCandidate(
            filePath: normalizedPath,
            fileName: p.basename(normalizedPath),
            sizeInBytes: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.scan_folder.failed',
        message: '智能扫描文件夹失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportScanResult.error(error.toString());
    }

    candidates.sort((a, b) {
      final nameCompare = a.fileName.compareTo(b.fileName);
      if (nameCompare != 0) return nameCompare;
      return a.filePath.compareTo(b.filePath);
    });
    return ImportScanResult.success(
      rootDirectoryPath: normalizedRoot,
      candidates: candidates,
    );
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
    final uniquePaths = <String>{};
    for (final rawPath in filePaths) {
      final normalizedPath = p.normalize(rawPath.trim());
      if (normalizedPath.isEmpty) continue;
      uniquePaths.add(normalizedPath);
    }
    if (uniquePaths.isEmpty) {
      return const BatchDeleteResult(
        totalCount: 0,
        deletedCount: 0,
        failures: <BatchDeleteFailure>[],
      );
    }

    final failures = <BatchDeleteFailure>[];
    for (final filePath in uniquePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        ExceptionLogService().record(
          node: 'bookshelf.import.scan_folder.delete_file.failed',
          message: '删除导入文件失败',
          error: error,
          stackTrace: stackTrace,
        );
        failures.add(
          BatchDeleteFailure(
            filePath: filePath,
            errorMessage: error.toString(),
          ),
        );
      }
    }

    return BatchDeleteResult(
      totalCount: uniquePaths.length,
      deletedCount: uniquePaths.length - failures.length,
      failures: failures,
    );
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

    final extension = _normalizeImportExtension(p.extension(normalizedPath));
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

  String _normalizeImportExtension(String extension) {
    final normalized = extension.trim().toLowerCase();
    if (normalized.startsWith('.')) {
      return normalized.substring(1);
    }
    return normalized;
  }

  Future<bool> _isAllowedImportDirectory(String directoryPath) async {
    final normalized = p.normalize(directoryPath.trim());
    if (normalized.isEmpty) return false;

    final protectedDirectories = <String>{};
    Future<void> collectProtectedPath(
        Future<Directory> Function() loader) async {
      try {
        final directory = await loader();
        final path = p.normalize(directory.path.trim());
        if (path.isEmpty) return;
        protectedDirectories.add(path);
      } catch (_) {
        // noop
      }
    }

    await collectProtectedPath(getApplicationSupportDirectory);
    await collectProtectedPath(getApplicationDocumentsDirectory);
    await collectProtectedPath(getTemporaryDirectory);

    for (final protectedPath in protectedDirectories) {
      if (normalized == protectedPath) return false;
      if (p.isWithin(protectedPath, normalized)) return false;
    }
    return true;
  }
}

/// 选择导入目录结果
class ImportDirectorySelectionResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final String? directoryPath;

  ImportDirectorySelectionResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.directoryPath,
  });

  factory ImportDirectorySelectionResult.success({
    required String directoryPath,
  }) {
    return ImportDirectorySelectionResult._(
      success: true,
      directoryPath: directoryPath,
    );
  }

  factory ImportDirectorySelectionResult.cancelled() {
    return ImportDirectorySelectionResult._(success: false, cancelled: true);
  }

  factory ImportDirectorySelectionResult.error(String message) {
    return ImportDirectorySelectionResult._(
      success: false,
      errorMessage: message,
    );
  }
}

class ImportDirectoryCreateResult {
  final bool success;
  final String? errorMessage;
  final String? directoryPath;

  ImportDirectoryCreateResult._({
    required this.success,
    this.errorMessage,
    this.directoryPath,
  });

  factory ImportDirectoryCreateResult.success({
    required String directoryPath,
  }) {
    return ImportDirectoryCreateResult._(
      success: true,
      directoryPath: directoryPath,
    );
  }

  factory ImportDirectoryCreateResult.error(String message) {
    return ImportDirectoryCreateResult._(
      success: false,
      errorMessage: message,
    );
  }
}

class ImportScanCandidate {
  final String filePath;
  final String fileName;
  final int sizeInBytes;
  final DateTime modifiedAt;

  const ImportScanCandidate({
    required this.filePath,
    required this.fileName,
    required this.sizeInBytes,
    required this.modifiedAt,
  });
}

class ImportScanResult {
  final bool success;
  final String? errorMessage;
  final String? rootDirectoryPath;
  final List<ImportScanCandidate> candidates;

  const ImportScanResult._({
    required this.success,
    this.errorMessage,
    this.rootDirectoryPath,
    this.candidates = const <ImportScanCandidate>[],
  });

  factory ImportScanResult.success({
    required String rootDirectoryPath,
    required List<ImportScanCandidate> candidates,
  }) {
    return ImportScanResult._(
      success: true,
      rootDirectoryPath: rootDirectoryPath,
      candidates: candidates,
    );
  }

  factory ImportScanResult.error(String message) {
    return ImportScanResult._(
      success: false,
      errorMessage: message,
    );
  }
}

class BatchImportFailure {
  final String filePath;
  final String errorMessage;

  const BatchImportFailure({
    required this.filePath,
    required this.errorMessage,
  });
}

class BatchImportResult {
  final int totalCount;
  final int successCount;
  final List<Book> importedBooks;
  final List<BatchImportFailure> failures;

  const BatchImportResult({
    required this.totalCount,
    required this.successCount,
    required this.importedBooks,
    required this.failures,
  });

  int get failedCount => failures.length;
}

class BatchDeleteFailure {
  final String filePath;
  final String errorMessage;

  const BatchDeleteFailure({
    required this.filePath,
    required this.errorMessage,
  });
}

class BatchDeleteResult {
  final int totalCount;
  final int deletedCount;
  final List<BatchDeleteFailure> failures;

  const BatchDeleteResult({
    required this.totalCount,
    required this.deletedCount,
    required this.failures,
  });

  int get failedCount => failures.length;
}

/// 导入结果
class ImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final Book? book;
  final int chapterCount;

  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.book,
    this.chapterCount = 0,
  });

  factory ImportResult.success(
      {required Book book, required int chapterCount}) {
    return ImportResult._(
        success: true, book: book, chapterCount: chapterCount);
  }

  factory ImportResult.cancelled() {
    return ImportResult._(success: false, cancelled: true);
  }

  factory ImportResult.error(String message) {
    return ImportResult._(success: false, errorMessage: message);
  }
}
