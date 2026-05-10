import 'reading_settings.dart';

/// `sanitize` 提取为扩展，统一对字段做范围/枚举夹紧；与主类解耦。
extension ReadingSettingsSanitize on ReadingSettings {
  ReadingSettings sanitize() {
    final safeReadStyleConfigs = readStyleConfigs
        .map((config) => config.sanitize())
        .toList(growable: false);
    final safeThemeIndex = safeReadStyleConfigs.isEmpty
        ? (themeIndex < 0 ? 0 : themeIndex)
        : themeIndex.clamp(0, safeReadStyleConfigs.length - 1).toInt();
    final safeNightThemeIndex = safeReadStyleConfigs.isEmpty
        ? (nightThemeIndex < 0 ? 0 : nightThemeIndex)
        : nightThemeIndex.clamp(0, safeReadStyleConfigs.length - 1).toInt();
    final safeEInkThemeIndex = safeReadStyleConfigs.isEmpty
        ? (eInkThemeIndex < 0 ? 0 : eInkThemeIndex)
        : eInkThemeIndex.clamp(0, safeReadStyleConfigs.length - 1).toInt();
    final safeHeaderMode = ReadingSettingsHelpers.safeInt(
      headerMode,
      min: ReadingSettings.headerModeHideWhenStatusBarShown,
      max: ReadingSettings.headerModeHide,
      fallback: ReadingSettings.headerModeHideWhenStatusBarShown,
    );
    final safeFooterMode = ReadingSettingsHelpers.safeInt(
      footerMode,
      min: ReadingSettings.footerModeShow,
      max: ReadingSettings.footerModeHide,
      fallback: ReadingSettings.footerModeShow,
    );
    final keepLightSeed = keepScreenOn &&
            keepLightSeconds == ReadingSettings.keepLightFollowSystem
        ? ReadingSettings.keepLightAlways
        : keepLightSeconds;
    final safeKeepLightSeconds = ReadingSettingsHelpers.normalizeKeepLightSeconds(
      keepLightSeed,
      fallback: keepScreenOn
          ? ReadingSettings.keepLightAlways
          : ReadingSettings.keepLightFollowSystem,
    );
    final safePageDirection = ReadingSettings.pageDirectionForMode(pageTurnMode);
    final safeLayoutPresetVersion =
        layoutPresetVersion < ReadingSettings.layoutPresetVersionLegadoV2
            ? ReadingSettings.layoutPresetVersionLegadoV2
            : layoutPresetVersion;
    return ReadingSettings(
      fontSize: ReadingSettingsHelpers.safeDouble(
        fontSize,
        min: 10.0,
        max: 60.0,
        fallback: ReadingSettings.legadoV2FontSize,
      ),
      lineHeight: ReadingSettingsHelpers.safeDouble(
        lineHeight,
        min: 1.0,
        max: 4.0,
        fallback: ReadingSettings.legadoV2LineHeight,
      ),
      letterSpacing: ReadingSettingsHelpers.safeDouble(
        letterSpacing,
        min: -2.0,
        max: 5.0,
        fallback: 0.0,
      ),
      paragraphSpacing: ReadingSettingsHelpers.safeDouble(
        paragraphSpacing,
        min: 0.0,
        max: 80.0,
        fallback: ReadingSettings.legadoV2ParagraphSpacing,
      ),
      marginHorizontal: ReadingSettingsHelpers.safeDouble(
        marginHorizontal,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingHorizontal,
      ),
      marginVertical: ReadingSettingsHelpers.safeDouble(
        marginVertical,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingVertical,
      ),
      themeIndex: safeThemeIndex,
      nightThemeIndex: safeNightThemeIndex,
      eInkThemeIndex: safeEInkThemeIndex,
      fontFamilyIndex: fontFamilyIndex < 0 ? 0 : fontFamilyIndex,
      pageTurnMode: pageTurnMode,
      keepScreenOn: safeKeepLightSeconds == ReadingSettings.keepLightAlways,
      keepLightSeconds: safeKeepLightSeconds,
      showStatusBar: showStatusBar,
      hideNavigationBar: hideNavigationBar,
      paddingDisplayCutouts: paddingDisplayCutouts,
      showBattery: showBattery,
      showTime: showTime,
      showProgress: showProgress,
      showChapterProgress: showChapterProgress,
      brightness: ReadingSettingsHelpers.safeDouble(
        brightness,
        min: 0.0,
        max: 1.0,
        fallback: 1.0,
      ),
      useSystemBrightness: useSystemBrightness,
      showBrightnessView: showBrightnessView,
      brightnessViewOnRight: brightnessViewOnRight,
      showReadTitleAddition: showReadTitleAddition,
      readBarStyleFollowPage: readBarStyleFollowPage,
      expandTextMenu: expandTextMenu,
      layoutPresetVersion: safeLayoutPresetVersion,
      progressBarBehavior: progressBarBehavior,
      confirmSkipChapter: confirmSkipChapter,
      textBold: ReadingSettingsHelpers.safeInt(
          textBold, min: 0, max: 2, fallback: 0),
      paragraphIndent: paragraphIndent,
      titleMode: ReadingSettingsHelpers.safeInt(
          titleMode, min: 0, max: 2, fallback: 0),
      titleSize: ReadingSettingsHelpers.safeInt(
          titleSize, min: -20, max: 20, fallback: 4),
      titleTopSpacing: ReadingSettingsHelpers.safeDouble(
        titleTopSpacing,
        min: 0.0,
        max: 120.0,
        fallback: 0.0,
      ),
      titleBottomSpacing: ReadingSettingsHelpers.safeDouble(
        titleBottomSpacing,
        min: 0.0,
        max: 120.0,
        fallback: 0.0,
      ),
      textFullJustify: textFullJustify,
      underline: underline,
      shareLayout: shareLayout,
      readStyleConfigs: safeReadStyleConfigs,
      paddingTop: ReadingSettingsHelpers.safeDouble(
        paddingTop,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingVertical,
      ),
      paddingBottom: ReadingSettingsHelpers.safeDouble(
        paddingBottom,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingVertical,
      ),
      paddingLeft: ReadingSettingsHelpers.safeDouble(
        paddingLeft,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingHorizontal,
      ),
      paddingRight: ReadingSettingsHelpers.safeDouble(
        paddingRight,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingHorizontal,
      ),
      headerPaddingTop: ReadingSettingsHelpers.safeDouble(
          headerPaddingTop, min: 0.0, max: 120.0, fallback: 4.0),
      headerPaddingBottom: ReadingSettingsHelpers.safeDouble(
          headerPaddingBottom, min: 0.0, max: 120.0, fallback: 4.0),
      headerPaddingLeft: ReadingSettingsHelpers.safeDouble(
        headerPaddingLeft,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingHorizontal,
      ),
      headerPaddingRight: ReadingSettingsHelpers.safeDouble(
        headerPaddingRight,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingHorizontal,
      ),
      footerPaddingTop: ReadingSettingsHelpers.safeDouble(
          footerPaddingTop, min: 0.0, max: 120.0, fallback: 4.0),
      footerPaddingBottom: ReadingSettingsHelpers.safeDouble(
          footerPaddingBottom, min: 0.0, max: 120.0, fallback: 4.0),
      footerPaddingLeft: ReadingSettingsHelpers.safeDouble(
        footerPaddingLeft,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingHorizontal,
      ),
      footerPaddingRight: ReadingSettingsHelpers.safeDouble(
        footerPaddingRight,
        min: 0.0,
        max: 120.0,
        fallback: ReadingSettings.legadoV2PaddingHorizontal,
      ),
      clickActions: ClickAction.normalizeConfig(
        Map<String, int>.from(clickActions),
      ),
      autoReadSpeed: ReadingSettingsHelpers.safeInt(
          autoReadSpeed, min: 1, max: 120, fallback: 10),
      pageAnimDuration: ReadingSettings.legacyPageAnimDuration,
      pageDirection: safePageDirection,
      pageTouchSlop: ReadingSettingsHelpers.safeInt(
          pageTouchSlop, min: 0, max: 9999, fallback: 0),
      noAnimScrollPage: noAnimScrollPage,
      volumeKeyPage: volumeKeyPage,
      volumeKeyPageOnPlay: volumeKeyPageOnPlay,
      mouseWheelPage: mouseWheelPage,
      keyPageOnLongPress: keyPageOnLongPress,
      disableReturnKey: disableReturnKey,
      screenOrientation: ReadingSettingsHelpers.safeInt(
        screenOrientation,
        min: ReadingSettings.screenOrientationUnspecified,
        max: ReadingSettings.screenOrientationReversePortrait,
        fallback: ReadingSettings.screenOrientationUnspecified,
      ),
      prevKeys: ReadingSettingsHelpers.normalizeKeyCodeList(prevKeys),
      nextKeys: ReadingSettingsHelpers.normalizeKeyCodeList(nextKeys),
      hideHeader: safeHeaderMode == ReadingSettings.headerModeHide,
      hideFooter: safeFooterMode == ReadingSettings.footerModeHide,
      showHeaderLine: showHeaderLine,
      showFooterLine: showFooterLine,
      headerMode: safeHeaderMode,
      footerMode: safeFooterMode,
      tipColor: ReadingSettingsHelpers.normalizeColorInt(
        tipColor,
        fallback: ReadingSettings.tipColorFollowContent,
        allowNegativeOne: false,
        allowZero: true,
      ),
      tipDividerColor: ReadingSettingsHelpers.normalizeColorInt(
        tipDividerColor,
        fallback: ReadingSettings.tipDividerColorDefault,
        allowNegativeOne: true,
        allowZero: true,
      ),
      headerLeftContent: ReadingSettingsHelpers.safeInt(
          headerLeftContent, min: 0, max: 9, fallback: 3),
      headerCenterContent: ReadingSettingsHelpers.safeInt(
          headerCenterContent, min: 0, max: 9, fallback: 2),
      headerRightContent: ReadingSettingsHelpers.safeInt(
          headerRightContent, min: 0, max: 9, fallback: 4),
      footerLeftContent: ReadingSettingsHelpers.safeInt(
          footerLeftContent, min: 0, max: 9, fallback: 5),
      footerCenterContent: ReadingSettingsHelpers.safeInt(
          footerCenterContent, min: 0, max: 9, fallback: 4),
      footerRightContent: ReadingSettingsHelpers.safeInt(
          footerRightContent, min: 0, max: 9, fallback: 8),
      chineseConverterType: ReadingSettingsHelpers.safeInt(
        chineseConverterType,
        min: ReadingSettings.chineseConverterOff,
        max: ReadingSettings.chineseConverterSimplifiedToTraditional,
        fallback: ReadingSettings.chineseConverterOff,
      ),
      cleanChapterTitle: cleanChapterTitle,
      textBottomJustify: textBottomJustify,
      doublePage: doublePage,
      readBodyToLh: readBodyToLh,
      autoChangeSource: autoChangeSource,
      selectText: selectText,
    );
  }
}
