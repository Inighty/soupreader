import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../source/models/book_source.dart';

/// 书架管理导出服务（对齐 legado `menu_export_all_use_book_source`）。
///
/// 对齐基准：`BookDao.getAllUseBookSource`
/// - 仅统计“书架在用”的线上书籍来源；
/// - 过滤本地标签与 WebDav 标签来源；
/// - 仅返回当前书源仓库中可命中的书源对象。
class BookshelfManageExportService {
  BookshelfManageExportService({
    required BookRepository bookRepository,
    required SourceRepository sourceRepository,
  })  : _bookRepository = bookRepository,
        _sourceRepository = sourceRepository;

  static const String _legacyLocalTag = 'loc_book';
  static const String _legacyWebDavTag = 'webDav::';

  final BookRepository _bookRepository;
  final SourceRepository _sourceRepository;

  List<BookSource> collectAllUsedBookSources() {
    final books = _bookRepository.getAllBooks();
    final allSources = _sourceRepository.getAllSources();
    if (books.isEmpty || allSources.isEmpty) {
      return const <BookSource>[];
    }

    final sourceByUrl = <String, BookSource>{
      for (final source in allSources) source.bookSourceUrl.trim(): source,
    };

    final orderedUrls = <String>[];
    final seenUrls = <String>{};
    for (final book in books) {
      if (book.isLocal) continue;
      final sourceUrl = (book.sourceUrl ?? '').trim();
      if (sourceUrl.isEmpty) continue;
      if (_isLegacyExcludedSourceTag(sourceUrl)) continue;
      if (!seenUrls.add(sourceUrl)) continue;
      orderedUrls.add(sourceUrl);
    }

    final usedSources = <BookSource>[];
    for (final url in orderedUrls) {
      final source = sourceByUrl[url];
      if (source != null) {
        usedSources.add(source);
      }
    }
    return usedSources;
  }

  bool _isLegacyExcludedSourceTag(String sourceUrl) {
    final normalized = sourceUrl.trim();
    if (normalized.isEmpty) return true;
    if (normalized.startsWith(_legacyWebDavTag)) return true;
    final lower = normalized.toLowerCase();
    if (lower.startsWith(_legacyLocalTag)) return true;
    if (lower.startsWith(_legacyWebDavTag.toLowerCase())) return true;
    return false;
  }
}
