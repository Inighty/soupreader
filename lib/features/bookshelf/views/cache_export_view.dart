import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../models/book.dart';
import '../services/cache_download_task_service.dart';
import '../services/cache_export_task_service.dart';
import 'cache_export_actions.dart';
import 'cache_export_dialogs.dart';
import 'cache_export_helpers.dart';
import 'cache_export_widgets.dart';

/// 缓存/导出页（当前已收敛 `menu_download`、`menu_download_after`、
/// `menu_download_all`、`menu_book_group`、`menu_export_all`、
/// `menu_enable_replace`、`menu_enable_custom_export`、`menu_export_web_dav`、
/// `menu_export_no_chapter_name`、`menu_export_pics_file`、`menu_parallel_export`、
/// `menu_export_folder`、`menu_export_file_name`、`menu_export_type`、
/// `menu_export_charset`）。
class CacheExportView extends StatefulWidget {
  const CacheExportView({super.key, this.initialGroupId});

  final int? initialGroupId;

  @override
  State<CacheExportView> createState() => _CacheExportViewState();
}

class _CacheExportViewState extends State<CacheExportView> {
  late final BookRepository _bookRepo;
  late final ChapterRepository _chapterRepo;
  late final CacheDownloadTaskService _downloadService;
  late final CacheExportTaskService _exportService;

  StreamSubscription<List<Book>>? _booksSubscription;

  List<Book> _allBooks = const <Book>[];
  List<Book> _books = const <Book>[];
  Map<String, int> _cachedChapterCountByBookId = const <String, int>{};
  int _selectedGroupId = cacheGroupIdAll;
  String _selectedGroupTitle = '全部';
  CacheDownloadProgress? _progress;
  bool _downloadRunning = false;
  bool _exportRunning = false;
  bool _exportUseReplace = true;
  bool _enableCustomExport = false;
  bool _exportToWebDav = false;
  bool _exportNoChapterName = false;
  bool _exportPictureFile = false;
  bool _parallelExportBook = false;
  int _exportTypeIndex = 0;
  String _exportCharset = CacheExportTaskService.defaultExportCharset;
  String? _initError;

  @override
  void initState() {
    super.initState();
    try {
      final db = DatabaseService();
      _bookRepo = BookRepository(db);
      _chapterRepo = ChapterRepository(db);
      _downloadService = CacheDownloadTaskService(
        database: db,
        bookRepo: _bookRepo,
        chapterRepo: _chapterRepo,
      );
      _exportService = CacheExportTaskService(
        database: db,
        chapterRepo: _chapterRepo,
      );
      _refreshExportFlagsFromService();
      final initialGroupId = widget.initialGroupId;
      if (initialGroupId != null) {
        final matchesLegacy =
            cacheLegacyBookGroups.any((g) => g.id == initialGroupId);
        if (matchesLegacy) {
          _selectedGroupId = initialGroupId;
          _selectedGroupTitle = resolveCacheGroupTitle(initialGroupId);
        }
      }
      _refreshBooksSnapshot();
      _booksSubscription = _bookRepo.watchAllBooks().listen((books) {
        if (!mounted) return;
        _applyBooks(books);
      });
    } catch (error) {
      _initError = '缓存/导出页初始化失败：$error';
    }
  }

  @override
  void dispose() {
    _booksSubscription?.cancel();
    if (_downloadRunning) {
      _downloadService.stop();
    }
    super.dispose();
  }

  void _refreshExportFlagsFromService() {
    _exportUseReplace = _exportService.getExportUseReplace();
    _enableCustomExport = _exportService.getEnableCustomExport();
    _exportToWebDav = _exportService.getExportToWebDav();
    _exportNoChapterName = _exportService.getExportNoChapterName();
    _exportPictureFile = _exportService.getExportPictureFile();
    _parallelExportBook = _exportService.getParallelExportBook();
    _exportTypeIndex = _exportService.getExportTypeIndex();
    _exportCharset = _exportService.getExportCharset();
  }

  void _applyBooks(List<Book> books) {
    final nextBooks = List<Book>.from(books);
    sortCacheBooksByRecentRead(nextBooks);
    final nextCount = _buildCachedCountMap(nextBooks);
    final filtered = filterCacheBooksByGroup(nextBooks, _selectedGroupId);
    setState(() {
      _allBooks = nextBooks;
      _books = filtered;
      _cachedChapterCountByBookId = nextCount;
      _selectedGroupTitle = resolveCacheGroupTitle(_selectedGroupId);
    });
  }

  Map<String, int> _buildCachedCountMap(List<Book> books) {
    final next = <String, int>{};
    for (final book in books) {
      next[book.id] =
          _chapterRepo.getDownloadedCacheInfoForBook(book.id).chapters;
    }
    return next;
  }

  void _refreshBooksSnapshot() {
    final books = List<Book>.from(_bookRepo.getAllBooks());
    sortCacheBooksByRecentRead(books);
    if (!mounted) return;
    setState(() {
      _allBooks = books;
      _books = filterCacheBooksByGroup(books, _selectedGroupId);
      _cachedChapterCountByBookId = _buildCachedCountMap(books);
      _selectedGroupTitle = resolveCacheGroupTitle(_selectedGroupId);
    });
  }

  void _handleDownloadProgress(CacheDownloadProgress progress) {
    if (!mounted) return;
    final nextCount = Map<String, int>.from(_cachedChapterCountByBookId);
    nextCount[progress.bookId] =
        _chapterRepo.getDownloadedCacheInfoForBook(progress.bookId).chapters;
    setState(() {
      _progress = progress;
      _cachedChapterCountByBookId = nextCount;
    });
  }

  Future<void> _handleDownloadTap() => _startDownload(downloadAllChapters: false);
  Future<void> _handleDownloadAllTap() =>
      _startDownload(downloadAllChapters: true);

  Future<void> _downloadSingleBook(Book book) async {
    if (_downloadRunning || book.isLocal) return;
    setState(() {
      _downloadRunning = true;
      _progress = null;
    });
    try {
      final summary = await _downloadService.startDownloadFromCurrentChapter(
        [book],
        onProgress: _handleDownloadProgress,
      );
      _refreshBooksSnapshot();
      if (!mounted) return;
      await _showMessage(buildCacheDownloadSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('缓存失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _downloadRunning = false);
    }
  }

  Future<void> _exportSingleBook(Book book) async {
    if (_exportRunning) return;
    setState(() => _exportRunning = true);
    try {
      final exportDirectory = await _resolveExportDirectory();
      if (exportDirectory == null) return;
      final summary = await _exportService.exportAllToDirectory(
        [book],
        exportDirectory,
        exportPictureFile: _exportPictureFile,
      );
      if (!mounted) return;
      await _showMessage(buildCacheExportSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('导出失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _exportRunning = false);
    }
  }

  Future<void> _startDownload({required bool downloadAllChapters}) async {
    if (_downloadRunning) {
      _downloadService.stop();
      return;
    }

    final candidates =
        _books.where((book) => !book.isLocal).toList(growable: false);
    if (candidates.isEmpty) {
      await _showMessage('当前无可缓存的在线书籍');
      return;
    }

    final confirmed = await confirmCacheStartDownload(context);
    if (!confirmed) return;

    if (!mounted) return;
    setState(() {
      _downloadRunning = true;
      _progress = null;
    });

    try {
      final summary = downloadAllChapters
          ? await _downloadService.startDownloadAllChapters(
              _books,
              onProgress: _handleDownloadProgress,
            )
          : await _downloadService.startDownloadFromCurrentChapter(
              _books,
              onProgress: _handleDownloadProgress,
            );
      _refreshBooksSnapshot();
      if (!mounted) return;
      await _showMessage(buildCacheDownloadSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('缓存失败：$error');
    } finally {
      if (!mounted) return;
      setState(() {
        _downloadRunning = false;
        _progress = null;
      });
    }
  }

  Future<void> _handleDownloadActionLongPress() {
    return showCacheDownloadActionLongPressSheet(
      context: context,
      onDownloadAfter: _handleDownloadTap,
      onDownloadAll: _handleDownloadAllTap,
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCacheExportMessage(context, message);
  }

  Future<void> _handleMoreTap() async {
    if (_exportRunning || !mounted) return;
    setState(_refreshExportFlagsFromService);
    await showCacheExportMoreSheet(
      context: context,
      flags: CacheExportToggleFlags(
        exportUseReplace: _exportUseReplace,
        enableCustomExport: _enableCustomExport,
        exportToWebDav: _exportToWebDav,
        exportNoChapterName: _exportNoChapterName,
        exportPictureFile: _exportPictureFile,
        parallelExportBook: _parallelExportBook,
      ),
      currentExportTypeName: _currentExportTypeName(),
      currentExportCharset: _exportCharset,
      callbacks: CacheExportMoreCallbacks(
        onExportAll: _handleExportAllTap,
        onToggleUseReplace: _toggleExportUseReplace,
        onToggleCustomExport: _toggleCustomExport,
        onToggleExportToWebDav: _toggleExportToWebDav,
        onToggleNoChapterName: _toggleExportNoChapterName,
        onToggleExportPicture: _toggleExportPictureFile,
        onToggleParallel: _toggleParallelExportBook,
        onPickFolder: _handleExportFolderTap,
        onPickFileName: _handleExportFileNameTap,
        onPickType: _handleExportTypeTap,
        onPickCharset: _handleExportCharsetTap,
      ),
    );
  }

  Future<void> _handleBookGroupTap() async {
    if (!mounted) return;
    final selectedGroupId = await showCacheExportBookGroupSheet(
      context: context,
      selectedGroupId: _selectedGroupId,
    );
    if (selectedGroupId == null || selectedGroupId == _selectedGroupId) return;
    if (!mounted) return;
    setState(() {
      _selectedGroupId = selectedGroupId;
      _selectedGroupTitle = resolveCacheGroupTitle(selectedGroupId);
      _books = filterCacheBooksByGroup(_allBooks, selectedGroupId);
    });
  }

  Future<void> _toggleExportUseReplace() => _toggleFlag(
      _exportUseReplace,
      (v) => _exportUseReplace = v,
      _exportService.saveExportUseReplace);

  Future<void> _toggleCustomExport() => _toggleFlag(
      _enableCustomExport,
      (v) => _enableCustomExport = v,
      _exportService.saveEnableCustomExport);

  Future<void> _toggleExportToWebDav() => _toggleFlag(
      _exportToWebDav,
      (v) => _exportToWebDav = v,
      _exportService.saveExportToWebDav);

  Future<void> _toggleExportNoChapterName() => _toggleFlag(
      _exportNoChapterName,
      (v) => _exportNoChapterName = v,
      _exportService.saveExportNoChapterName);

  Future<void> _toggleExportPictureFile() => _toggleFlag(
      _exportPictureFile,
      (v) => _exportPictureFile = v,
      _exportService.saveExportPictureFile);

  Future<void> _toggleParallelExportBook() => _toggleFlag(
      _parallelExportBook,
      (v) => _parallelExportBook = v,
      _exportService.saveParallelExportBook);

  Future<void> _toggleFlag(
    bool currentValue,
    void Function(bool) applyOptimistic,
    Future<void> Function(bool) save,
  ) async {
    final nextValue = !currentValue;
    if (!mounted) return;
    setState(() => applyOptimistic(nextValue));
    try {
      await save(nextValue);
    } catch (error) {
      if (!mounted) return;
      setState(() => applyOptimistic(currentValue));
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _handleExportFolderTap() =>
      handleCacheExportFolderTap(_exportService);

  Future<void> _handleExportFileNameTap() => handleCacheExportFileNameTap(
        context: context,
        exportService: _exportService,
      );

  String _currentExportTypeName() {
    final options = _exportService.getExportTypeOptions();
    if (_exportTypeIndex < 0 || _exportTypeIndex >= options.length) {
      return options.first;
    }
    return options[_exportTypeIndex];
  }

  Future<void> _handleExportTypeTap() async {
    if (!mounted) return;
    final options = _exportService.getExportTypeOptions();
    final selected = await showCacheExportTypeSheet(
      context: context,
      options: options,
      currentIndex: _exportTypeIndex,
    );
    if (selected == null || selected == _exportTypeIndex) return;

    final previous = _exportTypeIndex;
    if (!mounted) return;
    setState(() => _exportTypeIndex = selected);
    try {
      await _exportService.saveExportTypeIndex(selected);
    } catch (error) {
      if (!mounted) return;
      setState(() => _exportTypeIndex = previous);
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _handleExportCharsetTap() async {
    final next = await handleCacheExportCharsetTap(
      context: context,
      exportService: _exportService,
    );
    if (next == null || !mounted) return;
    setState(() => _exportCharset = next);
  }

  Future<void> _handleExportAllTap() async {
    if (_exportRunning) return;
    if (_books.isEmpty) {
      await _showMessage('暂无书籍');
      return;
    }

    if (!mounted) return;
    setState(() => _exportRunning = true);

    try {
      final exportDirectory = await _resolveExportDirectory();
      if (exportDirectory == null) return;

      final summary = await _exportService.exportAllToDirectory(
        _books,
        exportDirectory,
        exportPictureFile: _exportPictureFile,
      );
      if (!mounted) return;
      await _showMessage(buildCacheExportSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('导出失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _exportRunning = false);
    }
  }

  Future<String?> _resolveExportDirectory() =>
      resolveCacheExportDirectory(_exportService);

  @override
  Widget build(BuildContext context) {
    final initError = _initError;
    return AppCupertinoPageScaffold(
      title: '缓存/导出',
      middle: CacheExportNavMiddle(groupTitle: _selectedGroupTitle),
      trailing: CacheExportTopActions(
        downloadRunning: _downloadRunning,
        onDownloadTap: _handleDownloadTap,
        onDownloadLongPress: _handleDownloadActionLongPress,
        onBookGroupTap: _handleBookGroupTap,
        onMoreTap: _handleMoreTap,
      ),
      child: initError == null
          ? Column(
              children: [
                const CacheExportMigrationHintCard(),
                CacheExportProgressCard(progress: _progress),
                Expanded(
                  child: _books.isEmpty
                      ? const AppEmptyState(
                          illustration: AppEmptyPlanetIllustration(size: 86),
                          title: '暂无书籍',
                          message: '请先在书架添加书籍，或切换分组后重试。',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 12, bottom: 16),
                          itemCount: _books.length,
                          itemBuilder: (context, index) {
                            final book = _books[index];
                            return CacheExportBookTile(
                              book: book,
                              cachedChapters:
                                  _cachedChapterCountByBookId[book.id] ?? 0,
                              downloadRunning: _downloadRunning,
                              exportRunning: _exportRunning,
                              onDownload: () => _downloadSingleBook(book),
                              onExport: () => _exportSingleBook(book),
                            );
                          },
                        ),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  initError,
                  style: TextStyle(
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
              ),
            ),
    );
  }
}
