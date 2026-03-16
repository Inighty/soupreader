import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../../../core/database/database_service.dart';
import '../../../core/models/book.dart' show Chapter;
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/js_runtime.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/services/webdav_service.dart';
import '../../../core/utils/chinese_script_converter.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../services/reader_charset_service.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_image_resolver.dart';
import '../services/reader_image_warmup_telemetry.dart';
import '../services/reader_theme_mode_helper.dart';
import '../services/reader_theme_resolver.dart';
import '../services/reader_tip_selection_helper.dart';
import '../services/read_aloud_service.dart';
import '../utils/chapter_progress_utils.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';
import '../widgets/auto_pager.dart';
import '../widgets/scroll_text_layout_engine.dart';
import 'reader_bookmark_controller.dart';
import 'reader_read_aloud_controller.dart';
import 'reader_source_switch_state.dart';

/// Centralized state container for the reader.
///
/// Holds ALL mutable state that was previously scattered across
/// `_SimpleReaderViewState`. Child widgets and controllers observe this
/// via [ReaderStateProvider] and mutate it through setter methods that
/// call [notifyListeners].
class ReaderStateManager extends ChangeNotifier {
  ReaderStateManager({
    required this.bookId,
    required this.bookTitle,
    required this.isEphemeral,
  });

  // ── Identity ──
  final String bookId;
  final String bookTitle;
  final bool isEphemeral;

  // ── Services (injected once, not changeable) ──
  late final ChapterRepository chapterRepo;
  late final BookRepository bookRepo;
  late final SourceRepository sourceRepo;
  late final ReplaceRuleRepository replaceRuleRepo;
  late final BookshelfCatalogUpdateService catalogUpdateService;
  late final ReplaceRuleService replaceService;
  late final SettingsService settingsService;
  late final WebDavService webDavService;
  final ScreenBrightnessService brightnessService =
      ScreenBrightnessService.instance;
  final KeepScreenOnService keepScreenOnService = KeepScreenOnService.instance;
  final RuleParserEngine ruleEngine = RuleParserEngine();
  final ScrollTextLayoutEngine scrollTextLayoutEngine =
      ScrollTextLayoutEngine.instance;
  final ChineseScriptConverter chineseScriptConverter =
      ChineseScriptConverter.instance;
  final ReaderCharsetService readerCharsetService = ReaderCharsetService();

  // ── Controllers (created by shell, held here for cross-controller access) ──
  late final ReaderReadAloudController readAloudController;
  late final ReaderBookmarkController bookmarkController;
  late final ReaderSourceSwitchState sourceState;

  // ── Chapter state ──
  List<Chapter> chapters = [];
  int currentChapterIndex = 0;
  String currentContent = '';
  String currentTitle = '';
  bool isLoadingChapter = false;
  bool isRestoringProgress = false;
  bool isInitialized = false;
  final Map<String, ReplaceStageCache> replaceStageCache = {};
  final Map<String, String> catalogDisplayTitleCacheByChapterId = {};
  final Map<String, ResolvedChapterSnapshot>
      resolvedChapterSnapshotByChapterId = {};
  final Map<String, ChapterImageMetaSnapshot>
      chapterImageMetaSnapshotByChapterId = {};
  final Map<String, Future<String>> chapterContentInFlight = {};
  final Map<String, bool> chapterSameTitleRemovedById = {};
  bool hasDeferredChapterTransformRefresh = false;
  Duration recentChapterFetchDuration = Duration.zero;

  // ── Reading Settings & Theme ──
  ReadingSettings settings = const ReadingSettings();
  ReaderThemeResolver themeResolver = const ReaderThemeResolver(
    settings: ReadingSettings(),
    themeMode: ReaderThemeMode.day,
    readStyleConfigs: [],
  );
  int? bookPageAnimOverride;
  bool useReplaceRule = true;
  bool reSegment = false;
  bool delRubyTag = false;
  bool delHTag = false;
  String imageStyle = 'DEFAULT';
  String? readerCustomFontFamily;
  String? readStyleBackgroundDirectoryPath;
  ui.Image? readerBgUiImage;
  String? readerBgUiImageKey;
  Timer? keepLightTimer;

  // ── UI/Menu state ──
  bool showMenu = false;
  bool showSearchMenu = false;
  bool showAutoReadPanel = false;
  bool autoPagerPausedByMenu = false;
  EdgeInsets? lastViewPadding;
  bool contentSelectMenuLongPressHandled = false;
  Timer? contentSelectMenuLongPressResetTimer;

  // ── Scroll mode state ──
  final ScrollController scrollController = ScrollController();
  final List<ScrollSegment> scrollSegments = [];
  final Map<int, GlobalKey> scrollSegmentKeys = {};
  final Map<int, double> scrollSegmentHeights = {};
  final List<ScrollSegmentOffsetRange> scrollSegmentOffsetRanges = [];
  final GlobalKey scrollViewportKey = GlobalKey(debugLabel: 'scroll_viewport');
  final ValueNotifier<ScrollTipData> scrollTipNotifier = ValueNotifier(
    const ScrollTipData(
      title: '',
      bookTitle: '',
      bookProgress: 0,
      chapterProgress: 0,
      currentPage: 0,
      totalPages: 0,
      currentTime: '',
    ),
  );
  final ValueNotifier<int> scrollSegmentsVersion = ValueNotifier(0);
  bool scrollAppending = false;
  bool scrollPrepending = false;
  bool syncingScrollVisibleChapter = false;
  int? pendingScrollTargetChapterIndex;
  double? pendingScrollTargetChapterProgress;
  bool pendingScrollJumpToEnd = false;
  int pendingScrollJumpRetry = 0;
  double currentScrollChapterProgress = 0.0;
  DateTime lastScrollProgressSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastScrollUiSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastScrollPreloadCheckAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool programmaticScrollInFlight = false;
  double scrollAnchorWithinViewport = 32.0;
  dynamic scrollLayoutSnapshot;
  int? scrollLayoutChapterIndex;
  int scrollLayoutFingerprint = 0;
  bool scrollTickCallbackPending = false;

  // ── Paged mode state ──
  final PageFactory pageFactory = PageFactory();
  final PagedReaderController pagedReaderController = PagedReaderController();
  bool isHydratingChapterFromPageFactory = false;
  int? activeHydratingChapterFromPageFactoryIndex;
  int? pendingHydratingChapterFromPageFactoryIndex;
  bool isCurrentFactoryChapterLoading = false;
  bool chapterSeekConfirmed = false;
  bool pendingImageSizeRepagination = false;

  // ── Image state ──
  final Map<String, ReaderImageMarkerMeta> chapterImageMetaByCacheKey = {};
  final Set<String> imageSizeWarmupInFlight = {};
  final Set<String> bookImageSizeCacheKeys = {};
  final Map<String, String> readerImageCookieHeaderByHost = {};
  final Set<String> readerImageCookieLoadInFlight = {};
  double longImageFirstFrameErrorEma = 0.0;
  int longImageFirstFrameErrorSamples = 0;
  final ReaderImageResolver readerImageResolver =
      const ReaderImageResolver(isWeb: false);
  final Map<String, ReaderImageWarmupSourceTelemetry>
      imageWarmupTelemetryBySource = {};
  Timer? imageSizeSnapshotPersistTimer;

  // ── Auto-pager ──
  final AutoPager autoPager = AutoPager();
  bool audioPlayUseWakeLock = false;

  // ── Read record ──
  DateTime lastReadRecordAccumulatedAt = DateTime.now();
  DateTime lastReadRecordPersistAt =
      DateTime.fromMillisecondsSinceEpoch(0);
  int pendingReadRecordDurationMs = 0;

  // ── TOC UI ──
  bool tocUiUseReplace = false;
  bool tocUiLoadWordCount = true;
  bool tocUiSplitLongChapter = false;

  // ── Bookmark state ──
  bool hasBookmarkAtCurrent = false;

  // ── Focus ──
  final FocusNode keyboardFocusNode = FocusNode();

  // ── Convenience ──

  /// Notify all listeners (use after batch state mutations in setState).
  void notify() => notifyListeners();

  @override
  void dispose() {
    scrollController.dispose();
    scrollTipNotifier.dispose();
    scrollSegmentsVersion.dispose();
    keyboardFocusNode.dispose();
    autoPager.dispose();
    keepLightTimer?.cancel();
    imageSizeSnapshotPersistTimer?.cancel();
    contentSelectMenuLongPressResetTimer?.cancel();
    super.dispose();
  }
}
