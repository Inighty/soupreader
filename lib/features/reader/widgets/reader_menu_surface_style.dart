import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';

/// 阅读器顶部/底部菜单统一样式（对标 legado 同一 bg/text 语义）。
class ReaderMenuSurfaceStyle {
  final Color panelBackground;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color borderColor;
  final Color dividerColor;
  final Color shadowColor;
  final Color controlBackground;
  final Color controlBorder;

  const ReaderMenuSurfaceStyle({
    required this.panelBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.borderColor,
    required this.dividerColor,
    required this.shadowColor,
    required this.controlBackground,
    required this.controlBorder,
  });
}

ReaderMenuSurfaceStyle resolveReaderMenuSurfaceStyle({
  required ReadingThemeColors currentTheme,
  required bool readBarStyleFollowPage,
}) {
  final isDark = currentTheme.isDark;
  final panelBase = readBarStyleFollowPage
      ? currentTheme.background
      : (isDark
          ? ReaderOverlayTokens.panelDark
          : ReaderOverlayTokens.panelLight);
  final panelBackground = panelBase.withValues(
    alpha: readBarStyleFollowPage ? (isDark ? 0.98 : 0.97) : 1.0,
  );
  final primaryText = readBarStyleFollowPage
      ? currentTheme.text
      : (isDark
          ? ReaderOverlayTokens.textStrongDark
          : ReaderOverlayTokens.textStrongLight);
  final secondaryText = readBarStyleFollowPage
      ? currentTheme.text.withValues(alpha: isDark ? 0.66 : 0.62)
      : (isDark
          ? ReaderOverlayTokens.textNormalDark
          : ReaderOverlayTokens.textNormalLight);
  final tertiaryText = readBarStyleFollowPage
      ? currentTheme.text.withValues(alpha: isDark ? 0.54 : 0.5)
      : (isDark
          ? ReaderOverlayTokens.textSubtleDark
          : ReaderOverlayTokens.textSubtleLight);
  final borderColor = readBarStyleFollowPage
      ? primaryText.withValues(alpha: isDark ? 0.30 : 0.24)
      : (isDark
          ? ReaderOverlayTokens.borderDark
          : ReaderOverlayTokens.borderLight);
  final dividerColor = borderColor.withValues(alpha: isDark ? 0.78 : 0.62);
  final shadowColor = readBarStyleFollowPage
      ? primaryText.withValues(alpha: isDark ? 0.12 : 0.1)
      : CupertinoColors.black.withValues(alpha: isDark ? 0.3 : 0.11);
  final controlBackground = readBarStyleFollowPage
      ? currentTheme.text.withValues(alpha: isDark ? 0.12 : 0.08)
      : (isDark
          ? ReaderOverlayTokens.cardDark.withValues(alpha: 0.76)
          : ReaderOverlayTokens.cardLight.withValues(alpha: 0.95));
  final controlBorder = readBarStyleFollowPage
      ? primaryText.withValues(alpha: isDark ? 0.28 : 0.22)
      : borderColor.withValues(alpha: isDark ? 0.9 : 0.85);

  return ReaderMenuSurfaceStyle(
    panelBackground: panelBackground,
    primaryText: primaryText,
    secondaryText: secondaryText,
    tertiaryText: tertiaryText,
    borderColor: borderColor,
    dividerColor: dividerColor,
    shadowColor: shadowColor,
    controlBackground: controlBackground,
    controlBorder: controlBorder,
  );
}
