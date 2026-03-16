import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../../../core/models/book.dart' show Chapter;
import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_image_warmup_telemetry.dart';
import '../services/reader_theme_mode_helper.dart';
import '../services/reader_theme_resolver.dart';
import '../widgets/auto_pager.dart';
import '../widgets/page_factory.dart';
import '../widgets/paged_reader_widget.dart';

// ═══════════════════════════════════════════════════════════════════════
// 状态分组：将 50+ 个散乱变量归类为 6 个内聚的 "数据仓库"，
// 每个仓库用 ValueNotifier 包装，外部加工车间改值后 UI 自动刷新。
// ═══════════════════════════════════════════════════════════════════════

/// 章节 + 内容状态（UI 可观察）
class ChapterState extends ChangeNotifier {
  List<Chapter> chapters = [];
  int currentIndex = 0;
  String currentContent = '';
  String currentTitle = '';
  bool isLoading = false;
  bool isRestoring = false;
  bool isInitialized = false;

  /// 内容处理内部缓存（不驱动 UI，仅供 Coordinator 使用）。
  final ContentProcessingCache cache = ContentProcessingCache();

  Duration recentFetchDuration = Duration.zero;

  void update({
    int? index,
    String? content,
    String? title,
    bool? loading,
    bool? restoring,
    bool? initialized,
  }) {
    if (index != null) currentIndex = index;
    if (content != null) currentContent = content;
    if (title != null) currentTitle = title;
    if (loading != null) isLoading = loading;
    if (restoring != null) isRestoring = restoring;
    if (initialized != null) isInitialized = initialized;
    notifyListeners();
  }

  int get readableCount => chapters.length;
  int get maxIndex => (chapters.length - 1).clamp(0, 999999);

  /// 供外部 Coordinator 调用，触发 UI 刷新（ChangeNotifier.notifyListeners 是 protected）。
  void notify() => notifyListeners();
}

/// UI / 菜单 / 覆盖层状态
class UiState extends ChangeNotifier {
  bool showMenu = false;
  bool showSearchMenu = false;
  bool showAutoReadPanel = false;
  bool autoPagerPausedByMenu = false;
  bool contentSelectLongPressHandled = false;
  Timer? contentSelectLongPressResetTimer;
  final AutoPager autoPager = AutoPager();

  /// Toast 消息队列。Coordinator 层写入，View 层消费。
  final ValueNotifier<String?> pendingToast = ValueNotifier(null);

  /// 由 Coordinator 层调用发送 toast 消息。
  void showToast(String message) {
    pendingToast.value = message;
  }

  void toggleMenu(bool show) {
    showMenu = show;
    notifyListeners();
  }

  void toggleSearchMenu(bool show) {
    showSearchMenu = show;
    notifyListeners();
  }

  void toggleAutoReadPanel(bool show) {
    showAutoReadPanel = show;
    notifyListeners();
  }
}

/// 阅读设置 + 主题
class SettingsState extends ChangeNotifier {
  ReadingSettings settings = const ReadingSettings();
  ReaderThemeResolver themeResolver = ReaderThemeResolver(
    settings: const ReadingSettings(),
    themeMode: ReaderThemeMode.day,
    readStyleConfigs: const [],
  );
  int? bookPageAnimOverride;
  bool useReplaceRule = true;
  bool reSegment = false;
  bool delRubyTag = false;
  bool delHTag = false;
  String imageStyle = 'DEFAULT';
  String? customFontFamily;
  String? bgDirectoryPath;
  ui.Image? bgUiImage;
  String? bgUiImageKey;

  void update(ReadingSettings newSettings) {
    settings = newSettings;
    notifyListeners();
  }

  void syncTheme(ReaderThemeResolver resolver) {
    themeResolver = resolver;
    notifyListeners();
  }

  /// 供外部 Coordinator 调用，触发 UI 刷新。
  void notify() => notifyListeners();
}

/// 滚动模式状态
class ScrollModeState extends ChangeNotifier {
  final ScrollController controller = ScrollController();
  final List<ScrollSegment> segments = [];
  final Map<int, GlobalKey> segmentKeys = {};
  final Map<int, double> segmentHeights = {};
  final List<ScrollSegmentOffsetRange> offsetRanges = [];
  final GlobalKey viewportKey = GlobalKey(debugLabel: 'scroll_viewport');
  final ValueNotifier<ScrollTipData> tipNotifier = ValueNotifier(
    const ScrollTipData(
      title: '', bookTitle: '', bookProgress: 0,
      chapterProgress: 0, currentPage: 0, totalPages: 0, currentTime: '',
    ),
  );
  final ValueNotifier<int> segmentsVersion = ValueNotifier(0);

  bool appending = false;
  bool prepending = false;
  bool syncingVisibleChapter = false;
  int? pendingTargetIndex;
  double? pendingTargetProgress;
  bool pendingJumpToEnd = false;
  int pendingJumpRetry = 0;
  double currentChapterProgress = 0.0;
  bool programmaticScrollInFlight = false;
  double anchorWithinViewport = 32.0;
  DateTime lastProgressSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastUiSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastPreloadCheckAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool tickCallbackPending = false;
  dynamic layoutSnapshot;
  int? layoutChapterIndex;
  int layoutFingerprint = 0;

  void bumpVersion() {
    segmentsVersion.value++;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.dispose();
    tipNotifier.dispose();
    segmentsVersion.dispose();
    super.dispose();
  }
}

/// 分页模式状态
class PagedModeState extends ChangeNotifier {
  final PageFactory pageFactory = PageFactory();
  final PagedReaderController pagedController = PagedReaderController();
  bool isHydrating = false;
  int? activeHydratingIndex;
  int? pendingHydratingIndex;
  bool isCurrentFactoryLoading = false;
  bool seekConfirmed = false;
  bool pendingImageRepagination = false;
}

/// 图片缓存 + 书源状态
class ImageCacheState {
  // ── 书源身份信息 ──
  String? sourceUrl;
  String? sourceName;
  String bookAuthor = '';
  String? bookCoverUrl;

  // ── 图片缓存 ──
  final Map<String, ReaderImageMarkerMeta> metaByCacheKey = {};
  final Set<String> warmupInFlight = {};
  final Set<String> bookCacheKeys = {};
  final Map<String, String> cookieHeaderByHost = {};
  final Set<String> cookieLoadInFlight = {};
  double longImageErrorEma = 0.0;
  int longImageErrorSamples = 0;
  final Map<String, ReaderImageWarmupSourceTelemetry> telemetryBySource = {};
  Timer? snapshotPersistTimer;
  final Map<String, ChapterImageMetaSnapshot> metaSnapshotByChapterId = {};
}

/// 内容处理内部缓存（不驱动 UI 刷新）。
///
/// 存放替换规则阶段缓存、目录显示标题缓存等，
/// 仅供 Coordinator 内部使用，不需要 ChangeNotifier。
class ContentProcessingCache {
  final Map<String, ReplaceStageCache> replaceStage = {};
  final Map<String, String> catalogDisplayTitle = {};
  final Map<String, ResolvedChapterSnapshot> resolvedSnapshots = {};
  final Map<String, Future<String>> contentInFlight = {};
  final Map<String, bool> sameTitleRemovedById = {};
  bool hasDeferredTransformRefresh = false;

  void clear() {
    replaceStage.clear();
    catalogDisplayTitle.clear();
    contentInFlight.clear();
  }

  void clearForChapter(String chapterId) {
    replaceStage.remove(chapterId);
    catalogDisplayTitle.remove(chapterId);
    contentInFlight.remove(chapterId);
  }
}
