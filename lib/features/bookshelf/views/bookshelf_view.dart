import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../import/book_import_file_name_rule_service.dart';
import '../../import/import_service.dart';
import 'bookshelf_body_widgets.dart';
import 'bookshelf_display_engine.dart';
import 'bookshelf_group_store_engine.dart';
import 'bookshelf_more_menu.dart';
import 'bookshelf_navigation.dart';
import 'bookshelf_sort_layout_engine.dart';
import '../services/book_add_service.dart';
import '../services/bookshelf_book_group_store.dart';
import '../services/bookshelf_booklist_import_service.dart';
import '../services/bookshelf_catalog_update_service.dart';
import '../services/bookshelf_import_export_service.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';

enum ImportFolderAction {
  select,
  create,
}

enum BookshelfMoreMenuAction {
  updateCatalog,
  importLocal,
  remoteBook,
  selectFolder,
  scanFolder,
  importFileNameRule,
  addUrl,
  manage,
  cacheExport,
  groupManage,
  layout,
  exportBooklist,
  importBooklist,
  log,
}

/// 书架页面 - 纯 iOS 原生风格
class BookshelfView extends StatefulWidget {
  final ValueListenable<int>? reselectSignal;

  const BookshelfView({
    super.key,
    this.reselectSignal,
  });

  @override
  State<BookshelfView> createState() => BookshelfViewState();
}

class BookshelfViewState extends State<BookshelfView> {
  static const String bookGroupMembershipSettingKey =
      'bookshelf.book_group_membership_map';
  static const String style1SelectedTabIndexSettingKey =
      'bookshelf.style1_selected_tab_index';
  bool isGridView = true;
  int gridCrossAxisCount = 3;
  // 与 legado 一致：图墙/列表都可展示“更新中”状态。
  final Set<String> updatingBookIds = <String>{};
  final ScrollController scrollController = ScrollController();
  final GlobalKey moreMenuKey = GlobalKey();
  late final DatabaseService database;
  late final BookRepository bookRepo;
  late final SourceRepository sourceRepo;
  late final BookAddService bookAddService;
  late final ImportService importService;
  late final BookImportFileNameRuleService bookImportFileNameRuleService;
  late final BookshelfBookGroupStore bookGroupStore;
  late final SettingsService settingsService;
  late final BookshelfImportExportService bookshelfIo;
  late final BookshelfBooklistImportService booklistImporter;
  late final BookshelfCatalogUpdateService catalogUpdater;
  StreamSubscription<List<Book>>? booksSubscription;
  List<Book> books = [];
  bool isImporting = false;
  bool isSelectingImportFolder = false;
  bool isScanningImportFolder = false;
  bool isAddingByUrl = false;
  bool cancelAddByUrlRequested = false;
  bool isUpdatingCatalog = false;
  String? initError;
  int? lastExternalReselectVersion;
  List<BookshelfBookGroup> bookGroups = defaultBookGroups;
  Map<String, int> bookGroupMembershipMap = const <String, int>{};
  // 与 legado style2 一致：根态是独立的 IdRoot，而不是“全部”分组本身。
  int selectedGroupId = BookshelfBookGroup.idRoot;
  // 与 legado AppConfig.saveTabPosition 对齐：style1 记录分组页签索引。
  int style1SelectedTabIndex = 0;

  // 与 legado 对齐：内置分组的语义和顺序需要稳定保底，避免旧数据缺项导致 UI 行为漂移。
  static const List<BookshelfBookGroup> defaultBookGroups =
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

  @override
  void initState() {
    super.initState();
    try {
      debugPrint('[bookshelf] init start');
      settingsService = SettingsService();
      final db = DatabaseService();
      database = db;
      bookRepo = BookRepository(db);
      sourceRepo = SourceRepository(db);
      bookAddService = BookAddService(database: db);
      importService = ImportService();
      bookImportFileNameRuleService = BookImportFileNameRuleService();
      bookGroupStore = BookshelfBookGroupStore(database: db);
      bookshelfIo = BookshelfImportExportService();
      booklistImporter = BookshelfBooklistImportService();
      catalogUpdater = BookshelfCatalogUpdateService(
        database: db,
        bookRepo: bookRepo,
      );
      final initialLayoutIndex = normalizeLayoutIndex(
          settingsService.appSettings.bookshelfLayoutIndex);
      isGridView = initialLayoutIndex > 0;
      gridCrossAxisCount = gridColumnsForLayoutIndex(initialLayoutIndex);
      style1SelectedTabIndex = readStyle1SelectedTabIndex();
      lastExternalReselectVersion = widget.reselectSignal?.value;
      widget.reselectSignal?.addListener(onExternalReselectSignal);
      loadBooks();
      unawaited(reloadBookGroupContext(showError: false));
      booksSubscription = bookRepo.watchAllBooks().listen((books) {
        if (!mounted) return;
        setState(() {
          books = List<Book>.from(books);
          sortBooks(settingsService.appSettings.bookshelfSortIndex);
        });
      });
      debugPrint('[bookshelf] init done, books=\${books.length}');
    } catch (e, st) {
      initError = '书架初始化异常: $e';
      debugPrint('[bookshelf] init failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  void didUpdateWidget(covariant BookshelfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal == widget.reselectSignal) return;
    oldWidget.reselectSignal?.removeListener(onExternalReselectSignal);
    lastExternalReselectVersion = widget.reselectSignal?.value;
    widget.reselectSignal?.addListener(onExternalReselectSignal);
  }

  @override
  void dispose() {
    booksSubscription?.cancel();
    widget.reselectSignal?.removeListener(onExternalReselectSignal);
    scrollController.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    if (initError != null) return buildInitErrorPage();

    final page = AppCupertinoPageScaffold(
      title: currentBookshelfTitle(),
      useSliverNavigationBar: true,
      sliverScrollController: scrollController,
      middle: buildBookshelfMiddleTitle(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: openGlobalSearch,
            child: const Icon(CupertinoIcons.search, size: 22),
          ),
          AppNavBarButton(
            key: moreMenuKey,
            onPressed: showMoreMenu,
            child: const Icon(CupertinoIcons.line_horizontal_3, size: 22),
          ),
        ],
      ),
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => buildBodySliver(),
    );
    return PopScope<void>(
      canPop: !isStyle2Enabled || selectedGroupId == BookshelfBookGroup.idRoot,
      // 与 legado style2 保持同义：处于子分组时先返回根分组，而不是直接退出主界面。
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        tryHandleStyle2Back();
      },
      child: wrapWithFastScroller(page),
    );
  }

  void showMessage(String message) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void showBottomHint(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }
}
