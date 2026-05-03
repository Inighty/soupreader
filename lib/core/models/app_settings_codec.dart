import 'app_settings.dart';

/// 把 [AppSettings] 的 fromJson / toJson 编解码逻辑从主类抽离出来，
/// 让 `app_settings.dart` 仅保留字段、构造与 [AppSettings.copyWith]。
///
/// 外部不应直接调用本文件的函数；继续使用 `AppSettings.fromJson` /
/// `appSettings.toJson()`。
AppSettings appSettingsFromJson(Map<String, dynamic> json) {
  final legacyScopeSourceUrls = _parseStringList(json['searchScopeSourceUrls']);
  var parsedSearchScope = _parseString(json['searchScope']);
  if (parsedSearchScope.isEmpty && legacyScopeSourceUrls.length == 1) {
    parsedSearchScope = '::${legacyScopeSourceUrls.first}';
  }
  final hasLegacyLayoutIndex = json.containsKey('bookshelfLayoutIndex') ||
      json.containsKey('bookshelfLayout');
  final parsedLayoutIndex = _parseIntWithDefault(
    json['bookshelfLayoutIndex'] ?? json['bookshelfLayout'],
    bookshelfLayoutIndexFromViewMode(_parseViewMode(json['bookshelfViewMode'])),
  ).clamp(0, 4);
  final hasLegacySortIndex = json.containsKey('bookshelfSortIndex') ||
      json.containsKey('bookshelfSort');
  final parsedSortIndex = _parseIntWithDefault(
    json['bookshelfSortIndex'] ?? json['bookshelfSort'],
    bookshelfLegacySortIndexFromMode(_parseSortMode(json['bookshelfSortMode'])),
  ).clamp(0, 5);
  final themeSetting = _parseMap(json['theme_setting'] ?? json['themeSetting']);
  final parsedLauncherIcon = _parseString(
    json['launcherIcon'] ?? themeSetting['launcherIcon'],
  );

  return AppSettings(
    appearanceMode: parseAppAppearanceModeFromJson(json),
    wifiOnlyDownload: json['wifiOnlyDownload'] as bool? ?? true,
    autoUpdateSources: json['autoUpdateSources'] as bool? ?? true,
    autoRefresh: _parseBoolWithDefault(
      json['autoRefresh'] ?? json['auto_refresh'],
      false,
    ),
    defaultToRead: _parseBoolWithDefault(json['defaultToRead'], false),
    showDiscovery: _parseBoolWithDefault(json['showDiscovery'], true),
    showRss: _parseBoolWithDefault(json['showRss'] ?? json['showRSS'], true),
    defaultHomePage: _parseDefaultHomePage(json['defaultHomePage']),
    preDownloadNum:
        _parseIntWithDefault(json['preDownloadNum'], 10).clamp(0, 9999),
    threadCount: _parseIntWithDefault(json['threadCount'], 16).clamp(1, 999),
    bitmapCacheSize:
        _parseIntWithDefault(json['bitmapCacheSize'], 50).clamp(1, 2047),
    imageRetainNum:
        _parseIntWithDefault(json['imageRetainNum'], 0).clamp(0, 999),
    replaceEnableDefault:
        _parseBoolWithDefault(json['replaceEnableDefault'], true),
    cronet: _parseBoolWithDefault(json['cronet'] ?? json['Cronet'], false),
    antiAlias: _parseBoolWithDefault(json['antiAlias'], false),
    mediaButtonOnExit: _parseBoolWithDefault(json['mediaButtonOnExit'], true),
    readAloudByMediaButton:
        _parseBoolWithDefault(json['readAloudByMediaButton'], false),
    ignoreAudioFocus: _parseBoolWithDefault(json['ignoreAudioFocus'], false),
    pauseReadAloudWhilePhoneCalls:
        _parseBoolWithDefault(json['pauseReadAloudWhilePhoneCalls'], true),
    readAloudWakeLock: _parseBoolWithDefault(json['readAloudWakeLock'], false),
    readAloudByPage: _parseBoolWithDefault(json['readAloudByPage'], false),
    streamReadAloudAudio:
        _parseBoolWithDefault(json['streamReadAloudAudio'], false),
    autoClearExpired: _parseBoolWithDefault(json['autoClearExpired'], true),
    showAddToShelfAlert:
        _parseBoolWithDefault(json['showAddToShelfAlert'], true),
    updateToVariant: AppSettings.normalizeUpdateToVariant(
      _parseString(
        json['updateToVariant'] ?? AppSettings.defaultUpdateToVariant,
      ),
    ),
    showMangaUi: _parseBoolWithDefault(json['showMangaUi'], true),
    webPort:
        _parseIntWithDefault(json['webPort'], AppSettings.defaultWebPort),
    webServiceWakeLock:
        _parseBoolWithDefault(json['webServiceWakeLock'], false),
    processText: _parseBoolWithDefault(
      json['processText'] ?? json['process_text'],
      true,
    ),
    recordLog: _parseBoolWithDefault(json['recordLog'], false),
    recordHeapDump: _parseBoolWithDefault(json['recordHeapDump'], false),
    launcherIcon: parsedLauncherIcon.isEmpty
        ? AppSettings.defaultLauncherIcon
        : parsedLauncherIcon,
    transparentStatusBar: _parseBoolWithDefault(
      json['transparentStatusBar'] ?? themeSetting['transparentStatusBar'],
      true,
    ),
    immNavigationBar: _parseBoolWithDefault(
      json['immNavigationBar'] ?? themeSetting['immNavigationBar'],
      true,
    ),
    barElevation: _parseIntWithDefault(
      json['barElevation'] ?? themeSetting['barElevation'],
      AppSettings.defaultBarElevation,
    ).clamp(0, 32),
    fontScale: _parseIntWithDefault(
      json['fontScale'] ?? themeSetting['fontScale'],
      AppSettings.defaultFontScale,
    ).clamp(0, 16),
    backgroundImage: _parseString(
      json['backgroundImage'] ??
          json['bgImage'] ??
          themeSetting['backgroundImage'] ??
          themeSetting['bgImage'],
    ),
    backgroundImageNight: _parseString(
      json['backgroundImageNight'] ??
          json['bgImageN'] ??
          themeSetting['backgroundImageNight'] ??
          themeSetting['bgImageN'],
    ),
    backgroundImageBlurring: _parseIntWithDefault(
      json['backgroundImageBlurring'] ??
          json['bgImageBlurring'] ??
          themeSetting['backgroundImageBlurring'] ??
          themeSetting['bgImageBlurring'],
      AppSettings.defaultBackgroundImageBlurring,
    ).clamp(0, AppSettings.maxBackgroundImageBlurring),
    backgroundImageNightBlurring: _parseIntWithDefault(
      json['backgroundImageNightBlurring'] ??
          json['bgImageNBlurring'] ??
          themeSetting['backgroundImageNightBlurring'] ??
          themeSetting['bgImageNBlurring'],
      AppSettings.defaultBackgroundImageBlurring,
    ).clamp(0, AppSettings.maxBackgroundImageBlurring),
    bookshelfViewMode: hasLegacyLayoutIndex
        ? bookshelfViewModeFromLayoutIndex(parsedLayoutIndex)
        : _parseViewMode(json['bookshelfViewMode']),
    bookshelfSortMode: hasLegacySortIndex
        ? bookshelfSortModeFromLegacyIndex(parsedSortIndex)
        : _parseSortMode(json['bookshelfSortMode']),
    bookshelfGroupStyle: _parseIntWithDefault(
            json['bookshelfGroupStyle'] ?? json['bookGroupStyle'], 0)
        .clamp(0, 1),
    bookshelfLayoutIndex: parsedLayoutIndex,
    bookshelfSortIndex: parsedSortIndex,
    bookshelfShowUnread: _parseBoolWithDefault(
      json['bookshelfShowUnread'] ?? json['showUnread'],
      true,
    ),
    bookshelfShowLastUpdateTime: _parseBoolWithDefault(
      json['bookshelfShowLastUpdateTime'] ?? json['showLastUpdateTime'],
      false,
    ),
    bookshelfShowWaitUpCount: _parseBoolWithDefault(
      json['bookshelfShowWaitUpCount'] ?? json['showWaitUpCount'],
      false,
    ),
    bookshelfShowFastScroller: _parseBoolWithDefault(
      json['bookshelfShowFastScroller'] ?? json['showBookshelfFastScroller'],
      false,
    ),
    searchFilterMode: normalizeSearchFilterMode(
        _parseSearchFilterMode(json['searchFilterMode'])),
    searchConcurrency:
        _parseIntWithDefault(json['searchConcurrency'], 8).clamp(2, 12),
    searchCacheRetentionDays:
        _parseIntWithDefault(json['searchCacheRetentionDays'], 5).clamp(1, 30),
    searchScope: parsedSearchScope,
    searchScopeSourceUrls: legacyScopeSourceUrls,
    searchShowCover: json['searchShowCover'] as bool? ?? true,
    bookInfoDeleteAlert:
        _parseBoolWithDefault(json['bookInfoDeleteAlert'], true),
    syncBookProgress: _parseBoolWithDefault(
      json['syncBookProgress'] ?? json['sync_book_progress'],
      true,
    ),
    syncBookProgressPlus: _parseBoolWithDefault(
      json['syncBookProgressPlus'] ?? json['sync_book_progress_plus'],
      false,
    ),
    webDavUrl: _parseString(
      json['webDavUrl'] ?? json['webdavUrl'] ?? AppSettings.defaultWebDavUrl,
    ),
    webDavAccount: _parseString(
      json['webDavAccount'] ?? json['webdavAccount'],
    ),
    webDavPassword: _parseString(
      json['webDavPassword'] ?? json['webdavPassword'],
    ),
    webDavDir: _parseString(json['webDavDir'] ?? json['webdavDir']),
    webDavDeviceName: _parseString(
      json['webDavDeviceName'] ?? json['webdavDeviceName'],
    ),
    onlyLatestBackup: _parseBoolWithDefault(
      json['onlyLatestBackup'] ?? json['only_latest_backup'],
      true,
    ),
    autoCheckNewBackup: _parseBoolWithDefault(
      json['autoCheckNewBackup'] ?? json['auto_check_new_backup'],
      true,
    ),
    backupPath: _parseString(json['backupPath'] ?? json['backupUri']),
  );
}

Map<String, dynamic> appSettingsToJson(AppSettings settings) {
  final appearanceModeValue =
      appAppearanceModeToLegacyValue(settings.appearanceMode);
  return {
    'appearanceMode': appearanceModeValue,
    'themeMode': appearanceModeValue,
    'wifiOnlyDownload': settings.wifiOnlyDownload,
    'autoUpdateSources': settings.autoUpdateSources,
    'autoRefresh': settings.autoRefresh,
    'auto_refresh': settings.autoRefresh,
    'defaultToRead': settings.defaultToRead,
    'showDiscovery': settings.showDiscovery,
    'showRss': settings.showRss,
    'defaultHomePage': settings.defaultHomePage.name,
    'preDownloadNum': settings.preDownloadNum,
    'threadCount': settings.threadCount,
    'bitmapCacheSize': settings.bitmapCacheSize,
    'imageRetainNum': settings.imageRetainNum,
    'replaceEnableDefault': settings.replaceEnableDefault,
    'cronet': settings.cronet,
    'Cronet': settings.cronet,
    'antiAlias': settings.antiAlias,
    'mediaButtonOnExit': settings.mediaButtonOnExit,
    'readAloudByMediaButton': settings.readAloudByMediaButton,
    'ignoreAudioFocus': settings.ignoreAudioFocus,
    'pauseReadAloudWhilePhoneCalls': settings.pauseReadAloudWhilePhoneCalls,
    'readAloudWakeLock': settings.readAloudWakeLock,
    'readAloudByPage': settings.readAloudByPage,
    'streamReadAloudAudio': settings.streamReadAloudAudio,
    'autoClearExpired': settings.autoClearExpired,
    'showAddToShelfAlert': settings.showAddToShelfAlert,
    'updateToVariant': settings.updateToVariant,
    'showMangaUi': settings.showMangaUi,
    'webPort': settings.webPort,
    'webServiceWakeLock': settings.webServiceWakeLock,
    'processText': settings.processText,
    'process_text': settings.processText,
    'recordLog': settings.recordLog,
    'recordHeapDump': settings.recordHeapDump,
    'launcherIcon': settings.launcherIcon,
    'transparentStatusBar': settings.transparentStatusBar,
    'immNavigationBar': settings.immNavigationBar,
    'barElevation': settings.barElevation,
    'fontScale': settings.fontScale,
    'backgroundImage': settings.backgroundImage,
    'backgroundImageNight': settings.backgroundImageNight,
    'backgroundImageBlurring': settings.backgroundImageBlurring,
    'backgroundImageNightBlurring': settings.backgroundImageNightBlurring,
    'theme_setting': {
      'launcherIcon': settings.launcherIcon,
      'transparentStatusBar': settings.transparentStatusBar,
      'immNavigationBar': settings.immNavigationBar,
      'barElevation': settings.barElevation,
      'fontScale': settings.fontScale,
      'backgroundImage': settings.backgroundImage,
      'backgroundImageNight': settings.backgroundImageNight,
      'backgroundImageBlurring': settings.backgroundImageBlurring,
      'backgroundImageNightBlurring': settings.backgroundImageNightBlurring,
    },
    'bookshelfViewMode': settings.bookshelfViewMode.index,
    'bookshelfSortMode': settings.bookshelfSortMode.index,
    'bookshelfGroupStyle': settings.bookshelfGroupStyle,
    'bookGroupStyle': settings.bookshelfGroupStyle,
    'bookshelfLayoutIndex': settings.bookshelfLayoutIndex,
    'bookshelfLayout': settings.bookshelfLayoutIndex,
    'bookshelfSortIndex': settings.bookshelfSortIndex,
    'bookshelfSort': settings.bookshelfSortIndex,
    'bookshelfShowUnread': settings.bookshelfShowUnread,
    'showUnread': settings.bookshelfShowUnread,
    'bookshelfShowLastUpdateTime': settings.bookshelfShowLastUpdateTime,
    'showLastUpdateTime': settings.bookshelfShowLastUpdateTime,
    'bookshelfShowWaitUpCount': settings.bookshelfShowWaitUpCount,
    'showWaitUpCount': settings.bookshelfShowWaitUpCount,
    'bookshelfShowFastScroller': settings.bookshelfShowFastScroller,
    'showBookshelfFastScroller': settings.bookshelfShowFastScroller,
    'searchFilterMode':
        normalizeSearchFilterMode(settings.searchFilterMode).index,
    'searchConcurrency': settings.searchConcurrency,
    'searchCacheRetentionDays': settings.searchCacheRetentionDays,
    'searchScope': settings.searchScope,
    'searchScopeSourceUrls': settings.searchScopeSourceUrls,
    'searchShowCover': settings.searchShowCover,
    'bookInfoDeleteAlert': settings.bookInfoDeleteAlert,
    'syncBookProgress': settings.syncBookProgress,
    'sync_book_progress': settings.syncBookProgress,
    'syncBookProgressPlus': settings.syncBookProgressPlus,
    'sync_book_progress_plus': settings.syncBookProgressPlus,
    'webDavUrl': settings.webDavUrl,
    'webDavAccount': settings.webDavAccount,
    'webDavPassword': settings.webDavPassword,
    'webDavDir': settings.webDavDir,
    'webDavDeviceName': settings.webDavDeviceName,
    'webdavDeviceName': settings.webDavDeviceName,
    'onlyLatestBackup': settings.onlyLatestBackup,
    'only_latest_backup': settings.onlyLatestBackup,
    'autoCheckNewBackup': settings.autoCheckNewBackup,
    'auto_check_new_backup': settings.autoCheckNewBackup,
    'backupPath': settings.backupPath,
    'backupUri': settings.backupPath,
  };
}

BookshelfViewMode _parseViewMode(dynamic raw) {
  final index = raw is int
      ? raw
      : raw is num
          ? raw.toInt()
          : null;
  if (index == null) return BookshelfViewMode.grid;
  return BookshelfViewMode
      .values[index.clamp(0, BookshelfViewMode.values.length - 1)];
}

BookshelfSortMode _parseSortMode(dynamic raw) {
  final index = raw is int
      ? raw
      : raw is num
          ? raw.toInt()
          : null;
  if (index == null) return BookshelfSortMode.recentRead;
  return BookshelfSortMode
      .values[index.clamp(0, BookshelfSortMode.values.length - 1)];
}

SearchFilterMode _parseSearchFilterMode(dynamic raw) {
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

MainDefaultHomePage _parseDefaultHomePage(dynamic raw) {
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

int _parseIntWithDefault(dynamic raw, int fallback) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? fallback;
  return fallback;
}

List<String> _parseStringList(dynamic raw) {
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

String _parseString(dynamic raw) {
  if (raw == null) return '';
  return raw.toString().trim();
}

Map<String, dynamic> _parseMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
  return const <String, dynamic>{};
}

bool _parseBoolWithDefault(dynamic raw, bool fallback) {
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
