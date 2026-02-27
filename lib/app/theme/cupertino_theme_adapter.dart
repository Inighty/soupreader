import 'package:flutter/cupertino.dart';

import 'cupertino_theme.dart';
import 'design_tokens.dart';

/// 基于现有 Design Token 的轻量语义主题快照。
///
/// 该结构用于替代旧的 Shad 主题数据，避免依赖 ShadTheme 上下文。
class AppThemeTokens {
  final Brightness brightness;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color mutedForeground;
  final BorderRadiusGeometry controlRadius;

  const AppThemeTokens({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.mutedForeground,
    required this.controlRadius,
  });
}

/// Cupertino 壳层下的主题适配入口。
class AppCupertinoThemeAdapter {
  AppCupertinoThemeAdapter._();

  static CupertinoThemeData cupertinoTheme(Brightness brightness) {
    return AppCupertinoTheme.build(brightness);
  }

  static AppThemeTokens resolve(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final brightness = theme.brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;
    return fromBrightness(brightness);
  }

  static AppThemeTokens fromBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppThemeTokens(
      brightness: brightness,
      background:
          isDark ? AppDesignTokens.pageBgDark : AppDesignTokens.pageBgLight,
      foreground:
          isDark ? AppDesignTokens.textInverse : AppDesignTokens.textStrong,
      card: isDark ? AppDesignTokens.surfaceDark : AppDesignTokens.surfaceLight,
      cardForeground:
          isDark ? AppDesignTokens.textInverse : AppDesignTokens.textStrong,
      popover:
          isDark ? AppDesignTokens.surfaceDark : AppDesignTokens.surfaceLight,
      popoverForeground:
          isDark ? AppDesignTokens.textInverse : AppDesignTokens.textStrong,
      primary: isDark
          ? AppDesignTokens.brandSecondary
          : AppDesignTokens.brandPrimary,
      primaryForeground:
          isDark ? AppDesignTokens.textStrong : const Color(0xFFFFFFFF),
      destructive: AppDesignTokens.error,
      destructiveForeground: const Color(0xFFFFFFFF),
      border: isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight,
      input: isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight,
      ring: isDark
          ? AppDesignTokens.brandSecondary
          : AppDesignTokens.brandPrimary,
      mutedForeground: isDark
          ? AppDesignTokens.textMuted.withValues(alpha: 0.92)
          : AppDesignTokens.textNormal.withValues(alpha: 0.74),
      controlRadius: const BorderRadius.all(
        Radius.circular(AppDesignTokens.radiusControl),
      ),
    );
  }
}
