import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../../source/services/source_import/export_service.dart';
import '../../search/views/search_book_info_view.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import '../services/bookshelf_book_group_store.dart';
import '../services/bookshelf_manage_batch_change_source_service.dart';
import '../services/bookshelf_manage_export_service.dart';
import 'bookshelf_group_manage_placeholder_dialog.dart';
import 'bookshelf_manage_actions.dart';
import 'bookshelf_manage_body.dart';
import 'bookshelf_manage_dialogs.dart';
import 'bookshelf_manage_helpers.dart';

/// 书架管理承载页（对应 legado: menu_bookshelf_manage -> BookshelfManageActivity）。
class BookshelfManagePlaceholderView extends StatefulWidget {
  const BookshelfManagePlaceholderView({
    super.key,
    this.initialGroupId,
  });

  final int? initialGroupId;

  @override
  State<BookshelfManagePlaceholderView> createState() =>
      _BookshelfManagePlaceholderViewState();
}

class _BookshelfManagePlaceholderViewState
    extends State<BookshelfManagePlaceholderView> {
  late final DatabaseService _database;
  late final BookRepository _bookRepository;
  late final ChapterRepository _chapterRepository;
  late final SourceRepository _sourceRepository;
  late final BookshelfBookGroupStore _bookGroupStore;
  late final SourceImportExportService _sourceImportExportService;
  late final BookshelfManageExportService _exportService;
  late final SettingsService _settingsService;
  late final ExceptionLogService _exceptionLogService;
  late final BookshelfManageBatchChangeSourceService _batchChangeSourceService;

  StreamSubscription<List<Book>>? _bookSubscription;
  List<Book> _allBooks = const <Book>[];
  List<BookshelfBookGroup> _bookGroups = bookshelfManageDefaultBookGroups;
  Map<String, int> _bookGroupMembershipMap = const <String, int>{};
  int _selectedGroupId = BookshelfBookGroup.idAll;
  String _selectedGroupTitle = '全部';
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedBookIds = <String>{};

  bool _isExporting = false;
  bool _isBatchChangingSource = false;
  bool _isClearingCache = false;
  bool _isDeletingSelection = false;
  bool _isUpdatingCanUpdate = false;
  bool _isAddingToGroup = false;
  bool _openBookInfoByClickTitle = true;

  bool get _selectionBlocked =>
      _isBatchChangingSource ||
      _isClearingCache ||
      _isDeletingSelection ||
      _isUpdatingCanUpdate ||
      _isAddingToGroup;

  bool get _disableNavActions => _isExporting || _selectionBlocked;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _database = db;
    _bookRepository = BookRepository(db);
    _chapterRepository = ChapterRepository(db);
    _sourceRepository = SourceRepository(db);
    _bookGroupStore = BookshelfBookGroupStore(database: db);
    _sourceImportExportService = SourceImportExportService();
    _settingsService = SettingsService();
    _exceptionLogService = ExceptionLogService();
    _exportService = BookshelfManageExportService(
      bookRepository: _bookRepository,
      sourceRepository: _sourceRepository,
    );
    _batchChangeSourceService = BookshelfManageBatchChangeSourceService(
      bookRepository: _bookRepository,
      sourceRepository: _sourceRepository,
      chapterRepository: _chapterRepository,
      ruleEngine: RuleParserEngine(),
      settingsService: _settingsService,
      exceptionLogService: _exceptionLogService,
    );
    _openBookInfoByClickTitle = _settingsService.getOpenBookInfoByClickTitle();
    _allBooks = sortBookshelfManageBooks(
      books: _bookRepository.getAllBooks(),
      settingsService: _settingsService,
    );
    final initialGroupId = widget.initialGroupId;
    if (initialGroupId != null && initialGroupId != BookshelfBookGroup.idRoot) {
      _selectedGroupId = initialGroupId;
    }
    unawaited(_reloadBookGroupContext(showError: false));
    _bookSubscription = _bookRepository.watchAllBooks().listen((books) {
      if (!mounted) return;
      setState(() {
        _allBooks = sortBookshelfManageBooks(
          books: books,
          settingsService: _settingsService,
        );
        _pruneInvalidSelection();
      });
    });
  }

  @override
  void dispose() {
    _bookSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadBookGroupContext({required bool showError}) async {
    try {
      final groups = await _bookGroupStore.getGroups();
      if (!mounted) return;
      final normalizedGroups = normalizeBookshelfManageGroups(groups);
      final groupMembership =
          readBookshelfManageGroupMembershipMap(_database);
      var nextSelectedGroupId = _selectedGroupId;
      final hasSelectedGroup = normalizedGroups
          .any((group) => group.groupId == nextSelectedGroupId);
      if (!hasSelectedGroup) {
        nextSelectedGroupId = BookshelfBookGroup.idAll;
      }
      setState(() {
        _bookGroups = normalizedGroups;
        _bookGroupMembershipMap = groupMembership;
        _selectedGroupId = nextSelectedGroupId;
        _selectedGroupTitle = resolveBookshelfManageGroupTitleById(
          nextSelectedGroupId,
          _bookGroups,
        );
      });
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'bookshelf_manage.menu_book_group.load',
        message: '书架管理加载分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!showError || !mounted) return;
      _showMessage('加载分组失败：$error');
    }
  }

  List<Book> get _filteredBooks => filterBookshelfManageDisplayBooks(
        allBooks: _allBooks,
        selectedGroupId: _selectedGroupId,
        groups: _bookGroups,
        membership: _bookGroupMembershipMap,
        searchText: _searchText,
        resolveSourceLabel: _resolveSourceDisplayName,
      );

  List<Book> _collectSelectedBooksFromCurrentView(List<Book> visibleBooks) {
    if (_selectedBookIds.isEmpty || visibleBooks.isEmpty) {
      return const <Book>[];
    }
    return visibleBooks
        .where((book) => _selectedBookIds.contains(book.id))
        .toList(growable: false);
  }

  String _resolveSourceDisplayName(Book book) =>
      resolveBookshelfManageSourceDisplayName(
        book: book,
        sourceRepository: _sourceRepository,
      );

  void _pruneInvalidSelection() {
    final exists = _allBooks.map((book) => book.id).toSet();
    _selectedBookIds.removeWhere((id) => !exists.contains(id));
  }

  void _toggleBookSelection(String bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  void _clearAllSelection() {
    setState(_selectedBookIds.clear);
  }

  void _clearVisibleSelection(List<Book> books) {
    setState(() {
      for (final book in books) {
        _selectedBookIds.remove(book.id);
      }
    });
  }

  void _selectVisibleBooks(List<Book> books) {
    setState(() {
      for (final book in books) {
        _selectedBookIds.add(book.id);
      }
    });
  }

  void _checkSelectedInterval(List<Book> visibleBooks) {
    setState(() {
      checkBookshelfManageSelectedInterval(
        visibleBooks: visibleBooks,
        selectedBookIds: _selectedBookIds,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = _filteredBooks;
    final selectedBooks = _collectSelectedBooksFromCurrentView(filteredBooks);
    final selectedCount = selectedBooks.length;
    final allVisibleSelected =
        filteredBooks.isNotEmpty && selectedCount == filteredBooks.length;
    final selectionDisabled = selectedCount == 0 || _selectionBlocked;

    return AppCupertinoPageScaffold(
      title: '书架管理',
      trailing: BookshelfManageTopActions(
        disableNavActions: _disableNavActions,
        busy: _isExporting || _selectionBlocked,
        onShowGroupMenu: () => unawaited(_showBookGroupMenu()),
        onShowMoreMenu: _showMoreMenu,
      ),
      child: BookshelfManageBody(
        searchController: _searchController,
        selectedGroupTitle: _selectedGroupTitle,
        onSearchChanged: (value) => setState(() => _searchText = value),
        filteredBooks: filteredBooks,
        allBooks: _allBooks,
        selectedCount: selectedCount,
        allVisibleSelected: allVisibleSelected,
        changingSource: _isBatchChangingSource,
        clearingCache: _isClearingCache,
        updatingCanUpdate: _isUpdatingCanUpdate,
        addingToGroup: _isAddingToGroup,
        deletingSelection: _isDeletingSelection,
        selectionBlocked: _selectionBlocked,
        openBookInfoByClickTitle: _openBookInfoByClickTitle,
        selectedBookIds: _selectedBookIds,
        resolveSourceLabel: _resolveSourceDisplayName,
        onToggleSelectAll: filteredBooks.isEmpty
            ? null
            : () {
                if (allVisibleSelected) {
                  _clearVisibleSelection(filteredBooks);
                } else {
                  _selectVisibleBooks(filteredBooks);
                }
              },
        onClearSelection: selectedCount == 0 ? null : _clearAllSelection,
        onBatchChangeSource:
            selectionDisabled ? null : _handleBatchChangeSource,
        onClearCache: selectionDisabled ? null : _handleClearCache,
        onDeleteSelection: selectionDisabled ? null : _handleDeleteSelection,
        onEnableUpdate: selectionDisabled
            ? null
            : () => _handleSetCanUpdate(
                  canUpdate: true,
                  node: 'bookshelf_manage.menu_update_enable',
                  actionLabel: '允许更新',
                ),
        onDisableUpdate: selectionDisabled
            ? null
            : () => _handleSetCanUpdate(
                  canUpdate: false,
                  node: 'bookshelf_manage.menu_update_disable',
                  actionLabel: '禁止更新',
                ),
        onAddToGroup: selectionDisabled ? null : _handleAddToGroup,
        onCheckSelectedInterval: selectionDisabled
            ? null
            : () => _checkSelectedInterval(filteredBooks),
        onToggleBookSelection: _toggleBookSelection,
        onOpenBookInfo: (book) => unawaited(_openBookInfo(book)),
      ),
    );
  }

  Future<void> _showBookGroupMenu() async {
    await _reloadBookGroupContext(showError: true);
    if (!mounted) return;
    final outcome = await showBookshelfManageGroupChooser(
      context: context,
      groups: _bookGroups,
      currentGroupId: _selectedGroupId,
    );
    if (!mounted) return;
    if (outcome.openGroupManage) {
      await showCupertinoBottomSheetDialog<void>(
        context: context,
        builder: (_) => const BookshelfGroupManagePlaceholderDialog(),
      );
      if (!mounted) return;
      await _reloadBookGroupContext(showError: false);
      return;
    }
    final nextGroupId = outcome.selectedGroupId;
    if (nextGroupId == null || nextGroupId == _selectedGroupId) return;
    setState(() {
      _selectedGroupId = nextGroupId;
      _selectedGroupTitle = resolveBookshelfManageGroupTitleById(
        nextGroupId,
        _bookGroups,
      );
    });
  }

  void _showMoreMenu() {
    showBookshelfManageMoreMenu(
      context: context,
      openBookInfoByClickTitle: _openBookInfoByClickTitle,
      onToggleOpenBookInfoByClickTitle: () async {
        final nextValue = !_openBookInfoByClickTitle;
        setState(() => _openBookInfoByClickTitle = nextValue);
        await _settingsService.saveOpenBookInfoByClickTitle(nextValue);
      },
      onExportAllUsedBookSources: () =>
          unawaited(_exportAllUsedBookSources()),
    );
  }

  Future<void> _openBookInfo(Book book) {
    return Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
  }

  Future<void> _handleBatchChangeSource() async {
    if (_selectionBlocked) return;
    final selected = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selected.isEmpty) return _showMessage('请先选择书籍');
    final targetSource = await pickBookshelfManageTargetSource(
      context: context,
      sourceRepository: _sourceRepository,
      settingsService: _settingsService,
      onMessage: _showMessage,
    );
    if (!mounted || targetSource == null) return;
    setState(() => _isBatchChangingSource = true);
    try {
      await executeBookshelfManageBatchChangeSource(
        context: context,
        service: _batchChangeSourceService,
        exceptionLogService: _exceptionLogService,
        books: selected,
        targetSource: targetSource,
        onMessage: _showMessage,
      );
    } finally {
      if (mounted) setState(() => _isBatchChangingSource = false);
    }
  }

  Future<void> _handleClearCache() async {
    if (_isClearingCache) return;
    final selected = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selected.isEmpty) return _showMessage('请先选择书籍');
    setState(() => _isClearingCache = true);
    final result = await clearBookshelfManageBookCache(
      chapterRepository: _chapterRepository,
      exceptionLogService: _exceptionLogService,
      selectedBooks: selected,
    );
    if (!mounted) return;
    setState(() => _isClearingCache = false);
    _showMessage(result.success ? '成功清理缓存' : (result.errorMessage ?? '清理缓存出错'));
  }

  Future<void> _handleSetCanUpdate({
    required bool canUpdate,
    required String node,
    required String actionLabel,
  }) async {
    if (_isUpdatingCanUpdate) return;
    final selected = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selected.isEmpty) return _showMessage('请先选择书籍');
    setState(() => _isUpdatingCanUpdate = true);
    final error = await setBookshelfManageCanUpdate(
      settingsService: _settingsService,
      exceptionLogService: _exceptionLogService,
      selectedBooks: selected,
      canUpdate: canUpdate,
      node: node,
      actionLabel: actionLabel,
    );
    if (!mounted) return;
    setState(() => _isUpdatingCanUpdate = false);
    if (error != null) _showMessage(error);
  }

  Future<void> _handleAddToGroup() async {
    if (_isAddingToGroup) return;
    final selectedBooks = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selectedBooks.isEmpty) {
      _showMessage('请先选择书籍');
      return;
    }
    await _reloadBookGroupContext(showError: true);
    if (!mounted) return;
    final selectedGroupBits = await pickBookshelfManageGroupBits(
      context: context,
      groups: _bookGroups,
      onMessage: _showMessage,
    );
    if (!mounted || selectedGroupBits == null || selectedGroupBits == 0) return;
    setState(() => _isAddingToGroup = true);
    final next = await addBookshelfManageBooksToGroup(
      database: _database,
      exceptionLogService: _exceptionLogService,
      currentMembership: _bookGroupMembershipMap,
      selectedBooks: selectedBooks,
      selectedGroupBits: selectedGroupBits,
      onError: _showMessage,
    );
    if (!mounted) return;
    setState(() {
      _bookGroupMembershipMap = next;
      _isAddingToGroup = false;
    });
  }

  Future<void> _handleDeleteSelection() async {
    if (_isDeletingSelection) return;
    final selectedBooks = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selectedBooks.isEmpty) {
      _showMessage('请先选择书籍');
      return;
    }
    final deleteOriginal = await confirmBookshelfManageDeleteSelection(
      context: context,
      initialDeleteOriginal: _settingsService.getDeleteBookOriginal(),
    );
    if (!mounted || deleteOriginal == null) return;
    await _settingsService.saveDeleteBookOriginal(deleteOriginal);
    setState(() => _isDeletingSelection = true);
    final deletedBookIds = await deleteBookshelfManageSelectedBooks(
      bookRepository: _bookRepository,
      exceptionLogService: _exceptionLogService,
      selectedBooks: selectedBooks,
      deleteOriginal: deleteOriginal,
      onFailureReport: (reason) => _showMessage('删除出错\n$reason'),
    );
    if (!mounted) return;
    setState(() {
      _selectedBookIds.removeWhere((id) => deletedBookIds.contains(id));
      _isDeletingSelection = false;
    });
  }

  Future<void> _exportAllUsedBookSources() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await exportAllUsedBookshelfManageBookSources(
        context: context,
        exportService: _exportService,
        sourceImportExportService: _sourceImportExportService,
        onMessage: _showMessage,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMessage(String message) {
    showBookshelfManageMessage(context, message);
  }
}
