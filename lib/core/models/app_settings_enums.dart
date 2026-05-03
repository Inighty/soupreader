/// 应用外观模式与书架/搜索相关枚举及其转换函数。
///
/// 从 `app_settings.dart` 抽离以缩短主类行数，外部仍可通过
/// `app_settings.dart` 的重导出访问这些公开符号。
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
