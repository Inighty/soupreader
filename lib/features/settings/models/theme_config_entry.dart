import 'dart:convert';

/// 主题配置项（对齐 legado `ThemeConfig.Config` 字段形状）。
class ThemeConfigEntry {
  const ThemeConfigEntry({
    required this.themeName,
    required this.isNightTheme,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.bottomBackground,
  });

  final String themeName;
  final bool isNightTheme;
  final String primaryColor;
  final String accentColor;
  final String backgroundColor;
  final String bottomBackground;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'themeName': themeName,
      'isNightTheme': isNightTheme,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'backgroundColor': backgroundColor,
      'bottomBackground': bottomBackground,
    };
  }

  String toJsonText() {
    return jsonEncode(toJson());
  }

  /// 从“当前主题快照”构建配置项；用于保存白天/夜间主题。
  static ThemeConfigEntry? tryCreate({
    required String themeName,
    required bool isNightTheme,
    required String primaryColor,
    required String accentColor,
    required String backgroundColor,
    required String bottomBackground,
  }) {
    final config = ThemeConfigEntry(
      themeName: themeName.trim(),
      isNightTheme: isNightTheme,
      primaryColor: primaryColor.trim(),
      accentColor: accentColor.trim(),
      backgroundColor: backgroundColor.trim(),
      bottomBackground: bottomBackground.trim(),
    );
    if (!config._validateColors()) {
      return null;
    }
    return config;
  }

  static ThemeConfigEntry? tryParseJsonText(String rawText) {
    final normalized = rawText.trim();
    if (normalized.isEmpty) return null;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is! Map) return null;
      final mapped = decoded.map<String, dynamic>(
        (key, value) => MapEntry('$key', value),
      );
      return tryParseJsonObject(mapped);
    } catch (_) {
      return null;
    }
  }

  static ThemeConfigEntry? tryParseJsonObject(Map<String, dynamic> json) {
    final themeName = _parseRequiredString(json['themeName']);
    final isNightTheme = _parseRequiredBool(json['isNightTheme']);
    final primaryColor = _parseRequiredString(json['primaryColor']);
    final accentColor = _parseRequiredString(json['accentColor']);
    final backgroundColor = _parseRequiredString(json['backgroundColor']);
    final bottomBackground = _parseRequiredString(json['bottomBackground']);
    if (themeName == null ||
        isNightTheme == null ||
        primaryColor == null ||
        accentColor == null ||
        backgroundColor == null ||
        bottomBackground == null) {
      return null;
    }
    return tryCreate(
      themeName: themeName,
      isNightTheme: isNightTheme,
      primaryColor: primaryColor,
      accentColor: accentColor,
      backgroundColor: backgroundColor,
      bottomBackground: bottomBackground,
    );
  }

  bool _validateColors() {
    return _isValidHexColor(primaryColor) &&
        _isValidHexColor(accentColor) &&
        _isValidHexColor(backgroundColor) &&
        _isValidHexColor(bottomBackground);
  }

  static String? _parseRequiredString(dynamic value) {
    if (value == null) return null;
    return value.toString().trim();
  }

  static bool? _parseRequiredBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static bool _isValidHexColor(String value) {
    final text = value.trim();
    if (!text.startsWith('#')) return false;
    final hex = text.substring(1);
    if (hex.length != 6 && hex.length != 8) return false;
    return int.tryParse(hex, radix: 16) != null;
  }
}
