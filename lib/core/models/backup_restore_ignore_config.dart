class BackupRestoreIgnoreOption {
  final String key;
  final String title;

  const BackupRestoreIgnoreOption({
    required this.key,
    required this.title,
  });
}

class BackupRestoreIgnoreConfig {
  static const String readConfigKey = 'readConfig';
  static const String themeModeKey = 'themeMode';
  static const String themeConfigKey = 'themeConfig';
  static const String coverConfigKey = 'coverConfig';
  static const String bookshelfLayoutKey = 'bookshelfLayout';
  static const String showRssKey = 'showRss';
  static const String threadCountKey = 'threadCount';
  static const String localBookKey = 'localBook';

  static const List<BackupRestoreIgnoreOption> options =
      <BackupRestoreIgnoreOption>[
    BackupRestoreIgnoreOption(key: readConfigKey, title: '阅读设置'),
    BackupRestoreIgnoreOption(key: themeModeKey, title: '主题模式'),
    BackupRestoreIgnoreOption(key: themeConfigKey, title: '主题配置'),
    BackupRestoreIgnoreOption(key: coverConfigKey, title: '封面配置'),
    BackupRestoreIgnoreOption(key: bookshelfLayoutKey, title: '书架布局'),
    BackupRestoreIgnoreOption(key: showRssKey, title: '显示订阅'),
    BackupRestoreIgnoreOption(key: threadCountKey, title: '线程数量'),
    BackupRestoreIgnoreOption(key: localBookKey, title: '本地书籍'),
  ];

  static const Map<String, bool> _defaultValues = <String, bool>{};

  final Map<String, bool> ignoredMap;

  const BackupRestoreIgnoreConfig({
    this.ignoredMap = _defaultValues,
  });

  bool isIgnored(String key) {
    return ignoredMap[key] == true;
  }

  bool get ignoreReadConfig => isIgnored(readConfigKey);
  bool get ignoreThemeMode => isIgnored(themeModeKey);
  bool get ignoreThemeConfig => isIgnored(themeConfigKey);
  bool get ignoreCoverConfig => isIgnored(coverConfigKey);
  bool get ignoreBookshelfLayout => isIgnored(bookshelfLayoutKey);
  bool get ignoreShowRss => isIgnored(showRssKey);
  bool get ignoreThreadCount => isIgnored(threadCountKey);
  bool get ignoreLocalBook => isIgnored(localBookKey);
  bool get hasSelection => selectedCount > 0;

  List<BackupRestoreIgnoreOption> get selectedOptions {
    final out = <BackupRestoreIgnoreOption>[];
    for (final option in options) {
      if (!isIgnored(option.key)) continue;
      out.add(option);
    }
    return List<BackupRestoreIgnoreOption>.unmodifiable(out);
  }

  List<String> get selectedTitles {
    return List<String>.unmodifiable(
      selectedOptions.map((option) => option.title),
    );
  }

  int get selectedCount {
    var count = 0;
    for (final option in options) {
      if (isIgnored(option.key)) {
        count++;
      }
    }
    return count;
  }

  String summary({
    int maxItems = 2,
    String emptyText = '不忽略',
  }) {
    if (!hasSelection) return emptyText;
    final titles = selectedTitles;
    if (titles.length <= maxItems) {
      return titles.join('、');
    }
    final visible = titles.take(maxItems).join('、');
    return '$visible 等 ${titles.length} 项';
  }

  BackupRestoreIgnoreConfig copyWith({
    Map<String, bool>? ignoredMap,
  }) {
    return BackupRestoreIgnoreConfig(
      ignoredMap: ignoredMap ?? this.ignoredMap,
    );
  }

  BackupRestoreIgnoreConfig toggle(String key, bool enabled) {
    final next = Map<String, bool>.from(ignoredMap);
    if (enabled) {
      next[key] = true;
    } else {
      next.remove(key);
    }
    return BackupRestoreIgnoreConfig(
      ignoredMap: Map<String, bool>.unmodifiable(next),
    );
  }

  Map<String, dynamic> toJson() {
    final out = <String, bool>{};
    for (final option in options) {
      out[option.key] = isIgnored(option.key);
    }
    return out;
  }

  factory BackupRestoreIgnoreConfig.fromJson(dynamic raw) {
    if (raw is! Map) {
      return const BackupRestoreIgnoreConfig();
    }
    final parsed = <String, bool>{};
    for (final option in options) {
      final value = raw[option.key];
      final enabled = switch (value) {
        bool b => b,
        num n => n != 0,
        String s => s.trim().toLowerCase() == 'true' || s.trim() == '1',
        _ => false,
      };
      if (enabled) {
        parsed[option.key] = true;
      }
    }
    return BackupRestoreIgnoreConfig(
      ignoredMap: Map<String, bool>.unmodifiable(parsed),
    );
  }
}
