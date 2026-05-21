import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/book_variable_store.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/services/webdav_service.dart';
import '../../../core/models/book.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../import/txt_parser.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/services/reader_bookmark_export_service.dart';
import '../../reader/services/reader_charset_service.dart';
import '../../reader/services/chapter_title_display_helper.dart';
import '../../reader/services/reader_source_switch_helper.dart';
import '../../reader/services/txt_toc_rule_store.dart';
import '../../reader/views/reader_view.dart';
import '../../reader/widgets/source_switch_candidate_sheet.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../settings/views/app_log_dialog.dart';
import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../../source/services/source_login/ui_helper.dart';
import '../../source/services/source_login/url_resolver.dart';
import '../../source/views/login/login_form_view.dart';
import '../../source/views/login/login_webview_view.dart';
import '../services/search_book_info_edit_helper.dart';
import '../services/search_book_info_menu_helper.dart';
import '../services/search_book_info_refresh_helper.dart';
import '../services/search_book_info_share_helper.dart';
import '../services/search_book_info_top_helper.dart';
import 'search_book_info_edit_view.dart';
import 'search_book_info_toc_view.dart';
import 'search_book_info_widgets.dart';

part 'search_book_info_session_cache.dart';
part 'search_book_info_context_models.dart';
part 'search_book_info_bookshelf_context.dart';
part 'search_book_info_context_loader.dart';
part 'search_book_info_display_helpers.dart';
part 'search_book_info_toc_actions.dart';
part 'search_book_info_share_actions.dart';
part 'search_book_info_book_actions.dart';
part 'search_book_info_sync_actions.dart';
part 'search_book_info_shelf_actions.dart';
part 'search_book_info_reader_actions.dart';
part 'search_book_info_toc_refresh.dart';
part 'search_book_info_more_menu_items.dart';
part 'search_book_info_more_menu_actions.dart';
part 'search_book_info_source_switch_helpers.dart';
part 'search_book_info_source_switch_actions.dart';
part 'search_book_info_error_helpers.dart';
part 'search_book_info_body.dart';
part 'search_book_info_hero_section.dart';
part 'search_book_info_detail_section.dart';
part 'search_book_info_bottom_bar.dart';

enum _SearchBookInfoMoreMenuAction {
  edit,
  share,
  uploadWebDav,
  refresh,
  login,
  pinTop,
  setSourceVariable,
  setBookVariable,
  copyBookUrl,
  copyTocUrl,
  toggleAllowUpdate,
  toggleSplitLongChapter,
  toggleDeleteAlert,
  clearCache,
  logs,
}

typedef _SearchBookInfoMoreActionConfig = ({
  String actionKey,
  String actionLabel,
  Future<void> Function() action,
});

typedef _BookshelfTocCacheResult = ({
  List<TocItem> toc,
  String? error,
});

class _BookInfoSessionCacheEntry {
  final BookDetail? detail;
  final List<TocItem> toc;
  final DateTime savedAt;

  const _BookInfoSessionCacheEntry({
    required this.detail,
    required this.toc,
    required this.savedAt,
  });
}

/// 搜索/发现结果详情页（对标 legado：点击结果先进入详情，再决定阅读/加书架/目录）。
/// 也可从书架进入：若历史数据缺少 bookUrl，则降级展示缓存信息。
class SearchBookInfoView extends StatefulWidget {
  final SearchResult result;
  final Book? bookshelfBook;
  final ReaderBookmarkExportService? bookmarkExportService;

  const SearchBookInfoView({
    super.key,
    required this.result,
    this.bookmarkExportService,
  }) : bookshelfBook = null;

  const SearchBookInfoView._({
    super.key,
    required this.result,
    required this.bookshelfBook,
    required this.bookmarkExportService,
  });

  factory SearchBookInfoView.fromBookshelf({
    Key? key,
    required Book book,
    ReaderBookmarkExportService? bookmarkExportService,
  }) {
    final sourceUrl = (book.sourceUrl ?? book.sourceId ?? '').trim();
    return SearchBookInfoView._(
      key: key,
      bookshelfBook: book,
      bookmarkExportService: bookmarkExportService,
      result: SearchResult(
        name: book.title,
        author: book.author,
        coverUrl: (book.coverUrl ?? '').trim(),
        intro: book.intro ?? '',
        kind: '',
        lastChapter: (book.latestChapter ?? '').trim(),
        updateTime: '',
        wordCount: '',
        bookUrl: (book.bookUrl ?? '').trim(),
        sourceUrl: sourceUrl,
        sourceName: sourceUrl,
      ),
    );
  }

  @override
  State<SearchBookInfoView> createState() => SearchBookInfoViewState();
}

class SearchBookInfoViewState extends State<SearchBookInfoView> {
  static const _uuid = Uuid();
  static const int _maxSessionCacheEntries = 48;
  static const Duration _sessionCacheTtl = Duration(hours: 12);
  static const double _minWidthForInlineShareAction = 390;
  static const double _minWidthForInlineEditAction = 460;
  static final LinkedHashMap<String, _BookInfoSessionCacheEntry> _sessionCache =
      LinkedHashMap<String, _BookInfoSessionCacheEntry>();

  late final RuleParserEngine _engine;
  late final SourceRepository _sourceRepo;
  late final BookRepository _bookRepo;
  late final BookmarkRepository _bookmarkRepo;
  late final ChapterRepository _chapterRepo;
  late final BookAddService _addService;
  late final SettingsService _settingsService;
  late final WebDavService _webDavService;
  late final ReaderCharsetService _readerCharsetService;
  late final ReaderBookmarkExportService _bookmarkExportService;
  late final ChapterTitleDisplayHelper _chapterTitleDisplayHelper;
  final TxtTocRuleStore _txtTocRuleStore = TxtTocRuleStore();
  final GlobalKey _moreMenuKey = GlobalKey();

  late SearchResult _activeResult;
  BookSource? _source;
  BookDetail? _detail;
  List<TocItem> _toc = const <TocItem>[];

  String? _bookId;
  bool _inBookshelf = false;
  bool _loading = true;
  bool _loadingToc = false;
  bool _shelfBusy = false;
  bool _switchingSource = false;
  bool _allowUpdate = true;
  bool _splitLongChapter = true;
  bool _tocUiUseReplace = false;
  bool _tocUiLoadWordCount = true;
  bool _deleteAlertEnabled = true;
  int _changeSourceDelaySeconds = 0;
  String? _error;
  String? _tocError;

  bool get _isBookshelfEntry => widget.bookshelfBook != null;

  bool get _canFetchOnlineDetail {
    return _activeResult.sourceUrl.trim().isNotEmpty &&
        _activeResult.bookUrl.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _engine = RuleParserEngine();
    _sourceRepo = SourceRepository(db);
    _bookRepo = BookRepository(db);
    _bookmarkRepo = BookmarkRepository();
    _chapterRepo = ChapterRepository(db);
    _addService = BookAddService(database: db, engine: _engine);
    _settingsService = SettingsService();
    _changeSourceDelaySeconds = _settingsService.getBatchChangeSourceDelay();
    _webDavService = WebDavService();
    _readerCharsetService = ReaderCharsetService();
    _bookmarkExportService =
        widget.bookmarkExportService ?? ReaderBookmarkExportService();
    _deleteAlertEnabled = _resolveBookInfoDeleteAlertSetting();
    _chapterTitleDisplayHelper = ChapterTitleDisplayHelper(
      replaceRuleService: ReplaceRuleService(db),
    );
    _activeResult = widget.result;
    _loadContext();
  }

  @override
  Widget build(BuildContext context) {
    return _buildBookInfoPage(context);
  }
}
