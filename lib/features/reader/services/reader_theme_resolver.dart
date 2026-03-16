import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../models/reading_settings.dart';
import '../services/reader_theme_mode_helper.dart';

/// Resolves themed colors, font properties, and padding from
/// [ReadingSettings] and [ReaderThemeMode].
///
/// This class contains **no mutable state** — it simply interprets a
/// snapshot of settings into visual properties. Extracted from
/// `_SimpleReaderViewState` to improve testability and reuse.
class ReaderThemeResolver {
  const ReaderThemeResolver({
    required this.settings,
    required this.themeMode,
    required this.readStyleConfigs,
    this.customFontFamily,
  });

  final ReadingSettings settings;
  final ReaderThemeMode themeMode;
  final List<ReadStyleConfig> readStyleConfigs;
  final String? customFontFamily;

  // ── Read-style configs ──

  /// Active configs after sanitization.
  List<ReadStyleConfig> get activeConfigs {
    if (readStyleConfigs.isNotEmpty) {
      return readStyleConfigs
          .map((c) => c.sanitize())
          .toList(growable: false);
    }
    return _defaultConfigs;
  }

  List<ReadStyleConfig> get _defaultConfigs => AppColors.readingThemes
      .map((t) => ReadStyleConfig(
            name: t.name,
            backgroundColor: t.background.toARGB32(),
            textColor: t.text.toARGB32(),
          ))
      .toList(growable: false);

  /// Active read styles as [ReadingThemeColors].
  List<ReadingThemeColors> get activeStyles {
    return activeConfigs
        .map((c) => ReadingThemeColors(
              background: Color(c.backgroundColor),
              text: Color(c.textColor),
              name: c.name.trim().isEmpty ? '文字' : c.name.trim(),
            ))
        .toList(growable: false);
  }

  int get activeStyleIndex {
    final styles = activeConfigs;
    if (styles.isEmpty) return 0;
    final idx = ReaderThemeModeHelper.resolveThemeIndex(
      settings: settings,
      mode: themeMode,
    );
    return idx.clamp(0, styles.length - 1);
  }

  ReadStyleConfig get currentConfig {
    final styles = activeConfigs;
    if (styles.isEmpty) {
      return const ReadStyleConfig(
        name: '',
        backgroundColor: ReadStyleConfig.legacyDefaultBackgroundColor,
        textColor: ReadStyleConfig.legacyDefaultTextColor,
      );
    }
    return styles[activeStyleIndex].sanitize();
  }

  ReadingThemeColors get currentTheme {
    final styles = activeStyles;
    if (styles.isEmpty) return AppColors.readingThemes.first;
    return styles[activeStyleIndex];
  }

  // ── Derived colors ──

  Color get backgroundColor => Color(currentConfig.backgroundColor);

  bool get usesImageBackground {
    final bgType = currentConfig.bgType;
    return bgType == ReadStyleConfig.bgTypeAsset ||
        bgType == ReadStyleConfig.bgTypeFile;
  }

  Color get contentBackgroundColor =>
      usesImageBackground ? const Color(0x00000000) : backgroundColor;

  bool get isDark => currentTheme.isDark;

  bool get menuFollowPageTone =>
      settings.readBarStyleFollowPage && !usesImageBackground;

  Color get accent =>
      isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get panelBg => menuFollowPageTone
      ? backgroundColor
      : (isDark
          ? ReaderOverlayTokens.panelDark
          : ReaderOverlayTokens.panelLight);

  Color get cardBg {
    if (menuFollowPageTone) {
      final overlay = isDark
          ? CupertinoColors.white.withValues(alpha: 0.06)
          : CupertinoColors.black.withValues(alpha: 0.04);
      return Color.alphaBlend(overlay, panelBg);
    }
    return isDark
        ? ReaderOverlayTokens.cardDark
        : ReaderOverlayTokens.cardLight;
  }

  Color get border => menuFollowPageTone
      ? textStrong.withValues(alpha: isDark ? 0.2 : 0.16)
      : (isDark
          ? ReaderOverlayTokens.borderDark
          : ReaderOverlayTokens.borderLight);

  Color get textStrong => menuFollowPageTone
      ? currentTheme.text
      : (isDark
          ? ReaderOverlayTokens.textStrongDark
          : ReaderOverlayTokens.textStrongLight);

  Color get textNormal => menuFollowPageTone
      ? currentTheme.text.withValues(alpha: isDark ? 0.72 : 0.7)
      : (isDark
          ? ReaderOverlayTokens.textNormalDark
          : ReaderOverlayTokens.textNormalLight);

  Color get textSubtle => menuFollowPageTone
      ? currentTheme.text.withValues(alpha: isDark ? 0.56 : 0.52)
      : (isDark
          ? ReaderOverlayTokens.textSubtleDark
          : ReaderOverlayTokens.textSubtleLight);

  // ── Font ──

  String? get fontFamily {
    final custom = customFontFamily?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final family = ReadingFontFamily.getFontFamily(settings.fontFamilyIndex);
    return family.isEmpty ? null : family;
  }

  List<String>? get fontFamilyFallback {
    if (customFontFamily?.trim().isNotEmpty == true) return null;
    final fallback =
        ReadingFontFamily.getFontFamilyFallback(settings.fontFamilyIndex);
    return fallback.isEmpty ? null : fallback;
  }

  FontWeight get fontWeight {
    switch (settings.textBold) {
      case 1:
        return FontWeight.w600;
      case 2:
        return FontWeight.w300;
      default:
        return FontWeight.w400;
    }
  }

  TextDecoration get textDecoration =>
      settings.underline ? TextDecoration.underline : TextDecoration.none;

  TextAlign get bodyTextAlign =>
      settings.textFullJustify ? TextAlign.justify : TextAlign.left;

  TextAlign get titleTextAlign =>
      settings.titleMode == 1 ? TextAlign.center : TextAlign.left;

  EdgeInsets get contentPadding => EdgeInsets.fromLTRB(
        settings.paddingLeft,
        settings.paddingTop,
        settings.paddingRight,
        settings.paddingBottom,
      );
}
