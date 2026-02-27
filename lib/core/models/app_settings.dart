/// 应用级设置（非阅读页内设置）
///
/// 目标：对标 Legado / 完全阅读器等同类产品的“设置”入口，把常用的全局开关
/// 统一收敛到一个可持久化、可迁移（备份/恢复）的模型里。
enum AppAppearanceMode {
  followSystem,
  light,
  dark,
  eInk,
}

const int appAppearanceModeFollowSystemValue = 0;
const int appAppearanceModeLightValue = 1;
const int appAppearanceModeDarkValue = 2;
const int appAppearanceModeEInkValue = 3;
const int appAppearanceModeLegacyTriValueMax = appAppearanceModeDarkValue;
const int appAppearanceModeLegacyMaxValue = appAppearanceModeEInkValue;

int appAppearanceModeToLegacyValue(AppAppearanceMode mode) {
  switch (mode) {
    case AppAppearanceMode.followSystem:
      return appAppearanceModeFollowSystemValue;
    case AppAppearanceMode.light:
      return appAppearanceModeLightValue;
    case AppAppearanceMode.dark:
      return appAppearanceModeDarkValue;
    case AppAppearanceMode.eInk:
      return appAppearanceModeEInkValue;
  }
}

AppAppearanceMode appAppearanceModeFromLegacyValue(int value) {
  switch (value) {
    case appAppearanceModeLightValue:
      return AppAppearanceMode.light;
    case appAppearanceModeDarkValue:
      return AppAppearanceMode.dark;
    case appAppearanceModeEInkValue:
      return AppAppearanceMode.eInk;
    case appAppearanceModeFollowSystemValue:
    default:
      return AppAppearanceMode.followSystem;
  }
}

bool isValidAppAppearanceModeLegacyValue(int value) {
  return value >= appAppearanceModeFollowSystemValue &&
      value <= appAppearanceModeLegacyMaxValue;
}

int? tryParseAppAppearanceModeLegacyValue(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;
    switch (normalized.toLowerCase()) {
      case 'followsystem':
      case 'follow_system':
      case 'follow-system':
      case 'system':
      case 'auto':
        return appAppearanceModeFollowSystemValue;
      case 'light':
      case 'day':
        return appAppearanceModeLightValue;
      case 'dark':
      case 'night':
        return appAppearanceModeDarkValue;
      case 'eink':
      case 'e-ink':
      case 'e_ink':
        return appAppearanceModeEInkValue;
    }
  }
  return null;
}

int resolveAppAppearanceModeLegacyValueFromJson(
  Map<String, dynamic> sourceJson,
) {
  final parsedAppearanceMode =
      tryParseAppAppearanceModeLegacyValue(sourceJson['appearanceMode']);
  if (parsedAppearanceMode != null &&
      isValidAppAppearanceModeLegacyValue(parsedAppearanceMode)) {
    return parsedAppearanceMode;
  }
  final parsedThemeMode =
      tryParseAppAppearanceModeLegacyValue(sourceJson['themeMode']);
  if (parsedThemeMode != null &&
      isValidAppAppearanceModeLegacyValue(parsedThemeMode)) {
    return parsedThemeMode;
  }
  return appAppearanceModeFollowSystemValue;
}

AppAppearanceMode parseAppAppearanceModeFromJson(
  Map<String, dynamic> sourceJson,
) {
  return appAppearanceModeFromLegacyValue(
    resolveAppAppearanceModeLegacyValueFromJson(sourceJson),
  );
}

enum BookshelfViewMode {
  grid,
  list,
}

enum BookshelfSortMode {
  recentRead,
  recentAdded,
  title,
  author,
}

int bookshelfLayoutIndexFromViewMode(BookshelfViewMode mode) {
  return mode == BookshelfViewMode.list ? 0 : 1;
}

BookshelfViewMode bookshelfViewModeFromLayoutIndex(int index) {
  final normalized = index.clamp(0, 4).toInt();
  return normalized == 0 ? BookshelfViewMode.list : BookshelfViewMode.grid;
}

int bookshelfLegacySortIndexFromMode(BookshelfSortMode mode) {
  switch (mode) {
    case BookshelfSortMode.recentRead:
      return 0;
    case BookshelfSortMode.recentAdded:
      return 1;
    case BookshelfSortMode.title:
      return 2;
    case BookshelfSortMode.author:
      return 5;
  }
}

BookshelfSortMode bookshelfSortModeFromLegacyIndex(int index) {
  final normalized = index.clamp(0, 5).toInt();
  switch (normalized) {
    case 1:
      return BookshelfSortMode.recentAdded;
    case 2:
      return BookshelfSortMode.title;
    case 5:
      return BookshelfSortMode.author;
    case 0:
    case 3:
    case 4:
      return BookshelfSortMode.recentRead;
    default:
      return BookshelfSortMode.recentRead;
  }
}

enum MainDefaultHomePage {
  bookshelf,
  explore,
  rss,
  my,
}

enum SearchFilterMode {
  /// 历史兼容值：旧版本曾暴露“不过滤”入口。
  /// legado 仅有“精准搜索开关”，因此运行时会归一为 `normal`。
  none,
  normal,
  precise,
}

SearchFilterMode normalizeSearchFilterMode(SearchFilterMode mode) {
  return mode == SearchFilterMode.precise
      ? SearchFilterMode.precise
      : SearchFilterMode.normal;
}

class AppSettings {
  static const String defaultWebDavUrl = 'https://dav.jianguoyun.com/dav/';

  final AppAppearanceMode appearanceMode;
  final bool wifiOnlyDownload;
  final bool autoUpdateSources;
  final bool autoRefresh;
  final bool defaultToRead;
  final bool showDiscovery;
  final bool showRss;
  final MainDefaultHomePage defaultHomePage;
  final int preDownloadNum;
  final int threadCount;
  final int bitmapCacheSize;
  final int imageRetainNum;
  final bool replaceEnableDefault;
  final bool processText;
  final bool recordLog;
  final bool recordHeapDump;

  final BookshelfViewMode bookshelfViewMode;
  final BookshelfSortMode bookshelfSortMode;
  final int bookshelfGroupStyle;
  final int bookshelfLayoutIndex;
  final int bookshelfSortIndex;
  final bool bookshelfShowUnread;
  final bool bookshelfShowLastUpdateTime;
  final bool bookshelfShowWaitUpCount;
  final bool bookshelfShowFastScroller;
  final SearchFilterMode searchFilterMode;
  final int searchConcurrency;
  final int searchCacheRetentionDays;
  final String searchScope;
  final List<String> searchScopeSourceUrls;
  final bool searchShowCover;
  final bool bookInfoDeleteAlert;
  final bool syncBookProgress;
  final bool syncBookProgressPlus;
  final String webDavUrl;
  final String webDavAccount;
  final String webDavPassword;
  final String webDavDir;
  final String webDavDeviceName;
  final bool onlyLatestBackup;
  final bool autoCheckNewBackup;
  final String backupPath;

  const AppSettings({
    this.appearanceMode = AppAppearanceMode.followSystem,
    this.wifiOnlyDownload = true,
    this.autoUpdateSources = true,
    this.autoRefresh = false,
    this.defaultToRead = false,
    this.showDiscovery = true,
    this.showRss = true,
    this.defaultHomePage = MainDefaultHomePage.bookshelf,
    this.preDownloadNum = 10,
    this.threadCount = 16,
    this.bitmapCacheSize = 50,
    this.imageRetainNum = 0,
    this.replaceEnableDefault = true,
    this.processText = true,
    this.recordLog = false,
    this.recordHeapDump = false,
    this.bookshelfViewMode = BookshelfViewMode.grid,
    this.bookshelfSortMode = BookshelfSortMode.recentRead,
    this.bookshelfGroupStyle = 0,
    this.bookshelfLayoutIndex = 1,
    this.bookshelfSortIndex = 0,
    this.bookshelfShowUnread = true,
    this.bookshelfShowLastUpdateTime = false,
    this.bookshelfShowWaitUpCount = false,
    this.bookshelfShowFastScroller = false,
    this.searchFilterMode = SearchFilterMode.normal,
    this.searchConcurrency = 8,
    this.searchCacheRetentionDays = 5,
    this.searchScope = '',
    this.searchScopeSourceUrls = const <String>[],
    this.searchShowCover = true,
    this.bookInfoDeleteAlert = true,
    this.syncBookProgress = true,
    this.syncBookProgressPlus = false,
    this.webDavUrl = defaultWebDavUrl,
    this.webDavAccount = '',
    this.webDavPassword = '',
    this.webDavDir = '',
    this.webDavDeviceName = '',
    this.onlyLatestBackup = true,
    this.autoCheckNewBackup = true,
    this.backupPath = '',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    BookshelfViewMode parseViewMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == null) return BookshelfViewMode.grid;
      return BookshelfViewMode
          .values[index.clamp(0, BookshelfViewMode.values.length - 1)];
    }

    BookshelfSortMode parseSortMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == null) return BookshelfSortMode.recentRead;
      return BookshelfSortMode
          .values[index.clamp(0, BookshelfSortMode.values.length - 1)];
    }

    SearchFilterMode parseSearchFilterMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == SearchFilterMode.precise.index) {
        return SearchFilterMode.precise;
      }
      return SearchFilterMode.normal;
    }

    MainDefaultHomePage parseDefaultHomePage(dynamic raw) {
      if (raw is String) {
        switch (raw.trim().toLowerCase()) {
          case 'explore':
            return MainDefaultHomePage.explore;
          case 'rss':
            return MainDefaultHomePage.rss;
          case 'my':
            return MainDefaultHomePage.my;
          default:
            return MainDefaultHomePage.bookshelf;
        }
      }
      if (raw is int) {
        return MainDefaultHomePage
            .values[raw.clamp(0, MainDefaultHomePage.values.length - 1)];
      }
      if (raw is num) {
        final index = raw.toInt();
        return MainDefaultHomePage
            .values[index.clamp(0, MainDefaultHomePage.values.length - 1)];
      }
      return MainDefaultHomePage.bookshelf;
    }

    int parseIntWithDefault(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? fallback;
      return fallback;
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      final seen = <String>{};
      final out = <String>[];
      for (final item in raw) {
        final text = item.toString().trim();
        if (text.isEmpty) continue;
        if (!seen.add(text)) continue;
        out.add(text);
      }
      return out;
    }

    String parseString(dynamic raw) {
      if (raw == null) return '';
      return raw.toString().trim();
    }

    bool parseBoolWithDefault(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        switch (raw.trim().toLowerCase()) {
          case '1':
          case 'true':
          case 'yes':
          case 'on':
            return true;
          case '0':
          case 'false':
          case 'no':
          case 'off':
            return false;
        }
      }
      return fallback;
    }

    final legacyScopeSourceUrls =
        parseStringList(json['searchScopeSourceUrls']);
    var parsedSearchScope = parseString(json['searchScope']);
    if (parsedSearchScope.isEmpty && legacyScopeSourceUrls.length == 1) {
      parsedSearchScope = '::${legacyScopeSourceUrls.first}';
    }
    final hasLegacyLayoutIndex = json.containsKey('bookshelfLayoutIndex') ||
        json.containsKey('bookshelfLayout');
    final parsedLayoutIndex = parseIntWithDefault(
      json['bookshelfLayoutIndex'] ?? json['bookshelfLayout'],
      bookshelfLayoutIndexFromViewMode(
          parseViewMode(json['bookshelfViewMode'])),
    ).clamp(0, 4);
    final hasLegacySortIndex = json.containsKey('bookshelfSortIndex') ||
        json.containsKey('bookshelfSort');
    final parsedSortIndex = parseIntWithDefault(
      json['bookshelfSortIndex'] ?? json['bookshelfSort'],
      bookshelfLegacySortIndexFromMode(
          parseSortMode(json['bookshelfSortMode'])),
    ).clamp(0, 5);

    return AppSettings(
      appearanceMode: parseAppAppearanceModeFromJson(json),
      wifiOnlyDownload: json['wifiOnlyDownload'] as bool? ?? true,
      autoUpdateSources: json['autoUpdateSources'] as bool? ?? true,
      autoRefresh: parseBoolWithDefault(
        json['autoRefresh'] ?? json['auto_refresh'],
        false,
      ),
      defaultToRead: parseBoolWithDefault(
        json['defaultToRead'],
        false,
      ),
      showDiscovery: parseBoolWithDefault(json['showDiscovery'], true),
      showRss: parseBoolWithDefault(
        json['showRss'] ?? json['showRSS'],
        true,
      ),
      defaultHomePage: parseDefaultHomePage(json['defaultHomePage']),
      preDownloadNum:
          parseIntWithDefault(json['preDownloadNum'], 10).clamp(0, 9999),
      threadCount: parseIntWithDefault(json['threadCount'], 16).clamp(1, 999),
      bitmapCacheSize:
          parseIntWithDefault(json['bitmapCacheSize'], 50).clamp(1, 2047),
      imageRetainNum:
          parseIntWithDefault(json['imageRetainNum'], 0).clamp(0, 999),
      replaceEnableDefault:
          parseBoolWithDefault(json['replaceEnableDefault'], true),
      processText: parseBoolWithDefault(
        json['processText'] ?? json['process_text'],
        true,
      ),
      recordLog: parseBoolWithDefault(json['recordLog'], false),
      recordHeapDump: parseBoolWithDefault(json['recordHeapDump'], false),
      bookshelfViewMode: hasLegacyLayoutIndex
          ? bookshelfViewModeFromLayoutIndex(parsedLayoutIndex)
          : parseViewMode(json['bookshelfViewMode']),
      bookshelfSortMode: hasLegacySortIndex
          ? bookshelfSortModeFromLegacyIndex(parsedSortIndex)
          : parseSortMode(json['bookshelfSortMode']),
      bookshelfGroupStyle: parseIntWithDefault(
              json['bookshelfGroupStyle'] ?? json['bookGroupStyle'], 0)
          .clamp(0, 1),
      bookshelfLayoutIndex: parsedLayoutIndex,
      bookshelfSortIndex: parsedSortIndex,
      bookshelfShowUnread: parseBoolWithDefault(
        json['bookshelfShowUnread'] ?? json['showUnread'],
        true,
      ),
      bookshelfShowLastUpdateTime: parseBoolWithDefault(
        json['bookshelfShowLastUpdateTime'] ?? json['showLastUpdateTime'],
        false,
      ),
      bookshelfShowWaitUpCount: parseBoolWithDefault(
        json['bookshelfShowWaitUpCount'] ?? json['showWaitUpCount'],
        false,
      ),
      bookshelfShowFastScroller: parseBoolWithDefault(
        json['bookshelfShowFastScroller'] ?? json['showBookshelfFastScroller'],
        false,
      ),
      searchFilterMode: normalizeSearchFilterMode(
          parseSearchFilterMode(json['searchFilterMode'])),
      searchConcurrency:
          parseIntWithDefault(json['searchConcurrency'], 8).clamp(2, 12),
      searchCacheRetentionDays:
          parseIntWithDefault(json['searchCacheRetentionDays'], 5).clamp(1, 30),
      searchScope: parsedSearchScope,
      searchScopeSourceUrls: legacyScopeSourceUrls,
      searchShowCover: json['searchShowCover'] as bool? ?? true,
      bookInfoDeleteAlert: parseBoolWithDefault(
        json['bookInfoDeleteAlert'],
        true,
      ),
      syncBookProgress: parseBoolWithDefault(
        json['syncBookProgress'] ?? json['sync_book_progress'],
        true,
      ),
      syncBookProgressPlus: parseBoolWithDefault(
        json['syncBookProgressPlus'] ?? json['sync_book_progress_plus'],
        false,
      ),
      webDavUrl: parseString(
        json['webDavUrl'] ?? json['webdavUrl'] ?? defaultWebDavUrl,
      ),
      webDavAccount: parseString(
        json['webDavAccount'] ?? json['webdavAccount'],
      ),
      webDavPassword: parseString(
        json['webDavPassword'] ?? json['webdavPassword'],
      ),
      webDavDir: parseString(json['webDavDir'] ?? json['webdavDir']),
      webDavDeviceName: parseString(
        json['webDavDeviceName'] ?? json['webdavDeviceName'],
      ),
      onlyLatestBackup: parseBoolWithDefault(
        json['onlyLatestBackup'] ?? json['only_latest_backup'],
        true,
      ),
      autoCheckNewBackup: parseBoolWithDefault(
        json['autoCheckNewBackup'] ?? json['auto_check_new_backup'],
        true,
      ),
      backupPath: parseString(json['backupPath'] ?? json['backupUri']),
    );
  }

  Map<String, dynamic> toJson() {
    final appearanceModeValue = appAppearanceModeToLegacyValue(appearanceMode);
    return {
      'appearanceMode': appearanceModeValue,
      'themeMode': appearanceModeValue,
      'wifiOnlyDownload': wifiOnlyDownload,
      'autoUpdateSources': autoUpdateSources,
      'autoRefresh': autoRefresh,
      'auto_refresh': autoRefresh,
      'defaultToRead': defaultToRead,
      'showDiscovery': showDiscovery,
      'showRss': showRss,
      'defaultHomePage': defaultHomePage.name,
      'preDownloadNum': preDownloadNum,
      'threadCount': threadCount,
      'bitmapCacheSize': bitmapCacheSize,
      'imageRetainNum': imageRetainNum,
      'replaceEnableDefault': replaceEnableDefault,
      'processText': processText,
      'process_text': processText,
      'recordLog': recordLog,
      'recordHeapDump': recordHeapDump,
      'bookshelfViewMode': bookshelfViewMode.index,
      'bookshelfSortMode': bookshelfSortMode.index,
      'bookshelfGroupStyle': bookshelfGroupStyle,
      'bookGroupStyle': bookshelfGroupStyle,
      'bookshelfLayoutIndex': bookshelfLayoutIndex,
      'bookshelfLayout': bookshelfLayoutIndex,
      'bookshelfSortIndex': bookshelfSortIndex,
      'bookshelfSort': bookshelfSortIndex,
      'bookshelfShowUnread': bookshelfShowUnread,
      'showUnread': bookshelfShowUnread,
      'bookshelfShowLastUpdateTime': bookshelfShowLastUpdateTime,
      'showLastUpdateTime': bookshelfShowLastUpdateTime,
      'bookshelfShowWaitUpCount': bookshelfShowWaitUpCount,
      'showWaitUpCount': bookshelfShowWaitUpCount,
      'bookshelfShowFastScroller': bookshelfShowFastScroller,
      'showBookshelfFastScroller': bookshelfShowFastScroller,
      'searchFilterMode': normalizeSearchFilterMode(searchFilterMode).index,
      'searchConcurrency': searchConcurrency,
      'searchCacheRetentionDays': searchCacheRetentionDays,
      'searchScope': searchScope,
      'searchScopeSourceUrls': searchScopeSourceUrls,
      'searchShowCover': searchShowCover,
      'bookInfoDeleteAlert': bookInfoDeleteAlert,
      'syncBookProgress': syncBookProgress,
      'sync_book_progress': syncBookProgress,
      'syncBookProgressPlus': syncBookProgressPlus,
      'sync_book_progress_plus': syncBookProgressPlus,
      'webDavUrl': webDavUrl,
      'webDavAccount': webDavAccount,
      'webDavPassword': webDavPassword,
      'webDavDir': webDavDir,
      'webDavDeviceName': webDavDeviceName,
      'webdavDeviceName': webDavDeviceName,
      'onlyLatestBackup': onlyLatestBackup,
      'only_latest_backup': onlyLatestBackup,
      'autoCheckNewBackup': autoCheckNewBackup,
      'auto_check_new_backup': autoCheckNewBackup,
      'backupPath': backupPath,
      'backupUri': backupPath,
    };
  }

  AppSettings copyWith({
    AppAppearanceMode? appearanceMode,
    bool? wifiOnlyDownload,
    bool? autoUpdateSources,
    bool? autoRefresh,
    bool? defaultToRead,
    bool? showDiscovery,
    bool? showRss,
    MainDefaultHomePage? defaultHomePage,
    int? preDownloadNum,
    int? threadCount,
    int? bitmapCacheSize,
    int? imageRetainNum,
    bool? replaceEnableDefault,
    bool? processText,
    bool? recordLog,
    bool? recordHeapDump,
    BookshelfViewMode? bookshelfViewMode,
    BookshelfSortMode? bookshelfSortMode,
    int? bookshelfGroupStyle,
    int? bookshelfLayoutIndex,
    int? bookshelfSortIndex,
    bool? bookshelfShowUnread,
    bool? bookshelfShowLastUpdateTime,
    bool? bookshelfShowWaitUpCount,
    bool? bookshelfShowFastScroller,
    SearchFilterMode? searchFilterMode,
    int? searchConcurrency,
    int? searchCacheRetentionDays,
    String? searchScope,
    List<String>? searchScopeSourceUrls,
    bool? searchShowCover,
    bool? bookInfoDeleteAlert,
    bool? syncBookProgress,
    bool? syncBookProgressPlus,
    String? webDavUrl,
    String? webDavAccount,
    String? webDavPassword,
    String? webDavDir,
    String? webDavDeviceName,
    bool? onlyLatestBackup,
    bool? autoCheckNewBackup,
    String? backupPath,
  }) {
    return AppSettings(
      appearanceMode: appearanceMode ?? this.appearanceMode,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      autoUpdateSources: autoUpdateSources ?? this.autoUpdateSources,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      defaultToRead: defaultToRead ?? this.defaultToRead,
      showDiscovery: showDiscovery ?? this.showDiscovery,
      showRss: showRss ?? this.showRss,
      defaultHomePage: defaultHomePage ?? this.defaultHomePage,
      preDownloadNum:
          (preDownloadNum ?? this.preDownloadNum).clamp(0, 9999).toInt(),
      threadCount: (threadCount ?? this.threadCount).clamp(1, 999).toInt(),
      bitmapCacheSize:
          (bitmapCacheSize ?? this.bitmapCacheSize).clamp(1, 2047).toInt(),
      imageRetainNum:
          (imageRetainNum ?? this.imageRetainNum).clamp(0, 999).toInt(),
      replaceEnableDefault: replaceEnableDefault ?? this.replaceEnableDefault,
      processText: processText ?? this.processText,
      recordLog: recordLog ?? this.recordLog,
      recordHeapDump: recordHeapDump ?? this.recordHeapDump,
      bookshelfViewMode: bookshelfViewMode ?? this.bookshelfViewMode,
      bookshelfSortMode: bookshelfSortMode ?? this.bookshelfSortMode,
      bookshelfGroupStyle: bookshelfGroupStyle ?? this.bookshelfGroupStyle,
      bookshelfLayoutIndex: bookshelfLayoutIndex ?? this.bookshelfLayoutIndex,
      bookshelfSortIndex: bookshelfSortIndex ?? this.bookshelfSortIndex,
      bookshelfShowUnread: bookshelfShowUnread ?? this.bookshelfShowUnread,
      bookshelfShowLastUpdateTime:
          bookshelfShowLastUpdateTime ?? this.bookshelfShowLastUpdateTime,
      bookshelfShowWaitUpCount:
          bookshelfShowWaitUpCount ?? this.bookshelfShowWaitUpCount,
      bookshelfShowFastScroller:
          bookshelfShowFastScroller ?? this.bookshelfShowFastScroller,
      searchFilterMode: searchFilterMode ?? this.searchFilterMode,
      searchConcurrency: searchConcurrency ?? this.searchConcurrency,
      searchCacheRetentionDays:
          searchCacheRetentionDays ?? this.searchCacheRetentionDays,
      searchScope: searchScope ?? this.searchScope,
      searchScopeSourceUrls:
          searchScopeSourceUrls ?? this.searchScopeSourceUrls,
      searchShowCover: searchShowCover ?? this.searchShowCover,
      bookInfoDeleteAlert: bookInfoDeleteAlert ?? this.bookInfoDeleteAlert,
      syncBookProgress: syncBookProgress ?? this.syncBookProgress,
      syncBookProgressPlus: syncBookProgressPlus ?? this.syncBookProgressPlus,
      webDavUrl: webDavUrl ?? this.webDavUrl,
      webDavAccount: webDavAccount ?? this.webDavAccount,
      webDavPassword: webDavPassword ?? this.webDavPassword,
      webDavDir: webDavDir ?? this.webDavDir,
      webDavDeviceName: webDavDeviceName ?? this.webDavDeviceName,
      onlyLatestBackup: onlyLatestBackup ?? this.onlyLatestBackup,
      autoCheckNewBackup: autoCheckNewBackup ?? this.autoCheckNewBackup,
      backupPath: backupPath ?? this.backupPath,
    );
  }
}
