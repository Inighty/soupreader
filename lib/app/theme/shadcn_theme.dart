import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'design_tokens.dart';

class AppShadcnTheme {
  AppShadcnTheme._();

  static ShadThemeData light() {
    return ShadThemeData(
      brightness: Brightness.light,
      radius: const BorderRadius.all(
        Radius.circular(AppDesignTokens.radiusControl),
      ),
      colorScheme: const ShadSlateColorScheme.light(
        background: AppDesignTokens.pageBgLight,
        foreground: AppDesignTokens.textStrong,
        card: AppDesignTokens.surfaceLight,
        cardForeground: AppDesignTokens.textStrong,
        popover: AppDesignTokens.surfaceLight,
        popoverForeground: AppDesignTokens.textStrong,
        primary: AppDesignTokens.brandPrimary,
        primaryForeground: Color(0xFFFFFFFF),
        destructive: AppDesignTokens.error,
        destructiveForeground: Color(0xFFFFFFFF),
        border: AppDesignTokens.borderLight,
        input: AppDesignTokens.borderLight,
        ring: AppDesignTokens.brandPrimary,
      ),
    );
  }

  static ShadThemeData dark() {
    return ShadThemeData(
      brightness: Brightness.dark,
      radius: const BorderRadius.all(
        Radius.circular(AppDesignTokens.radiusControl),
      ),
      colorScheme: const ShadSlateColorScheme.dark(
        background: AppDesignTokens.pageBgDark,
        foreground: AppDesignTokens.textInverse,
        card: AppDesignTokens.surfaceDark,
        cardForeground: AppDesignTokens.textInverse,
        popover: AppDesignTokens.surfaceDark,
        popoverForeground: AppDesignTokens.textInverse,
        primary: AppDesignTokens.brandSecondary,
        primaryForeground: AppDesignTokens.textStrong,
        destructive: AppDesignTokens.error,
        destructiveForeground: Color(0xFFFFFFFF),
        border: AppDesignTokens.borderDark,
        input: AppDesignTokens.borderDark,
        ring: AppDesignTokens.brandSecondary,
      ),
    );
  }
}

