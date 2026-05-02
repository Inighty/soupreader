import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

/// 阅读器右/左侧亮度面板（顶部"自动" + 中段滑杆 + 底部"左右切换"）。
class ReaderBrightnessPanel extends StatelessWidget {
  static const double minHeight = 180.0;
  static const double maxHeight = 360.0;
  static const double width = 42.0;
  static const double buttonHeight = 40.0;
  static const double sliderMaxLength = 320.0;

  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final Color panelBackground;
  final Color foreground;
  final Color mutedForeground;
  final Color borderColor;
  final bool isDarkMode;
  final Key? autoToggleKey;
  final Key? positionToggleKey;
  final Key? rootKey;

  const ReaderBrightnessPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.panelBackground,
    required this.foreground,
    required this.mutedForeground,
    required this.borderColor,
    required this.isDarkMode,
    this.autoToggleKey,
    this.positionToggleKey,
    this.rootKey,
  });

  double _safeFinite(double value, {double fallback = 0.0}) {
    return value.isFinite ? value : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final accent = isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
    final autoBrightness = settings.useSystemBrightness;
    final iconColor = autoBrightness ? accent : mutedForeground;
    final panelOverlay = isDarkMode
        ? CupertinoColors.white.withValues(alpha: 0.02)
        : CupertinoColors.black.withValues(alpha: 0.08);
    final panelColor = Color.alphaBlend(
      panelOverlay,
      panelBackground.withValues(alpha: isDarkMode ? 0.54 : 0.42),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawAvailableHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : maxHeight;
        final availableHeight =
            rawAvailableHeight.clamp(0.0, double.infinity).toDouble();
        final panelHeight = availableHeight < minHeight
            ? availableHeight
            : availableHeight.clamp(minHeight, maxHeight).toDouble();
        final sliderRegionHeight = (panelHeight - buttonHeight * 2)
            .clamp(0.0, sliderMaxLength)
            .toDouble();

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: rootKey,
            width: width,
            height: panelHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusCard),
                  ),
                  child: Column(
                    children: [
                      CupertinoButton(
                        key: autoToggleKey,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () {
                          onSettingsChanged(
                            settings.copyWith(
                              useSystemBrightness:
                                  !settings.useSystemBrightness,
                            ),
                          );
                        },
                        child: SizedBox(
                          width: width,
                          height: buttonHeight,
                          child: Icon(
                            CupertinoIcons.brightness,
                            size: 22,
                            color: iconColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: sliderRegionHeight,
                        child: IgnorePointer(
                          ignoring: autoBrightness,
                          child: Opacity(
                            opacity: autoBrightness ? 0.35 : 1.0,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final sliderLength =
                                    (constraints.maxHeight - 6)
                                        .clamp(24.0, sliderMaxLength)
                                        .toDouble();
                                return Center(
                                  child: SizedBox(
                                    width: sliderLength,
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: CupertinoSlider(
                                        value: _safeFinite(
                                          settings.brightness,
                                          fallback: 1.0,
                                        ).clamp(0.0, 1.0).toDouble(),
                                        min: 0.0,
                                        max: 1.0,
                                        activeColor: accent,
                                        thumbColor: isDarkMode
                                            ? CupertinoColors.white
                                            : accent,
                                        onChanged: (value) {
                                          onSettingsChanged(
                                            settings.copyWith(
                                                brightness: value),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        key: positionToggleKey,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () {
                          onSettingsChanged(
                            settings.copyWith(
                              brightnessViewOnRight:
                                  !settings.brightnessViewOnRight,
                            ),
                          );
                        },
                        child: SizedBox(
                          width: width,
                          height: buttonHeight,
                          child: Icon(
                            CupertinoIcons.arrow_left_right,
                            size: 20,
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
