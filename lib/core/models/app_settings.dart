/// 应用级设置（非阅读页内设置）
///
/// 目标：对标 Legado / 完全阅读器等同类产品的“设置”入口，把常用的全局开关
/// 统一收敛到一个可持久化、可迁移（备份/恢复）的模型里。
enum AppAppearanceMode {
  followSystem,
  light,
  dark,
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

class AppSettings {
  final AppAppearanceMode appearanceMode;
  final bool wifiOnlyDownload;
  final bool autoUpdateSources;

  final BookshelfViewMode bookshelfViewMode;
  final BookshelfSortMode bookshelfSortMode;

  const AppSettings({
    this.appearanceMode = AppAppearanceMode.followSystem,
    this.wifiOnlyDownload = true,
    this.autoUpdateSources = true,
    this.bookshelfViewMode = BookshelfViewMode.grid,
    this.bookshelfSortMode = BookshelfSortMode.recentRead,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    AppAppearanceMode parseAppearanceMode(dynamic raw) {
      final index = raw is int
          ? raw
          : raw is num
              ? raw.toInt()
              : null;
      if (index == null) return AppAppearanceMode.followSystem;
      return AppAppearanceMode.values[
          index.clamp(0, AppAppearanceMode.values.length - 1)];
    }

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

    return AppSettings(
      appearanceMode: parseAppearanceMode(json['appearanceMode']),
      wifiOnlyDownload: json['wifiOnlyDownload'] as bool? ?? true,
      autoUpdateSources: json['autoUpdateSources'] as bool? ?? true,
      bookshelfViewMode: parseViewMode(json['bookshelfViewMode']),
      bookshelfSortMode: parseSortMode(json['bookshelfSortMode']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appearanceMode': appearanceMode.index,
      'wifiOnlyDownload': wifiOnlyDownload,
      'autoUpdateSources': autoUpdateSources,
      'bookshelfViewMode': bookshelfViewMode.index,
      'bookshelfSortMode': bookshelfSortMode.index,
    };
  }

  AppSettings copyWith({
    AppAppearanceMode? appearanceMode,
    bool? wifiOnlyDownload,
    bool? autoUpdateSources,
    BookshelfViewMode? bookshelfViewMode,
    BookshelfSortMode? bookshelfSortMode,
  }) {
    return AppSettings(
      appearanceMode: appearanceMode ?? this.appearanceMode,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      autoUpdateSources: autoUpdateSources ?? this.autoUpdateSources,
      bookshelfViewMode: bookshelfViewMode ?? this.bookshelfViewMode,
      bookshelfSortMode: bookshelfSortMode ?? this.bookshelfSortMode,
    );
  }
}

