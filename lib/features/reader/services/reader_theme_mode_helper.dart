import 'package:flutter/cupertino.dart';

import '../../../core/models/app_settings.dart';
import '../models/reading_settings.dart';

/// 阅读器主题模式（对标 legado：白天 / 夜间 / EInk）。
///
/// 说明：
/// - SoupReader 的全局外观由 `AppAppearanceMode` 决定；
/// - 阅读器需要在“跟随系统深色模式”时，自动切换到夜间主题索引；
/// - EInk 模式需要独立主题索引（避免与普通浅色模式混淆）。
enum ReaderThemeMode {
  day,
  night,
  eInk,
}

class ReaderThemeModeHelper {
  const ReaderThemeModeHelper._();

  /// 解析当前阅读器应使用的主题模式。
  ///
  /// 约束：
  /// - `appearanceMode == eInk` 时强制走 EInk；
  /// - 其余情况使用 `effectiveBrightness` 判定日/夜。
  static ReaderThemeMode resolveMode({
    required AppAppearanceMode appearanceMode,
    required Brightness effectiveBrightness,
  }) {
    if (appearanceMode == AppAppearanceMode.eInk) {
      return ReaderThemeMode.eInk;
    }
    return effectiveBrightness == Brightness.dark
        ? ReaderThemeMode.night
        : ReaderThemeMode.day;
  }

  /// 从阅读设置中取出“当前模式”的主题索引。
  static int resolveThemeIndex({
    required ReadingSettings settings,
    required ReaderThemeMode mode,
  }) {
    return switch (mode) {
      ReaderThemeMode.day => settings.themeIndex,
      ReaderThemeMode.night => settings.nightThemeIndex,
      ReaderThemeMode.eInk => settings.eInkThemeIndex,
    };
  }

  /// 更新阅读设置中“当前模式”的主题索引。
  static ReadingSettings updateThemeIndexForMode({
    required ReadingSettings settings,
    required ReaderThemeMode mode,
    required int index,
  }) {
    return switch (mode) {
      ReaderThemeMode.day => settings.copyWith(themeIndex: index),
      ReaderThemeMode.night => settings.copyWith(nightThemeIndex: index),
      ReaderThemeMode.eInk => settings.copyWith(eInkThemeIndex: index),
    };
  }

  /// 样式列表删除某个索引后，平移并裁剪主题索引，避免越界。
  ///
  /// 规则对齐旧逻辑：被删索引 <= 当前索引 时，当前索引向左移动一位。
  static int shiftIndexAfterRemoval({
    required int index,
    required int removedIndex,
    required int newLength,
  }) {
    if (newLength <= 0) {
      return 0;
    }
    var next = index;
    if (removedIndex <= next) {
      next -= 1;
    }
    return next.clamp(0, newLength - 1).toInt();
  }
}

