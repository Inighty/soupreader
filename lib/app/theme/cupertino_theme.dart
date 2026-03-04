import 'package:flutter/cupertino.dart';

import 'design_tokens.dart';
import 'typography.dart';

/// 全局 Cupertino 视觉主题（作用于全页面）。
class AppCupertinoTheme {
  AppCupertinoTheme._();

  static CupertinoThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBackground =
        isDark ? AppDesignTokens.pageBgDark : AppDesignTokens.pageBgLight;
    final textColor =
        isDark ? AppDesignTokens.textInverse : AppDesignTokens.textStrong;
    final secondaryText = isDark
        ? AppDesignTokens.textInverse.withValues(alpha: 0.74)
        : AppDesignTokens.textMuted;
    final actionColor =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: actionColor,
      scaffoldBackgroundColor: scaffoldBackground,
      barBackgroundColor: navBarBackground(brightness, scaffoldBackground),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: textColor,
          fontSize: 16,
          height: 1.35,
          letterSpacing: -0.08,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.24,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: textColor,
          fontSize: 33,
          fontWeight: FontWeight.w700,
          height: 1.18,
          letterSpacing: -0.5,
        ),
        actionTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: actionColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.08,
        ),
        tabLabelTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  static Color navBarBackground(
    Brightness brightness,
    Color scaffoldBackground,
  ) {
    final glass = brightness == Brightness.dark
        ? AppDesignTokens.glassDarkMaterial
        : AppDesignTokens.glassLightMaterial;
    return Color.alphaBlend(glass, scaffoldBackground);
  }

  static Color tabBarBackground(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? AppDesignTokens.surfaceDark
        : AppDesignTokens.surfaceLight;
    final glass = brightness == Brightness.dark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: 0.94)
        : AppDesignTokens.glassLightMaterial.withValues(alpha: 0.94);
    return Color.alphaBlend(glass, base);
  }

  static Color tabBarActive(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  static Color tabBarInactive(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.textInverse.withValues(alpha: 0.62)
        : AppDesignTokens.textMuted.withValues(alpha: 0.9);
  }

  static Border tabBarBorder(Brightness brightness) {
    final bezel = brightness == Brightness.dark
        ? AppDesignTokens.glassInnerHighlightDark
        : AppDesignTokens.glassInnerHighlightLight;
    final separator = brightness == Brightness.dark
        ? AppDesignTokens.borderDark.withValues(alpha: 0.9)
        : AppDesignTokens.borderLight.withValues(alpha: 0.9);
    return Border(
      top: BorderSide(
          color: separator, width: AppDesignTokens.hairlineBorderWidth),
      bottom:
          BorderSide(color: bezel, width: AppDesignTokens.hairlineBorderWidth),
    );
  }
}
