/// 应用级设置（非阅读页内设置）
///
/// 目标：对标 Legado / 完全阅读器等同类产品的“设置”入口，把常用的全局开关
/// 统一收敛到一个可持久化、可迁移（备份/恢复）的模型里。
library;

import 'app_settings_codec.dart';
import 'app_settings_enums.dart';

export 'app_settings_enums.dart';

class AppSettings {
  static const String defaultWebDavUrl = 'https://dav.jianguoyun.com/dav/';
  static const String defaultLauncherIcon = 'ic_launcher';
  static const String defaultUpdateToVariant = 'default_version';
  static const String officialUpdateToVariant = 'official_version';
  static const String betaReleaseUpdateToVariant = 'beta_release_version';
  static const String betaReleaseAUpdateToVariant = 'beta_releaseA_version';
  static const Set<String> validUpdateToVariants = <String>{
    defaultUpdateToVariant,
    officialUpdateToVariant,
    betaReleaseUpdateToVariant,
    betaReleaseAUpdateToVariant,
  };
  static const int defaultBarElevation = 4;
  static const int defaultFontScale = 0;
  static const int defaultWebPort = 1122;
  static const int defaultBackgroundImageBlurring = 0;
  static const int maxBackgroundImageBlurring = 25;

  static bool isValidUpdateToVariant(String value) {
    return validUpdateToVariants.contains(value.trim());
  }

  static String normalizeUpdateToVariant(String value) {
    final normalized = value.trim();
    if (isValidUpdateToVariant(normalized)) {
      return normalized;
    }
    return defaultUpdateToVariant;
  }

  static String updateToVariantLabel(String value) {
    switch (normalizeUpdateToVariant(value)) {
      case officialUpdateToVariant:
        return '正式版';
      case betaReleaseUpdateToVariant:
        return '测试版';
      case betaReleaseAUpdateToVariant:
        return '共存版';
      case defaultUpdateToVariant:
      default:
        return '当前';
    }
  }

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
  final bool cronet;
  final bool antiAlias;
  final bool mediaButtonOnExit;
  final bool readAloudByMediaButton;
  final bool ignoreAudioFocus;
  final bool pauseReadAloudWhilePhoneCalls;
  final bool readAloudWakeLock;
  final bool readAloudByPage;
  final bool streamReadAloudAudio;
  final bool autoClearExpired;
  final bool showAddToShelfAlert;
  final String updateToVariant;
  final bool showMangaUi;
  final int webPort;
  final bool webServiceWakeLock;
  final bool processText;
  final bool recordLog;
  final bool recordHeapDump;
  final String launcherIcon;
  final bool transparentStatusBar;
  final bool immNavigationBar;
  final int barElevation;
  final int fontScale;
  final String backgroundImage;
  final String backgroundImageNight;
  final int backgroundImageBlurring;
  final int backgroundImageNightBlurring;

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
    this.cronet = false,
    this.antiAlias = false,
    this.mediaButtonOnExit = true,
    this.readAloudByMediaButton = false,
    this.ignoreAudioFocus = false,
    this.pauseReadAloudWhilePhoneCalls = true,
    this.readAloudWakeLock = false,
    this.readAloudByPage = false,
    this.streamReadAloudAudio = false,
    this.autoClearExpired = true,
    this.showAddToShelfAlert = true,
    this.updateToVariant = defaultUpdateToVariant,
    this.showMangaUi = true,
    this.webPort = defaultWebPort,
    this.webServiceWakeLock = false,
    this.processText = true,
    this.recordLog = false,
    this.recordHeapDump = false,
    this.launcherIcon = defaultLauncherIcon,
    this.transparentStatusBar = true,
    this.immNavigationBar = true,
    this.barElevation = defaultBarElevation,
    this.fontScale = defaultFontScale,
    this.backgroundImage = '',
    this.backgroundImageNight = '',
    this.backgroundImageBlurring = defaultBackgroundImageBlurring,
    this.backgroundImageNightBlurring = defaultBackgroundImageBlurring,
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

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      appSettingsFromJson(json);

  Map<String, dynamic> toJson() => appSettingsToJson(this);

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
    bool? cronet,
    bool? antiAlias,
    bool? mediaButtonOnExit,
    bool? readAloudByMediaButton,
    bool? ignoreAudioFocus,
    bool? pauseReadAloudWhilePhoneCalls,
    bool? readAloudWakeLock,
    bool? readAloudByPage,
    bool? streamReadAloudAudio,
    bool? autoClearExpired,
    bool? showAddToShelfAlert,
    String? updateToVariant,
    bool? showMangaUi,
    int? webPort,
    bool? webServiceWakeLock,
    bool? processText,
    bool? recordLog,
    bool? recordHeapDump,
    String? launcherIcon,
    bool? transparentStatusBar,
    bool? immNavigationBar,
    int? barElevation,
    int? fontScale,
    String? backgroundImage,
    String? backgroundImageNight,
    int? backgroundImageBlurring,
    int? backgroundImageNightBlurring,
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
      cronet: cronet ?? this.cronet,
      antiAlias: antiAlias ?? this.antiAlias,
      mediaButtonOnExit: mediaButtonOnExit ?? this.mediaButtonOnExit,
      readAloudByMediaButton:
          readAloudByMediaButton ?? this.readAloudByMediaButton,
      ignoreAudioFocus: ignoreAudioFocus ?? this.ignoreAudioFocus,
      pauseReadAloudWhilePhoneCalls:
          pauseReadAloudWhilePhoneCalls ?? this.pauseReadAloudWhilePhoneCalls,
      readAloudWakeLock: readAloudWakeLock ?? this.readAloudWakeLock,
      readAloudByPage: readAloudByPage ?? this.readAloudByPage,
      streamReadAloudAudio: streamReadAloudAudio ?? this.streamReadAloudAudio,
      autoClearExpired: autoClearExpired ?? this.autoClearExpired,
      showAddToShelfAlert: showAddToShelfAlert ?? this.showAddToShelfAlert,
      updateToVariant: updateToVariant ?? this.updateToVariant,
      showMangaUi: showMangaUi ?? this.showMangaUi,
      webPort: webPort ?? this.webPort,
      webServiceWakeLock: webServiceWakeLock ?? this.webServiceWakeLock,
      processText: processText ?? this.processText,
      recordLog: recordLog ?? this.recordLog,
      recordHeapDump: recordHeapDump ?? this.recordHeapDump,
      launcherIcon: launcherIcon ?? this.launcherIcon,
      transparentStatusBar: transparentStatusBar ?? this.transparentStatusBar,
      immNavigationBar: immNavigationBar ?? this.immNavigationBar,
      barElevation: (barElevation ?? this.barElevation).clamp(0, 32).toInt(),
      fontScale: (fontScale ?? this.fontScale).clamp(0, 16).toInt(),
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundImageNight: backgroundImageNight ?? this.backgroundImageNight,
      backgroundImageBlurring:
          (backgroundImageBlurring ?? this.backgroundImageBlurring)
              .clamp(0, maxBackgroundImageBlurring)
              .toInt(),
      backgroundImageNightBlurring:
          (backgroundImageNightBlurring ?? this.backgroundImageNightBlurring)
              .clamp(0, maxBackgroundImageBlurring)
              .toInt(),
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
