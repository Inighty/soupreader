import 'reading_settings.dart';

/// 一组用于 `sanitize` / `fromJson` 的纯函数：把任意 `dynamic` 值
/// 归一成业务字段允许的范围/类型。原本以 private static 方法挂在
/// `ReadingSettings` 上，抽离出来便于重用与瘦身主类。
class ReadingSettingsHelpers {
  ReadingSettingsHelpers._();

  static double toDouble(dynamic raw, double fallback) {
    if (raw is num && raw.isFinite) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  static int toInt(dynamic raw, int fallback) {
    if (raw is num && raw.isFinite) return raw.toInt();
    if (raw is String) {
      return int.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  static bool toBool(dynamic raw, bool fallback) {
    if (raw is bool) return raw;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    if (raw is num) return raw != 0;
    return fallback;
  }

  static bool isCloseTo(double value, double target) {
    return (value - target).abs() < 0.0001;
  }

  static double safeDouble(
    double value, {
    required double min,
    required double max,
    required double fallback,
  }) {
    if (value.isNaN || value.isInfinite) return fallback;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int safeInt(
    int value, {
    required int min,
    required int max,
    required int fallback,
  }) {
    if (value < min || value > max) return fallback;
    return value;
  }

  static int normalizeColorInt(
    int value, {
    required int fallback,
    required bool allowNegativeOne,
    required bool allowZero,
  }) {
    if (value == -1 && allowNegativeOne) return value;
    if (value == 0 && allowZero) return value;
    if (value > 0 && value <= 0xFFFFFFFF) return value;
    return fallback;
  }

  static List<int> normalizeKeyCodeList(List<int> raw) {
    if (raw.isEmpty) return const <int>[];
    final normalizedSet = <int>{};
    for (final code in raw) {
      if (code > 0) normalizedSet.add(code);
    }
    if (normalizedSet.isEmpty) return const <int>[];
    final sorted = normalizedSet.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  static bool _isValidKeepLightSeconds(int value) {
    return value == ReadingSettings.keepLightFollowSystem ||
        value == ReadingSettings.keepLightOneMinute ||
        value == ReadingSettings.keepLightFiveMinutes ||
        value == ReadingSettings.keepLightTenMinutes ||
        value == ReadingSettings.keepLightAlways;
  }

  static int normalizeKeepLightSeconds(int value, {required int fallback}) {
    if (_isValidKeepLightSeconds(value)) return value;
    if (_isValidKeepLightSeconds(fallback)) return fallback;
    return ReadingSettings.keepLightFollowSystem;
  }
}
