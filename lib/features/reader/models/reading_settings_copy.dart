import 'reading_settings.dart';

/// `copyWith` 提取为扩展，纯字段覆盖逻辑无副作用，便于主类瘦身。
extension ReadingSettingsCopyWith on ReadingSettings {
  ReadingSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    double? marginHorizontal,
    double? marginVertical,
    int? themeIndex,
    int? nightThemeIndex,
    int? eInkThemeIndex,
    int? fontFamilyIndex,
    PageTurnMode? pageTurnMode,
    bool? keepScreenOn,
    int? keepLightSeconds,
    bool? showStatusBar,
    bool? hideNavigationBar,
    bool? paddingDisplayCutouts,
    bool? showBattery,
    bool? showTime,
    bool? showProgress,
    bool? showChapterProgress,
    double? brightness,
    bool? useSystemBrightness,
    bool? showBrightnessView,
    bool? brightnessViewOnRight,
    bool? showReadTitleAddition,
    bool? readBarStyleFollowPage,
    bool? expandTextMenu,
    int? layoutPresetVersion,
    ProgressBarBehavior? progressBarBehavior,
    bool? confirmSkipChapter,
    int? textBold,
    String? paragraphIndent,
    int? titleMode,
    int? titleSize,
    double? titleTopSpacing,
    double? titleBottomSpacing,
    bool? textFullJustify,
    bool? underline,
    bool? shareLayout,
    List<ReadStyleConfig>? readStyleConfigs,
    double? paddingTop,
    double? paddingBottom,
    double? paddingLeft,
    double? paddingRight,
    double? headerPaddingTop,
    double? headerPaddingBottom,
    double? headerPaddingLeft,
    double? headerPaddingRight,
    double? footerPaddingTop,
    double? footerPaddingBottom,
    double? footerPaddingLeft,
    double? footerPaddingRight,
    Map<String, int>? clickActions,
    int? autoReadSpeed,
    int? pageAnimDuration,
    PageDirection? pageDirection,
    int? pageTouchSlop,
    bool? noAnimScrollPage,
    bool? volumeKeyPage,
    bool? volumeKeyPageOnPlay,
    bool? mouseWheelPage,
    bool? keyPageOnLongPress,
    bool? disableReturnKey,
    bool? autoChangeSource,
    bool? selectText,
    int? screenOrientation,
    List<int>? prevKeys,
    List<int>? nextKeys,
    int? headerMode,
    int? footerMode,
    int? tipColor,
    int? tipDividerColor,
    bool? hideHeader,
    bool? hideFooter,
    bool? showHeaderLine,
    bool? showFooterLine,
    int? headerLeftContent,
    int? headerCenterContent,
    int? headerRightContent,
    int? footerLeftContent,
    int? footerCenterContent,
    int? footerRightContent,
    int? chineseConverterType,
    bool? chineseTraditional,
    bool? cleanChapterTitle,
    bool? textBottomJustify,
    bool? doublePage,
    bool? readBodyToLh,
  }) {
    final resolvedChineseConverterType = chineseConverterType ??
        (chineseTraditional == null
            ? this.chineseConverterType
            : (chineseTraditional
                ? ReadingSettings.chineseConverterSimplifiedToTraditional
                : ReadingSettings.chineseConverterOff));
    final resolvedHeaderMode = headerMode ??
        (hideHeader == null
            ? this.headerMode
            : (hideHeader
                ? ReadingSettings.headerModeHide
                : ReadingSettings.headerModeShow));
    final resolvedFooterMode = footerMode ??
        (hideFooter == null
            ? this.footerMode
            : (hideFooter
                ? ReadingSettings.footerModeHide
                : ReadingSettings.footerModeShow));
    final resolvedKeepLightSeconds = keepLightSeconds ??
        (keepScreenOn == null
            ? this.keepLightSeconds
            : (keepScreenOn
                ? ReadingSettings.keepLightAlways
                : ReadingSettings.keepLightFollowSystem));
    final resolvedKeepScreenOn = keepScreenOn ??
        (keepLightSeconds == null
            ? this.keepScreenOn
            : keepLightSeconds == ReadingSettings.keepLightAlways);

    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      marginHorizontal: marginHorizontal ?? this.marginHorizontal,
      marginVertical: marginVertical ?? this.marginVertical,
      themeIndex: themeIndex ?? this.themeIndex,
      nightThemeIndex: nightThemeIndex ?? this.nightThemeIndex,
      eInkThemeIndex: eInkThemeIndex ?? this.eInkThemeIndex,
      fontFamilyIndex: fontFamilyIndex ?? this.fontFamilyIndex,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      keepScreenOn: resolvedKeepScreenOn,
      keepLightSeconds: resolvedKeepLightSeconds,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      hideNavigationBar: hideNavigationBar ?? this.hideNavigationBar,
      paddingDisplayCutouts:
          paddingDisplayCutouts ?? this.paddingDisplayCutouts,
      showBattery: showBattery ?? this.showBattery,
      showTime: showTime ?? this.showTime,
      showProgress: showProgress ?? this.showProgress,
      showChapterProgress: showChapterProgress ?? this.showChapterProgress,
      brightness: brightness ?? this.brightness,
      useSystemBrightness: useSystemBrightness ?? this.useSystemBrightness,
      showBrightnessView: showBrightnessView ?? this.showBrightnessView,
      brightnessViewOnRight:
          brightnessViewOnRight ?? this.brightnessViewOnRight,
      showReadTitleAddition:
          showReadTitleAddition ?? this.showReadTitleAddition,
      readBarStyleFollowPage:
          readBarStyleFollowPage ?? this.readBarStyleFollowPage,
      expandTextMenu: expandTextMenu ?? this.expandTextMenu,
      layoutPresetVersion: layoutPresetVersion ?? this.layoutPresetVersion,
      progressBarBehavior: progressBarBehavior ?? this.progressBarBehavior,
      confirmSkipChapter: confirmSkipChapter ?? this.confirmSkipChapter,
      textBold: textBold ?? this.textBold,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      titleMode: titleMode ?? this.titleMode,
      titleSize: titleSize ?? this.titleSize,
      titleTopSpacing: titleTopSpacing ?? this.titleTopSpacing,
      titleBottomSpacing: titleBottomSpacing ?? this.titleBottomSpacing,
      textFullJustify: textFullJustify ?? this.textFullJustify,
      underline: underline ?? this.underline,
      shareLayout: shareLayout ?? this.shareLayout,
      readStyleConfigs: readStyleConfigs ?? this.readStyleConfigs,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      headerPaddingTop: headerPaddingTop ?? this.headerPaddingTop,
      headerPaddingBottom: headerPaddingBottom ?? this.headerPaddingBottom,
      headerPaddingLeft: headerPaddingLeft ?? this.headerPaddingLeft,
      headerPaddingRight: headerPaddingRight ?? this.headerPaddingRight,
      footerPaddingTop: footerPaddingTop ?? this.footerPaddingTop,
      footerPaddingBottom: footerPaddingBottom ?? this.footerPaddingBottom,
      footerPaddingLeft: footerPaddingLeft ?? this.footerPaddingLeft,
      footerPaddingRight: footerPaddingRight ?? this.footerPaddingRight,
      clickActions: clickActions ?? this.clickActions,
      autoReadSpeed: autoReadSpeed ?? this.autoReadSpeed,
      pageAnimDuration: pageAnimDuration ?? this.pageAnimDuration,
      pageDirection: pageDirection ?? this.pageDirection,
      pageTouchSlop: pageTouchSlop ?? this.pageTouchSlop,
      noAnimScrollPage: noAnimScrollPage ?? this.noAnimScrollPage,
      volumeKeyPage: volumeKeyPage ?? this.volumeKeyPage,
      volumeKeyPageOnPlay: volumeKeyPageOnPlay ?? this.volumeKeyPageOnPlay,
      mouseWheelPage: mouseWheelPage ?? this.mouseWheelPage,
      keyPageOnLongPress: keyPageOnLongPress ?? this.keyPageOnLongPress,
      disableReturnKey: disableReturnKey ?? this.disableReturnKey,
      autoChangeSource: autoChangeSource ?? this.autoChangeSource,
      selectText: selectText ?? this.selectText,
      screenOrientation: screenOrientation ?? this.screenOrientation,
      prevKeys: prevKeys ?? this.prevKeys,
      nextKeys: nextKeys ?? this.nextKeys,
      hideHeader: resolvedHeaderMode == ReadingSettings.headerModeHide,
      hideFooter: resolvedFooterMode == ReadingSettings.footerModeHide,
      showHeaderLine: showHeaderLine ?? this.showHeaderLine,
      showFooterLine: showFooterLine ?? this.showFooterLine,
      headerMode: resolvedHeaderMode,
      footerMode: resolvedFooterMode,
      tipColor: tipColor ?? this.tipColor,
      tipDividerColor: tipDividerColor ?? this.tipDividerColor,
      headerLeftContent: headerLeftContent ?? this.headerLeftContent,
      headerCenterContent: headerCenterContent ?? this.headerCenterContent,
      headerRightContent: headerRightContent ?? this.headerRightContent,
      footerLeftContent: footerLeftContent ?? this.footerLeftContent,
      footerCenterContent: footerCenterContent ?? this.footerCenterContent,
      footerRightContent: footerRightContent ?? this.footerRightContent,
      chineseConverterType: resolvedChineseConverterType,
      cleanChapterTitle: cleanChapterTitle ?? this.cleanChapterTitle,
      textBottomJustify: textBottomJustify ?? this.textBottomJustify,
      doublePage: doublePage ?? this.doublePage,
      readBodyToLh: readBodyToLh ?? this.readBodyToLh,
    ).sanitize();
  }
}
