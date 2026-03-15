import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_import_export_service.dart';
import '../../search/views/search_book_info_view.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import '../services/bookshelf_book_group_store.dart';
import '../services/bookshelf_manage_batch_change_source_service.dart';
import '../services/bookshelf_manage_export_service.dart';
import 'bookshelf_group_manage_placeholder_dialog.dart';
import 'bookshelf_manage_widgets.dart';

/// 书架管理承载页（对应 legado: menu_bookshelf_manage -> BookshelfManageActivity）。
///
/// 当前已收敛：
/// - `menu_export_all_use_book_source`（导出所有书的书源）
/// - `menu_book_group`（分组）
/// - `menu_group_manage`（分组管理）
/// - `menu_change_source`（多选后批量换源）
/// - `menu_clear_cache`（多选后批量清理缓存）
/// - `menu_del_selection`（多选后删除）
/// - `menu_update_enable`（多选后允许更新）
/// - `menu_update_disable`（多选后禁止更新）
/// - `menu_add_to_group`（多选后加入分组）
/// - `menu_check_selected_interval`（选中所选区间）
///
/// 其余 `bookshelf_manage.xml / bookshelf_menage_sel.xml` 动作按后续序号推进。
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
  static const String _bookGroupMembershipSettingKey =
      'bookshelf.book_group_membership_map';
  static const List<BookshelfBookGroup> _defaultBookGroups =
      <BookshelfBookGroup>[
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idAll,
      groupName: '全部',
      show: true,
      order: -10,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idLocal,
      groupName: '本地',
      show: true,
      order: -9,
      bookSort: -1,
      enableRefresh: false,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idAudio,
      groupName: '音频',
      show: true,
      order: -8,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idNetNone,
      groupName: '网络未分组',
      show: true,
      order: -7,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idLocalNone,
      groupName: '本地未分组',
      show: false,
      order: -6,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idError,
      groupName: '更新失败',
      show: true,
      order: -1,
      bookSort: -1,
      enableRefresh: true,
    ),
  ];

  late final DatabaseService _database;
  late final BookRepository _bookRepository;
  late final ChapterRepository _chapterRepository;
  late final SourceRepository _sourceRepository;
  late final BookshelfBookGroupStore _bookGroupStore;
  late final SourceImportExportService _sourceImportExportService;
  late final BookshelfManageExportService _exportService;
  late final RuleParserEngine _ruleEngine;
  late final SettingsService _settingsService;
  late final ExceptionLogService _exceptionLogService;
  late final BookshelfManageBatchChangeSourceService _batchChangeSourceService;

  StreamSubscription<List<Book>>? _bookSubscription;
  List<Book> _allBooks = const <Book>[];
  List<BookshelfBookGroup> _bookGroups = _defaultBookGroups;
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
    _ruleEngine = RuleParserEngine();
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
      ruleEngine: _ruleEngine,
      settingsService: _settingsService,
      exceptionLogService: _exceptionLogService,
    );
    _openBookInfoByClickTitle = _settingsService.getOpenBookInfoByClickTitle();

    _allBooks = _sortBooksForManage(_bookRepository.getAllBooks());
    final initialGroupId = widget.initialGroupId;
    if (initialGroupId != null && initialGroupId != BookshelfBookGroup.idRoot) {
      _selectedGroupId = initialGroupId;
    }
    unawaited(_reloadBookGroupContext(showError: false));
    _bookSubscription = _bookRepository.watchAllBooks().listen((books) {
      if (!mounted) return;
      setState(() {
        _allBooks = _sortBooksForManage(books);
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

  @override
  Widget build(BuildContext context) {
    final filteredBooks = _filteredBooks;
    final selectedBooks = _collectSelectedBooksFromCurrentView(filteredBooks);
    final selectedCount = selectedBooks.length;
    final allVisibleSelected =
        filteredBooks.isNotEmpty && selectedCount == filteredBooks.length;
    final disableNavActions = _isExporting ||
        _isBatchChangingSource ||
        _isClearingCache ||
        _isDeletingSelection ||
        _isUpdatingCanUpdate ||
        _isAddingToGroup;

    return AppCupertinoPageScaffold(
      title: '书架管理',
      trailing: _buildTopActions(disableNavActions: disableNavActions),
      child: Column(
        children: [
          Padding(
            padding: AppManageSearchField.outerPadding,
            child: AppManageSearchField(
              controller: _searchController,
              placeholder: '筛选 • $_selectedGroupTitle',
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: SelectionSummaryBar(
              selectedCount: selectedCount,
              totalCount: filteredBooks.length,
              allVisibleSelected: allVisibleSelected,
              changingSource: _isBatchChangingSource,
              clearingCache: _isClearingCache,
              updatingCanUpdate: _isUpdatingCanUpdate,
              addingToGroup: _isAddingToGroup,
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
              onBatchChangeSource: selectedCount == 0 ||
                      _isBatchChangingSource ||
                      _isClearingCache ||
                      _isDeletingSelection ||
                      _isUpdatingCanUpdate ||
                      _isAddingToGroup
                  ? null
                  : _handleBatchChangeSource,
              onClearCache: selectedCount == 0 ||
                      _isBatchChangingSource ||
                      _isClearingCache ||
                      _isDeletingSelection ||
                      _isUpdatingCanUpdate ||
                      _isAddingToGroup
                  ? null
                  : _handleClearCache,
              onDeleteSelection: selectedCount == 0 ||
                      _isBatchChangingSource ||
                      _isClearingCache ||
                      _isDeletingSelection ||
                      _isUpdatingCanUpdate ||
                      _isAddingToGroup
                  ? null
                  : _handleDeleteSelection,
              onEnableUpdate: selectedCount == 0 ||
                      _isBatchChangingSource ||
                      _isClearingCache ||
                      _isDeletingSelection ||
                      _isUpdatingCanUpdate ||
                      _isAddingToGroup
                  ? null
                  : _handleEnableUpdate,
              onDisableUpdate: selectedCount == 0 ||
                      _isBatchChangingSource ||
                      _isClearingCache ||
                      _isDeletingSelection ||
                      _isUpdatingCanUpdate ||
                      _isAddingToGroup
                  ? null
                  : _handleDisableUpdate,
              onAddToGroup: selectedCount == 0 ||
                      _isBatchChangingSource ||
                      _isClearingCache ||
                      _isDeletingSelection ||
                      _isUpdatingCanUpdate ||
                      _isAddingToGroup
                  ? null
                  : _handleAddToGroup,
              onCheckSelectedInterval: selectedCount == 0 ||
                      _isBatchChangingSource ||
                      _isClearingCache ||
                      _isDeletingSelection ||
                      _isUpdatingCanUpdate ||
                      _isAddingToGroup
                  ? null
                  : () => _checkSelectedInterval(filteredBooks),
              deletingSelection: _isDeletingSelection,
            ),
          ),
          Expanded(
            child: filteredBooks.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredBooks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      final selected = _selectedBookIds.contains(book.id);
                      return BookSelectionTile(
                        book: book,
                        selected: selected,
                        sourceLabel: _resolveSourceDisplayName(book),
                        titleTapOpensDetail: _openBookInfoByClickTitle,
                        onTitleTap: _isBatchChangingSource ||
                                _isClearingCache ||
                                _isDeletingSelection ||
                                _isUpdatingCanUpdate ||
                                _isAddingToGroup
                            ? null
                            : _openBookInfoByClickTitle
                                ? () => unawaited(_openBookInfo(book))
                                : null,
                        onTap: _isBatchChangingSource ||
                                _isClearingCache ||
                                _isDeletingSelection ||
                                _isUpdatingCanUpdate ||
                                _isAddingToGroup
                            ? null
                            : () => _toggleBookSelection(book.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<Book> _collectSelectedBooksFromCurrentView(List<Book> visibleBooks) {
    if (_selectedBookIds.isEmpty || visibleBooks.isEmpty) {
      return const <Book>[];
    }
    return visibleBooks
        .where((book) => _selectedBookIds.contains(book.id))
        .toList(growable: false);
  }

  List<Book> get _filteredBooks {
    final groupedBooks = _filterBooksByGroup(_allBooks, _selectedGroupId);
    final keyword = _searchText.trim().toLowerCase();
    if (keyword.isEmpty) return groupedBooks;
    return groupedBooks.where((book) {
      final title = book.title.toLowerCase();
      final author = book.author.toLowerCase();
      final sourceName = _resolveSourceDisplayName(book).toLowerCase();
      return title.contains(keyword) ||
          author.contains(keyword) ||
          sourceName.contains(keyword);
    }).toList(growable: false);
  }

  Future<void> _reloadBookGroupContext({required bool showError}) async {
    try {
      final groups = await _bookGroupStore.getGroups();
      if (!mounted) return;
      final normalizedGroups = _normalizeGroups(groups);
      final groupMembership = _readBookGroupMembershipMap();
      var nextSelectedGroupId = _selectedGroupId;
      final hasSelectedGroup =
          normalizedGroups.any((group) => group.groupId == nextSelectedGroupId);
      if (!hasSelectedGroup) {
        nextSelectedGroupId = BookshelfBookGroup.idAll;
      }
      setState(() {
        _bookGroups = normalizedGroups;
        _bookGroupMembershipMap = groupMembership;
        _selectedGroupId = nextSelectedGroupId;
        _selectedGroupTitle = _resolveGroupTitleById(nextSelectedGroupId);
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

  List<BookshelfBookGroup> _normalizeGroups(List<BookshelfBookGroup> groups) {
    final byId = <int, BookshelfBookGroup>{
      for (final group in groups) group.groupId: group,
    };
    for (final fallback in _defaultBookGroups) {
      byId.putIfAbsent(fallback.groupId, () => fallback);
    }
    final normalized = byId.values.toList(growable: false);
    normalized.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
    return normalized;
  }

  Map<String, int> _readBookGroupMembershipMap() {
    final raw = _database.getSetting(
      _bookGroupMembershipSettingKey,
      defaultValue: const <String, dynamic>{},
    );
    if (raw is! Map) return const <String, int>{};
    final parsed = <String, int>{};
    raw.forEach((key, value) {
      final bookId = '$key'.trim();
      if (bookId.isEmpty) return;
      parsed[bookId] = _parseGroupBits(value);
    });
    return parsed;
  }

  int _parseGroupBits(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  String _resolveGroupTitleById(int groupId) {
    for (final group in _bookGroups) {
      if (group.groupId == groupId) {
        return group.groupName;
      }
    }
    switch (groupId) {
      case BookshelfBookGroup.idAll:
        return '全部';
      case BookshelfBookGroup.idLocal:
        return '本地';
      case BookshelfBookGroup.idAudio:
        return '音频';
      case BookshelfBookGroup.idNetNone:
        return '网络未分组';
      case BookshelfBookGroup.idLocalNone:
        return '本地未分组';
      case BookshelfBookGroup.idError:
        return '更新失败';
      default:
        return '未分组';
    }
  }

  int _resolveCustomGroupMask() {
    var mask = 0;
    for (final group in _bookGroups) {
      if (group.groupId > 0) {
        mask |= group.groupId;
      }
    }
    return mask;
  }

  List<Book> _filterBooksByGroup(List<Book> books, int groupId) {
    switch (groupId) {
      case BookshelfBookGroup.idAll:
        return books;
      case BookshelfBookGroup.idLocal:
        return books.where((book) => book.isLocal).toList(growable: false);
      case BookshelfBookGroup.idAudio:
      case BookshelfBookGroup.idError:
        // 当前模型未承载 legado 音频/更新失败类型位，保持入口但回落空集。
        return const <Book>[];
      case BookshelfBookGroup.idNetNone:
        final customMask = _resolveCustomGroupMask();
        return books.where((book) {
          if (book.isLocal) return false;
          final membership = _bookGroupMembershipMap[book.id] ?? 0;
          return (membership & customMask) == 0;
        }).toList(growable: false);
      case BookshelfBookGroup.idLocalNone:
        final customMask = _resolveCustomGroupMask();
        return books.where((book) {
          if (!book.isLocal) return false;
          final membership = _bookGroupMembershipMap[book.id] ?? 0;
          return (membership & customMask) == 0;
        }).toList(growable: false);
      default:
        if (groupId == BookshelfBookGroup.longMinValue) {
          return books.where((book) {
            final membership = _bookGroupMembershipMap[book.id] ?? 0;
            return membership == groupId;
          }).toList(growable: false);
        }
        if (groupId > 0) {
          return books.where((book) {
            final membership = _bookGroupMembershipMap[book.id] ?? 0;
            return (membership & groupId) > 0;
          }).toList(growable: false);
        }
        return const <Book>[];
    }
  }

  List<Book> _sortBooksForManage(List<Book> books) {
    final list = List<Book>.from(books);
    final sortIndex = _settingsService.appSettings.bookshelfSortIndex;

    int compareDateTimeDesc(DateTime? a, DateTime? b) {
      final aTime = a ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    }

    DateTime? maxDate(DateTime? a, DateTime? b) {
      if (a == null) return b;
      if (b == null) return a;
      return a.isAfter(b) ? a : b;
    }

    final normalizedSort = sortIndex.clamp(0, 5);
    if (normalizedSort == 3) {
      // 手动排序依赖遗留 order 字段，当前模型未迁移该字段，保持数据库顺序。
      return list;
    }

    list.sort((a, b) {
      switch (normalizedSort) {
        case 0:
          return compareDateTimeDesc(
            a.lastReadTime ?? a.addedTime,
            b.lastReadTime ?? b.addedTime,
          );
        case 1:
          return compareDateTimeDesc(a.addedTime, b.addedTime);
        case 2:
          return a.title.compareTo(b.title);
        case 4:
          return compareDateTimeDesc(
            maxDate(a.lastReadTime, a.addedTime),
            maxDate(b.lastReadTime, b.addedTime),
          );
        case 5:
          return a.author.compareTo(b.author);
        default:
          return 0;
      }
    });

    return list;
  }

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
    setState(() => _selectedBookIds.clear());
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
    if (_selectedBookIds.isEmpty || visibleBooks.isEmpty) {
      return;
    }

    int? minIndex;
    int? maxIndex;
    for (var i = 0; i < visibleBooks.length; i++) {
      if (!_selectedBookIds.contains(visibleBooks[i].id)) {
        continue;
      }
      minIndex = minIndex == null || i < minIndex ? i : minIndex;
      maxIndex = maxIndex == null || i > maxIndex ? i : maxIndex;
    }
    if (minIndex == null || maxIndex == null) {
      return;
    }

    setState(() {
      for (var i = minIndex!; i <= maxIndex!; i++) {
        _selectedBookIds.add(visibleBooks[i].id);
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        _allBooks.isEmpty ? '书架暂无书籍' : '没有匹配的书籍',
        style: TextStyle(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  String _resolveSourceDisplayName(Book book) {
    if (book.isLocal) return '本地书籍';
    final sourceUrl = (book.sourceUrl ?? book.sourceId ?? '').trim();
    if (sourceUrl.isEmpty) return '未知书源';
    final source = _sourceRepository.getSourceByUrl(sourceUrl);
    if (source == null) return '未知书源';
    final group = (source.bookSourceGroup ?? '').trim();
    if (group.isEmpty) return source.bookSourceName;
    return '${source.bookSourceName} · $group';
  }

  Widget _buildTopActions({required bool disableNavActions}) {
    final busy = _isExporting ||
        _isBatchChangingSource ||
        _isClearingCache ||
        _isDeletingSelection ||
        _isUpdatingCanUpdate ||
        _isAddingToGroup;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: disableNavActions
              ? null
              : () {
                  unawaited(_showBookGroupMenu());
                },
          child: const Icon(CupertinoIcons.square_grid_2x2, size: 22),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: disableNavActions ? null : _showMoreMenu,
          child: busy
              ? const CupertinoActivityIndicator(radius: 8)
              : const Icon(CupertinoIcons.ellipsis_circle, size: 22),
        ),
      ],
    );
  }

  Future<void> _showBookGroupMenu() async {
    await _reloadBookGroupContext(showError: true);
    if (!mounted) return;
    final options = _bookGroups.toList(growable: false)
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) return byOrder;
        return a.groupId.compareTo(b.groupId);
      });
    var openGroupManage = false;
    int? selectedGroupId;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (popupContext) {
        return CupertinoActionSheet(
          title: const Text('分组'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                openGroupManage = true;
                Navigator.of(popupContext).pop();
              },
              child: const Text('分组管理'),
            ),
            ...options.map(
              (group) => CupertinoActionSheetAction(
                onPressed: () {
                  selectedGroupId = group.groupId;
                  Navigator.of(popupContext).pop();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedGroupId == group.groupId)
                      const Icon(CupertinoIcons.check_mark, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 6),
                    Text(group.groupName),
                  ],
                ),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (!mounted) return;
    if (openGroupManage) {
      await _openGroupManageDialog();
      if (!mounted) return;
      await _reloadBookGroupContext(showError: false);
      return;
    }
    if (selectedGroupId == null) return;
    if (selectedGroupId == _selectedGroupId) return;
    final nextGroupId = selectedGroupId!;
    setState(() {
      _selectedGroupId = nextGroupId;
      _selectedGroupTitle = _resolveGroupTitleById(nextGroupId);
    });
  }

  Future<void> _openGroupManageDialog() {
    return showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (_) => const BookshelfGroupManagePlaceholderDialog(),
    );
  }

  void _showMoreMenu() {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (popupContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                unawaited(_toggleOpenBookInfoByClickTitle());
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_openBookInfoByClickTitle)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  const Text('点击书名打开详情'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                unawaited(_exportAllUsedBookSources());
              },
              child: const Text('导出所有书的书源'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _toggleOpenBookInfoByClickTitle() async {
    final nextValue = !_openBookInfoByClickTitle;
    setState(() {
      _openBookInfoByClickTitle = nextValue;
    });
    await _settingsService.saveOpenBookInfoByClickTitle(nextValue);
  }

  Future<void> _openBookInfo(Book book) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
  }

  Future<void> _handleBatchChangeSource() async {
    if (_isBatchChangingSource ||
        _isClearingCache ||
        _isDeletingSelection ||
        _isUpdatingCanUpdate ||
        _isAddingToGroup) {
      return;
    }
    final selectedBooks = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selectedBooks.isEmpty) {
      _showMessage('请先选择书籍');
      return;
    }

    final targetSource = await _pickTargetSource();
    if (!mounted || targetSource == null) return;

    await _executeBatchChangeSource(
      books: selectedBooks,
      targetSource: targetSource,
    );
  }

  Future<void> _handleClearCache() async {
    if (_isClearingCache) return;
    final selectedBooks = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selectedBooks.isEmpty) {
      _showMessage('请先选择书籍');
      return;
    }

    setState(() => _isClearingCache = true);
    try {
      await _chapterRepository.clearDownloadedCacheForBooks(
        selectedBooks.map((book) => book.id),
      );
      if (!mounted) return;
      _showMessage('成功清理缓存');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'bookshelf_manage.menu_clear_cache',
        message: '书架管理批量清理缓存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selectedBooks.length,
          'bookIds': selectedBooks.map((book) => book.id).toList(),
        },
      );
      if (!mounted) return;
      _showMessage('清理缓存出错\n${_compactReason(error.toString())}');
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  Future<void> _handleEnableUpdate() async {
    await _handleSetCanUpdate(
      canUpdate: true,
      node: 'bookshelf_manage.menu_update_enable',
      actionLabel: '允许更新',
    );
  }

  Future<void> _handleDisableUpdate() async {
    await _handleSetCanUpdate(
      canUpdate: false,
      node: 'bookshelf_manage.menu_update_disable',
      actionLabel: '禁止更新',
    );
  }

  Future<void> _handleSetCanUpdate({
    required bool canUpdate,
    required String node,
    required String actionLabel,
  }) async {
    if (_isUpdatingCanUpdate) return;
    final selectedBooks = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selectedBooks.isEmpty) {
      _showMessage('请先选择书籍');
      return;
    }

    setState(() => _isUpdatingCanUpdate = true);
    try {
      await _settingsService.saveBooksCanUpdate(
        selectedBooks.map((book) => book.id),
        canUpdate,
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: node,
        message: '书架管理${actionLabel}批量设置失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selectedBooks.length,
          'bookIds': selectedBooks.map((book) => book.id).toList(),
          'canUpdate': canUpdate,
        },
      );
      if (!mounted) return;
      _showMessage('$actionLabel出错\n${_compactReason(error.toString())}');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingCanUpdate = false);
      }
    }
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
    final selectableGroups =
        _bookGroups.where((group) => group.groupId >= 0).toList(growable: false)
          ..sort((a, b) {
            final byOrder = a.order.compareTo(b.order);
            if (byOrder != 0) return byOrder;
            return a.groupId.compareTo(b.groupId);
          });
    if (selectableGroups.isEmpty) {
      _showMessage('暂无可选分组，请先在分组管理中添加');
      return;
    }

    final selectedGroupBits = await showCupertinoBottomSheetDialog<int>(
      context: context,
      builder: (_) => BookshelfManageGroupSelectDialog(
        groups: selectableGroups,
        initialGroupBits: 0,
      ),
    );
    if (!mounted || selectedGroupBits == null || selectedGroupBits == 0) return;

    setState(() => _isAddingToGroup = true);
    try {
      final nextMembership = Map<String, int>.from(_bookGroupMembershipMap);
      for (final book in selectedBooks) {
        final currentBits = nextMembership[book.id] ?? 0;
        nextMembership[book.id] = currentBits | selectedGroupBits;
      }
      await _database.putSetting(
        _bookGroupMembershipSettingKey,
        nextMembership,
      );
      if (!mounted) return;
      setState(() {
        _bookGroupMembershipMap = nextMembership;
      });
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'bookshelf_manage.menu_add_to_group',
        message: '书架管理加入分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selectedBooks.length,
          'bookIds': selectedBooks.map((book) => book.id).toList(),
          'selectedGroupBits': selectedGroupBits,
        },
      );
      if (!mounted) return;
      _showMessage('加入分组出错\n${_compactReason(error.toString())}');
    } finally {
      if (mounted) {
        setState(() => _isAddingToGroup = false);
      }
    }
  }

  Future<void> _handleDeleteSelection() async {
    if (_isDeletingSelection) return;
    final selectedBooks = _collectSelectedBooksFromCurrentView(_filteredBooks);
    if (selectedBooks.isEmpty) {
      _showMessage('请先选择书籍');
      return;
    }

    final deleteOriginal = await _confirmDeleteSelection();
    if (!mounted || deleteOriginal == null) return;
    await _settingsService.saveDeleteBookOriginal(deleteOriginal);

    setState(() => _isDeletingSelection = true);
    final deletedBookIds = <String>{};
    final deleteFailedReasons = <String>[];
    try {
      for (final book in selectedBooks) {
        try {
          await _bookRepository.deleteBook(book.id);
          deletedBookIds.add(book.id);
          if (book.isLocal) {
            await _deleteLocalBookArtifacts(
              book: book,
              deleteOriginal: deleteOriginal,
            );
          }
        } catch (error, stackTrace) {
          deleteFailedReasons.add(error.toString());
          _exceptionLogService.record(
            node: 'bookshelf_manage.menu_del_selection.delete_book',
            message: '书架管理删除所选书籍失败',
            error: error,
            stackTrace: stackTrace,
            context: <String, dynamic>{
              'bookId': book.id,
              'bookTitle': book.title,
              'deleteOriginal': deleteOriginal,
            },
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedBookIds
            .removeWhere((bookId) => deletedBookIds.contains(bookId));
      });
      if (deleteFailedReasons.isNotEmpty) {
        _showMessage('删除出错\n${_compactReason(deleteFailedReasons.first)}');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingSelection = false);
      }
    }
  }

  Future<bool?> _confirmDeleteSelection() async {
    var deleteOriginal = _settingsService.getDeleteBookOriginal();
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('提醒'),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('是否确认删除？'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '删除源文件',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        CupertinoSwitch(
                          value: deleteOriginal,
                          onChanged: (value) {
                            setDialogState(() {
                              deleteOriginal = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return null;
    return deleteOriginal;
  }

  Future<void> _deleteLocalBookArtifacts({
    required Book book,
    required bool deleteOriginal,
  }) async {
    final coverPath = _normalizeLocalFilePath(book.coverUrl);
    await _deleteFileIfExists(
      book: book,
      filePath: coverPath,
      nodeSuffix: 'delete_cover',
    );
    if (!deleteOriginal) return;

    final localPath = _normalizeLocalFilePath(book.localPath);
    final originalPath = localPath ?? _normalizeLocalFilePath(book.bookUrl);
    await _deleteFileIfExists(
      book: book,
      filePath: originalPath,
      nodeSuffix: 'delete_original',
    );
  }

  String? _normalizeLocalFilePath(String? rawValue) {
    final raw = (rawValue ?? '').trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    if (!uri.hasScheme) return raw;
    if (uri.scheme.toLowerCase() == 'file') {
      try {
        final filePath = uri.toFilePath();
        final normalized = filePath.trim();
        if (normalized.isEmpty) return null;
        return normalized;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _deleteFileIfExists({
    required Book book,
    required String? filePath,
    required String nodeSuffix,
  }) async {
    final normalizedPath = (filePath ?? '').trim();
    if (normalizedPath.isEmpty) return;
    try {
      final file = File(normalizedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'bookshelf_manage.menu_del_selection.$nodeSuffix',
        message: '书架管理删除本地文件失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': book.id,
          'bookTitle': book.title,
          'filePath': normalizedPath,
        },
      );
    }
  }

  Future<BookSource?> _pickTargetSource() async {
    final enabledSources = _sourceRepository
        .getAllSources()
        .where((source) => source.enabled)
        .toList(growable: false);
    if (enabledSources.isEmpty) {
      _showMessage('当前没有可用书源');
      return null;
    }
    enabledSources.sort((a, b) {
      final orderCompare = a.customOrder.compareTo(b.customOrder);
      if (orderCompare != 0) return orderCompare;
      return a.bookSourceName.compareTo(b.bookSourceName);
    });

    return Navigator.of(context, rootNavigator: true).push<BookSource>(
      CupertinoPageRoute<BookSource>(
        builder: (_) => BookshelfManageSourcePickerView(
          sources: enabledSources,
          initialDelaySeconds: _settingsService.getBatchChangeSourceDelay(),
          onDelayChanged: (seconds) =>
              _settingsService.saveBatchChangeSourceDelay(seconds),
        ),
      ),
    );
  }

  Future<void> _executeBatchChangeSource({
    required List<Book> books,
    required BookSource targetSource,
  }) async {
    final progressText = ValueNotifier<String>('批量换源');
    final cancelToken = CancelToken();
    var dialogVisible = true;

    setState(() => _isBatchChangingSource = true);
    final dialogFuture = showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ValueListenableBuilder<String>(
          valueListenable: progressText,
          builder: (_, text, __) {
            return CupertinoAlertDialog(
              title: const Text('批量换源'),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(height: 8),
                    Text(text),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () {
                    if (!cancelToken.isCancelled) {
                      cancelToken.cancel('用户取消批量换源');
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      dialogVisible = false;
    });

    try {
      await _batchChangeSourceService.changeSource(
        books: books,
        targetSource: targetSource,
        cancelToken: cancelToken,
        onProgress: (progress) {
          progressText.value = progress.progressText;
        },
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'bookshelf_manage.menu_change_source.run',
        message: '批量换源执行失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': books.length,
          'targetSourceUrl': targetSource.bookSourceUrl,
          'targetSourceName': targetSource.bookSourceName,
        },
      );
      if (mounted) {
        _showMessage('批量换源失败：$error');
      }
    } finally {
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await dialogFuture;
      progressText.dispose();
      if (mounted) {
        setState(() => _isBatchChangingSource = false);
      }
    }
  }

  Future<void> _exportAllUsedBookSources() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });
    try {
      final sources = _exportService.collectAllUsedBookSources();
      final result = await _sourceImportExportService.exportToFile(
        sources,
        defaultFileName: 'bookSource.json',
      );
      if (!mounted) return;
      if (result.cancelled) return;
      if (!result.success) {
        _showMessage(result.errorMessage ?? '导出失败');
        return;
      }
      final outputPath = (result.outputPath ?? '').trim();
      if (outputPath.isEmpty) {
        unawaited(showAppToast(context, message: '导出成功'));
        return;
      }
      await _showExportPathDialog(outputPath);
    } catch (error, stackTrace) {
      debugPrint('BookshelfManageExportAllUseBookSourceError: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showMessage('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
    if (path.isEmpty) {
      unawaited(showAppToast(context, message: '导出成功'));
      return;
    }
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('导出成功'),
          content: Text('\n导出路径：\n$path'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                unawaited(showAppToast(context, message: '已复制导出路径'));
              },
              child: const Text('复制路径'),
            ),
          ],
        );
      },
    );
  }

  String _compactReason(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  void _showMessage(String message) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('提示'),
          content: Text('\n$message'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好'),
            ),
          ],
        );
      },
    );
  }
}

