class CheckSourceSettings {
  static const int defaultTimeoutMs = 180000;

  final int timeoutMs;
  final bool checkSearch;
  final bool checkDiscovery;
  final bool checkInfo;
  final bool checkCategory;
  final bool checkContent;

  const CheckSourceSettings({
    this.timeoutMs = defaultTimeoutMs,
    this.checkSearch = true,
    this.checkDiscovery = true,
    this.checkInfo = true,
    this.checkCategory = true,
    this.checkContent = true,
  });

  factory CheckSourceSettings.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic raw, bool fallback) {
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

    return CheckSourceSettings(
      timeoutMs: parseInt(json['timeoutMs'], defaultTimeoutMs),
      checkSearch: parseBool(json['checkSearch'], true),
      checkDiscovery: parseBool(json['checkDiscovery'], true),
      checkInfo: parseBool(json['checkInfo'], true),
      checkCategory: parseBool(json['checkCategory'], true),
      checkContent: parseBool(json['checkContent'], true),
    ).normalized();
  }

  Map<String, dynamic> toJson() {
    final normalized = this.normalized();
    return {
      'timeoutMs': normalized.timeoutMs,
      'checkSearch': normalized.checkSearch,
      'checkDiscovery': normalized.checkDiscovery,
      'checkInfo': normalized.checkInfo,
      'checkCategory': normalized.checkCategory,
      'checkContent': normalized.checkContent,
    };
  }

  CheckSourceSettings copyWith({
    int? timeoutMs,
    bool? checkSearch,
    bool? checkDiscovery,
    bool? checkInfo,
    bool? checkCategory,
    bool? checkContent,
  }) {
    return CheckSourceSettings(
      timeoutMs: timeoutMs ?? this.timeoutMs,
      checkSearch: checkSearch ?? this.checkSearch,
      checkDiscovery: checkDiscovery ?? this.checkDiscovery,
      checkInfo: checkInfo ?? this.checkInfo,
      checkCategory: checkCategory ?? this.checkCategory,
      checkContent: checkContent ?? this.checkContent,
    );
  }

  CheckSourceSettings normalized() {
    final normalizedTimeoutMs = timeoutMs > 0 ? timeoutMs : defaultTimeoutMs;
    var normalizedCheckSearch = checkSearch;
    var normalizedCheckDiscovery = checkDiscovery;
    if (!normalizedCheckSearch && !normalizedCheckDiscovery) {
      normalizedCheckDiscovery = true;
    }
    final normalizedCheckInfo = checkInfo;
    final normalizedCheckCategory = normalizedCheckInfo && checkCategory;
    final normalizedCheckContent = normalizedCheckCategory && checkContent;
    return CheckSourceSettings(
      timeoutMs: normalizedTimeoutMs,
      checkSearch: normalizedCheckSearch,
      checkDiscovery: normalizedCheckDiscovery,
      checkInfo: normalizedCheckInfo,
      checkCategory: normalizedCheckCategory,
      checkContent: normalizedCheckContent,
    );
  }

  String summary() {
    final normalized = this.normalized();
    final checkItems = <String>[
      if (normalized.checkSearch) '搜索',
      if (normalized.checkDiscovery) '发现',
      if (normalized.checkInfo) '详情',
      if (normalized.checkCategory) '目录',
      if (normalized.checkContent) '正文',
    ];
    final checkItemText =
        checkItems.isEmpty ? ' 搜索' : ' ${checkItems.join(' ')}';
    return '校验超时：${normalized.timeoutMs ~/ 1000}秒\n校验项目：$checkItemText';
  }
}
