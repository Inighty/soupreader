import 'package:flutter/cupertino.dart';

import 'reading_settings.dart';

/// `fromJson` 工厂级解析逻辑：原本以 `factory ReadingSettings.fromJson`
/// 形式存在，抽出为独立类后由主类工厂转发，便于主文件瘦身。
class ReadingSettingsJson {
  ReadingSettingsJson._();

  static ReadingSettings fromJson(Map<String, dynamic> json) {
    final rawPageTurnMode = json['pageTurnMode'];
    final pageTurnModeIndex = ReadingSettingsHelpers.toInt(rawPageTurnMode, PageTurnMode.cover.index);
    final safePageTurnModeIndex =
        pageTurnModeIndex.clamp(0, PageTurnMode.values.length - 1);
    final safePageTurnMode = PageTurnMode.values[safePageTurnModeIndex];

    final defaultPageDirectionIndex =
        ReadingSettings.pageDirectionForMode(safePageTurnMode).index;
    final rawPageDirection = json['pageDirection'];
    final pageDirectionIndex =
        ReadingSettingsHelpers.toInt(rawPageDirection, defaultPageDirectionIndex);
    final safePageDirectionIndex =
        pageDirectionIndex.clamp(0, PageDirection.values.length - 1);
    final legacyKeepScreenOn = ReadingSettingsHelpers.toBool(json['keepScreenOn'], false);
    final keepLightFallback =
        legacyKeepScreenOn ? ReadingSettings.keepLightAlways : ReadingSettings.keepLightFollowSystem;
    final rawKeepLightSeconds = json.containsKey('keepLightSeconds')
        ? ReadingSettingsHelpers.toInt(json['keepLightSeconds'], keepLightFallback)
        : keepLightFallback;
    final keepLightSeed =
        legacyKeepScreenOn && rawKeepLightSeconds == ReadingSettings.keepLightFollowSystem
            ? ReadingSettings.keepLightAlways
            : rawKeepLightSeconds;
    final parsedKeepLightSeconds = ReadingSettingsHelpers.normalizeKeepLightSeconds(
      keepLightSeed,
      fallback: keepLightFallback,
    );
    final legacyChineseTraditional = ReadingSettingsHelpers.toBool(json['chineseTraditional'], false);
    final chineseConverterType = json.containsKey('chineseConverterType')
        ? ReadingSettingsHelpers.toInt(json['chineseConverterType'], ReadingSettings.chineseConverterOff)
        : (legacyChineseTraditional
            ? ReadingSettings.chineseConverterSimplifiedToTraditional
            : ReadingSettings.chineseConverterOff);
    final hasHeaderMode = json.containsKey('headerMode');
    final hasFooterMode = json.containsKey('footerMode');
    final hasHideHeader = json.containsKey('hideHeader');
    final hasHideFooter = json.containsKey('hideFooter');
    final parsedHeaderMode = hasHeaderMode
        ? ReadingSettingsHelpers.toInt(json['headerMode'], ReadingSettings.headerModeHideWhenStatusBarShown)
        : (hasHideHeader
            ? (ReadingSettingsHelpers.toBool(json['hideHeader'], false)
                ? ReadingSettings.headerModeHide
                : ReadingSettings.headerModeShow)
            : ReadingSettings.headerModeHideWhenStatusBarShown);
    final parsedFooterMode = hasFooterMode
        ? ReadingSettingsHelpers.toInt(json['footerMode'], ReadingSettings.footerModeShow)
        : (hasHideFooter
            ? (ReadingSettingsHelpers.toBool(json['hideFooter'], false)
                ? ReadingSettings.footerModeHide
                : ReadingSettings.footerModeShow)
            : ReadingSettings.footerModeShow);

    var layoutPresetVersion = ReadingSettingsHelpers.toInt(
      json['layoutPresetVersion'],
      ReadingSettings.layoutPresetVersionLegacy,
    );
    var fontSize = ReadingSettingsHelpers.toDouble(json['fontSize'], ReadingSettings.legacyV1FontSize);
    var lineHeight = ReadingSettingsHelpers.toDouble(json['lineHeight'], ReadingSettings.legacyV1LineHeight);
    const letterSpacing = 0.0;
    var paragraphSpacing =
        ReadingSettingsHelpers.toDouble(json['paragraphSpacing'], ReadingSettings.legacyV1ParagraphSpacing);
    var marginHorizontal = json.containsKey('marginHorizontal')
        ? ReadingSettingsHelpers.toDouble(json['marginHorizontal'], ReadingSettings.legacyV1PaddingHorizontal)
        : ReadingSettingsHelpers.toDouble(json['paddingH'], ReadingSettings.legacyV1PaddingHorizontal);
    var marginVertical = json.containsKey('marginVertical')
        ? ReadingSettingsHelpers.toDouble(json['marginVertical'], ReadingSettings.legacyV1MarginVertical)
        : ReadingSettingsHelpers.toDouble(json['paddingV'], ReadingSettings.legacyV1MarginVertical);
    var paddingTop = ReadingSettingsHelpers.toDouble(json['paddingTop'], ReadingSettings.legacyV1PaddingTop);
    var paddingBottom = ReadingSettingsHelpers.toDouble(json['paddingBottom'], ReadingSettings.legacyV1PaddingBottom);
    var paddingLeft = ReadingSettingsHelpers.toDouble(json['paddingLeft'], ReadingSettings.legacyV1PaddingHorizontal);
    var paddingRight =
        ReadingSettingsHelpers.toDouble(json['paddingRight'], ReadingSettings.legacyV1PaddingHorizontal);
    var headerPaddingTop = ReadingSettingsHelpers.toDouble(json['headerPaddingTop'], 4.0);
    var headerPaddingBottom = ReadingSettingsHelpers.toDouble(json['headerPaddingBottom'], 4.0);
    var headerPaddingLeft = ReadingSettingsHelpers.toDouble(
      json['headerPaddingLeft'],
      ReadingSettingsHelpers.toDouble(json['paddingLeft'], ReadingSettings.legacyV1PaddingHorizontal),
    );
    var headerPaddingRight = ReadingSettingsHelpers.toDouble(
      json['headerPaddingRight'],
      ReadingSettingsHelpers.toDouble(json['paddingRight'], ReadingSettings.legacyV1PaddingHorizontal),
    );
    var footerPaddingTop = ReadingSettingsHelpers.toDouble(json['footerPaddingTop'], 4.0);
    var footerPaddingBottom = ReadingSettingsHelpers.toDouble(json['footerPaddingBottom'], 4.0);
    var footerPaddingLeft = ReadingSettingsHelpers.toDouble(
      json['footerPaddingLeft'],
      ReadingSettingsHelpers.toDouble(json['paddingLeft'], ReadingSettings.legacyV1PaddingHorizontal),
    );
    var footerPaddingRight = ReadingSettingsHelpers.toDouble(
      json['footerPaddingRight'],
      ReadingSettingsHelpers.toDouble(json['paddingRight'], ReadingSettings.legacyV1PaddingHorizontal),
    );

    if (layoutPresetVersion < ReadingSettings.layoutPresetVersionLegadoV2) {
      if (ReadingSettingsHelpers.isCloseTo(fontSize, ReadingSettings.legacyV1FontSize)) {
        fontSize = ReadingSettings.legadoV2FontSize;
      }
      if (ReadingSettingsHelpers.isCloseTo(lineHeight, ReadingSettings.legacyV1LineHeight)) {
        lineHeight = ReadingSettings.legadoV2LineHeight;
      }
      if (ReadingSettingsHelpers.isCloseTo(paragraphSpacing, ReadingSettings.legacyV1ParagraphSpacing)) {
        paragraphSpacing = ReadingSettings.legadoV2ParagraphSpacing;
      }
      if (ReadingSettingsHelpers.isCloseTo(marginHorizontal, ReadingSettings.legacyV1PaddingHorizontal)) {
        marginHorizontal = ReadingSettings.legadoV2PaddingHorizontal;
      }
      if (ReadingSettingsHelpers.isCloseTo(marginVertical, ReadingSettings.legacyV1MarginVertical)) {
        marginVertical = ReadingSettings.legadoV2PaddingVertical;
      }
      if (ReadingSettingsHelpers.isCloseTo(paddingTop, ReadingSettings.legacyV1PaddingTop)) {
        paddingTop = ReadingSettings.legadoV2PaddingVertical;
      }
      if (ReadingSettingsHelpers.isCloseTo(paddingBottom, ReadingSettings.legacyV1PaddingBottom)) {
        paddingBottom = ReadingSettings.legadoV2PaddingVertical;
      }
      if (ReadingSettingsHelpers.isCloseTo(paddingLeft, ReadingSettings.legacyV1PaddingHorizontal)) {
        paddingLeft = ReadingSettings.legadoV2PaddingHorizontal;
      }
      if (ReadingSettingsHelpers.isCloseTo(paddingRight, ReadingSettings.legacyV1PaddingHorizontal)) {
        paddingRight = ReadingSettings.legadoV2PaddingHorizontal;
      }
      if (ReadingSettingsHelpers.isCloseTo(headerPaddingLeft, ReadingSettings.legacyV1PaddingHorizontal)) {
        headerPaddingLeft = ReadingSettings.legadoV2PaddingHorizontal;
      }
      if (ReadingSettingsHelpers.isCloseTo(headerPaddingRight, ReadingSettings.legacyV1PaddingHorizontal)) {
        headerPaddingRight = ReadingSettings.legadoV2PaddingHorizontal;
      }
      if (ReadingSettingsHelpers.isCloseTo(footerPaddingLeft, ReadingSettings.legacyV1PaddingHorizontal)) {
        footerPaddingLeft = ReadingSettings.legadoV2PaddingHorizontal;
      }
      if (ReadingSettingsHelpers.isCloseTo(footerPaddingRight, ReadingSettings.legacyV1PaddingHorizontal)) {
        footerPaddingRight = ReadingSettings.legadoV2PaddingHorizontal;
      }
      layoutPresetVersion = ReadingSettings.layoutPresetVersionLegadoV2;
    }

    final parsedThemeIndex = ReadingSettingsHelpers.toInt(json['themeIndex'], 9);
    final parsedReadStyleConfigs = ReadingSettingsHelpers.parseReadStyleConfigs(
      json['readStyleConfigs'],
    );
    final parsedNightThemeIndex = json.containsKey('nightThemeIndex')
        ? ReadingSettingsHelpers.toInt(json['nightThemeIndex'], 1)
        : _$inferNightThemeIndex(
            dayThemeIndex: parsedThemeIndex,
            styles: parsedReadStyleConfigs,
          );
    final parsedEInkThemeIndex = json.containsKey('eInkThemeIndex')
        ? ReadingSettingsHelpers.toInt(json['eInkThemeIndex'], 3)
        : _$inferEInkThemeIndex(
            dayThemeIndex: parsedThemeIndex,
            styles: parsedReadStyleConfigs,
          );

    return ReadingSettings(
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: ReadingSettingsHelpers.toDouble(json['letterSpacing'], letterSpacing),
      paragraphSpacing: paragraphSpacing,
      marginHorizontal: marginHorizontal,
      marginVertical: marginVertical,
      themeIndex: parsedThemeIndex,
      nightThemeIndex: parsedNightThemeIndex,
      eInkThemeIndex: parsedEInkThemeIndex,
      fontFamilyIndex: ReadingSettingsHelpers.toInt(json['fontFamilyIndex'], 0),
      pageTurnMode: safePageTurnMode,
      keepScreenOn: parsedKeepLightSeconds == ReadingSettings.keepLightAlways,
      keepLightSeconds: parsedKeepLightSeconds,
      showStatusBar: ReadingSettingsHelpers.toBool(json['showStatusBar'], true),
      hideNavigationBar: ReadingSettingsHelpers.toBool(json['hideNavigationBar'], false),
      paddingDisplayCutouts: ReadingSettingsHelpers.toBool(json['paddingDisplayCutouts'], false),
      showBattery: ReadingSettingsHelpers.toBool(json['showBattery'], true),
      showTime: ReadingSettingsHelpers.toBool(json['showTime'], true),
      showProgress: ReadingSettingsHelpers.toBool(json['showProgress'], true),
      showChapterProgress: ReadingSettingsHelpers.toBool(json['showChapterProgress'], true),
      brightness: ReadingSettingsHelpers.toDouble(json['brightness'], 1.0),
      useSystemBrightness: ReadingSettingsHelpers.toBool(json['useSystemBrightness'], true),
      showBrightnessView: ReadingSettingsHelpers.toBool(json['showBrightnessView'], true),
      brightnessViewOnRight: ReadingSettingsHelpers.toBool(json['brightnessViewOnRight'], false),
      showReadTitleAddition: ReadingSettingsHelpers.toBool(json['showReadTitleAddition'], true),
      readBarStyleFollowPage: ReadingSettingsHelpers.toBool(json['readBarStyleFollowPage'], false),
      expandTextMenu: ReadingSettingsHelpers.toBool(json['expandTextMenu'], false),
      layoutPresetVersion: layoutPresetVersion,
      progressBarBehavior:
          ReadingSettingsHelpers.parseProgressBarBehavior(json['progressBarBehavior']),
      confirmSkipChapter: ReadingSettingsHelpers.toBool(json['confirmSkipChapter'], true),
      // 新增字段
      textBold: ReadingSettingsHelpers.toInt(json['textBold'], 0),
      paragraphIndent: json['paragraphIndent'] as String? ?? '　　',
      titleMode: ReadingSettingsHelpers.toInt(json['titleMode'], 0),
      titleSize: ReadingSettingsHelpers.toInt(json['titleSize'], 4),
      titleTopSpacing: ReadingSettingsHelpers.toDouble(json['titleTopSpacing'], 0),
      titleBottomSpacing: ReadingSettingsHelpers.toDouble(json['titleBottomSpacing'], 0),
      textFullJustify: ReadingSettingsHelpers.toBool(json['textFullJustify'], true),
      underline: ReadingSettingsHelpers.toBool(json['underline'], false),
      shareLayout: ReadingSettingsHelpers.toBool(json['shareLayout'], true),
      readStyleConfigs: parsedReadStyleConfigs,
      paddingTop: paddingTop,
      paddingBottom: paddingBottom,
      paddingLeft: paddingLeft,
      paddingRight: paddingRight,
      headerPaddingTop: headerPaddingTop,
      headerPaddingBottom: headerPaddingBottom,
      headerPaddingLeft: headerPaddingLeft,
      headerPaddingRight: headerPaddingRight,
      footerPaddingTop: footerPaddingTop,
      footerPaddingBottom: footerPaddingBottom,
      footerPaddingLeft: footerPaddingLeft,
      footerPaddingRight: footerPaddingRight,
      clickActions: ReadingSettingsHelpers.parseClickActions(json['clickActions']),
      autoReadSpeed: ReadingSettingsHelpers.toInt(json['autoReadSpeed'], 10),
      // 对标 legado：翻页动画时长固定为 300ms（兼容读取旧字段但不生效）
      pageAnimDuration: ReadingSettings.legacyPageAnimDuration,
      pageDirection: PageDirection.values[safePageDirectionIndex],
      pageTouchSlop: ReadingSettingsHelpers.toInt(json['pageTouchSlop'], 0),
      noAnimScrollPage: ReadingSettingsHelpers.toBool(json['noAnimScrollPage'], false),
      volumeKeyPage: ReadingSettingsHelpers.toBool(json['volumeKeyPage'], true),
      volumeKeyPageOnPlay: ReadingSettingsHelpers.toBool(json['volumeKeyPageOnPlay'], true),
      mouseWheelPage: ReadingSettingsHelpers.toBool(json['mouseWheelPage'], true),
      keyPageOnLongPress: ReadingSettingsHelpers.toBool(json['keyPageOnLongPress'], false),
      disableReturnKey: ReadingSettingsHelpers.toBool(json['disableReturnKey'], false),
      autoChangeSource: ReadingSettingsHelpers.toBool(json['autoChangeSource'], false),
      selectText: ReadingSettingsHelpers.toBool(json['selectText'], false),
      screenOrientation: ReadingSettingsHelpers.toInt(
        json['screenOrientation'],
        ReadingSettings.screenOrientationUnspecified,
      ),
      prevKeys: ReadingSettingsHelpers.parseKeyCodeList(json['prevKeys']),
      nextKeys: ReadingSettingsHelpers.parseKeyCodeList(json['nextKeys']),
      // 页眉/页脚配置
      hideHeader:
          ReadingSettingsHelpers.toBool(json['hideHeader'], parsedHeaderMode == ReadingSettings.headerModeHide),
      hideFooter:
          ReadingSettingsHelpers.toBool(json['hideFooter'], parsedFooterMode == ReadingSettings.footerModeHide),
      showHeaderLine: ReadingSettingsHelpers.toBool(json['showHeaderLine'], false),
      showFooterLine: ReadingSettingsHelpers.toBool(json['showFooterLine'], true),
      headerMode: parsedHeaderMode,
      footerMode: parsedFooterMode,
      tipColor: ReadingSettingsHelpers.toInt(json['tipColor'], ReadingSettings.tipColorFollowContent),
      tipDividerColor: ReadingSettingsHelpers.toInt(json['tipDividerColor'], ReadingSettings.tipDividerColorDefault),
      headerLeftContent: ReadingSettingsHelpers.toInt(json['headerLeftContent'], 3),
      headerCenterContent: ReadingSettingsHelpers.toInt(json['headerCenterContent'], 2),
      headerRightContent: ReadingSettingsHelpers.toInt(json['headerRightContent'], 4),
      footerLeftContent: ReadingSettingsHelpers.toInt(json['footerLeftContent'], 5),
      footerCenterContent: ReadingSettingsHelpers.toInt(json['footerCenterContent'], 4),
      footerRightContent: ReadingSettingsHelpers.toInt(json['footerRightContent'], 8),
      // 其他功能开关
      chineseConverterType: chineseConverterType,
      cleanChapterTitle: ReadingSettingsHelpers.toBool(json['cleanChapterTitle'], false),
      textBottomJustify: ReadingSettingsHelpers.toBool(json['textBottomJustify'], true),
      doublePage: ReadingSettingsHelpers.toBool(json['doublePage'], false),
      readBodyToLh: ReadingSettingsHelpers.toBool(json['readBodyToLh'], true),
    ).sanitize();
  }

  /// legacy 兼容：旧版本仅保存 `themeIndex`，新增字段缺失时需要推断夜间/EInk 的默认索引。
  ///
  /// 规则：
  /// - 若存在样式列表：优先选择“第一个暗色背景”的样式作为夜间主题；
  /// - 若不存在：回退到默认索引（night=1）。
  static int _$inferNightThemeIndex({
    required int dayThemeIndex,
    required List<ReadStyleConfig> styles,
  }) {
    if (styles.isEmpty) {
      return 1;
    }
    final index = styles.indexWhere(
      (style) => _isDarkColor(style.backgroundColor),
    );
    if (index >= 0) {
      return index;
    }
    return dayThemeIndex < 0 ? 0 : dayThemeIndex;
  }

  /// legacy 兼容：EInk 模式下优先选择“背景最亮”的样式。
  ///
  /// 说明：
  /// - legado 的 EInk 配置是独立分支（bgStrEInk/textColorEInk），这里用“最亮背景”近似；
  /// - 若不存在样式列表：回退到默认索引（eInk=3）。
  static int _$inferEInkThemeIndex({
    required int dayThemeIndex,
    required List<ReadStyleConfig> styles,
  }) {
    if (styles.isEmpty) {
      return 3;
    }
    var bestIndex = 0;
    var bestLuminance = -1.0;
    for (var i = 0; i < styles.length; i++) {
      final lum = Color(styles[i].backgroundColor).computeLuminance();
      if (lum > bestLuminance) {
        bestLuminance = lum;
        bestIndex = i;
      }
    }
    return bestIndex < 0 ? (dayThemeIndex < 0 ? 0 : dayThemeIndex) : bestIndex;
  }

  static bool _isDarkColor(int argb) {
    return Color(argb).computeLuminance() < 0.5;
  }

}

///  抽到 extension，主类只保留字段与构造函数。
extension ReadingSettingsToJson on ReadingSettings {
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'paragraphSpacing': paragraphSpacing,
      'marginHorizontal': marginHorizontal,
      'marginVertical': marginVertical,
      'themeIndex': themeIndex,
      'nightThemeIndex': nightThemeIndex,
      'eInkThemeIndex': eInkThemeIndex,
      'fontFamilyIndex': fontFamilyIndex,
      'pageTurnMode': pageTurnMode.index,
      'keepScreenOn': keepScreenOn,
      'keepLightSeconds': keepLightSeconds,
      'showStatusBar': showStatusBar,
      'hideNavigationBar': hideNavigationBar,
      'paddingDisplayCutouts': paddingDisplayCutouts,
      'showBattery': showBattery,
      'showTime': showTime,
      'showProgress': showProgress,
      'showChapterProgress': showChapterProgress,
      'brightness': brightness,
      'useSystemBrightness': useSystemBrightness,
      'showBrightnessView': showBrightnessView,
      'brightnessViewOnRight': brightnessViewOnRight,
      'showReadTitleAddition': showReadTitleAddition,
      'readBarStyleFollowPage': readBarStyleFollowPage,
      'expandTextMenu': expandTextMenu,
      'layoutPresetVersion': layoutPresetVersion,
      'progressBarBehavior': progressBarBehavior.name,
      'confirmSkipChapter': confirmSkipChapter,
      // 新增字段
      'textBold': textBold,
      'paragraphIndent': paragraphIndent,
      'titleMode': titleMode,
      'titleSize': titleSize,
      'titleTopSpacing': titleTopSpacing,
      'titleBottomSpacing': titleBottomSpacing,
      'textFullJustify': textFullJustify,
      'underline': underline,
      'shareLayout': shareLayout,
      'readStyleConfigs': readStyleConfigs
          .map((config) => config.toJson())
          .toList(growable: false),
      'paddingTop': paddingTop,
      'paddingBottom': paddingBottom,
      'paddingLeft': paddingLeft,
      'paddingRight': paddingRight,
      'headerPaddingTop': headerPaddingTop,
      'headerPaddingBottom': headerPaddingBottom,
      'headerPaddingLeft': headerPaddingLeft,
      'headerPaddingRight': headerPaddingRight,
      'footerPaddingTop': footerPaddingTop,
      'footerPaddingBottom': footerPaddingBottom,
      'footerPaddingLeft': footerPaddingLeft,
      'footerPaddingRight': footerPaddingRight,
      'clickActions': ClickAction.normalizeConfig(clickActions),
      'autoReadSpeed': autoReadSpeed,
      // 对标 legado：翻页动画时长固定 300ms
      'pageAnimDuration': ReadingSettings.legacyPageAnimDuration,
      'pageDirection': pageDirection.index,
      'pageTouchSlop': pageTouchSlop,
      'noAnimScrollPage': noAnimScrollPage,
      'volumeKeyPage': volumeKeyPage,
      'volumeKeyPageOnPlay': volumeKeyPageOnPlay,
      'mouseWheelPage': mouseWheelPage,
      'keyPageOnLongPress': keyPageOnLongPress,
      'disableReturnKey': disableReturnKey,
      'autoChangeSource': autoChangeSource,
      'selectText': selectText,
      'screenOrientation': screenOrientation,
      'prevKeys': prevKeys,
      'nextKeys': nextKeys,
      // 页眉/页脚配置
      'hideHeader': hideHeader,
      'hideFooter': hideFooter,
      'showHeaderLine': showHeaderLine,
      'showFooterLine': showFooterLine,
      'headerMode': headerMode,
      'footerMode': footerMode,
      'tipColor': tipColor,
      'tipDividerColor': tipDividerColor,
      'headerLeftContent': headerLeftContent,
      'headerCenterContent': headerCenterContent,
      'headerRightContent': headerRightContent,
      'footerLeftContent': footerLeftContent,
      'footerCenterContent': footerCenterContent,
      'footerRightContent': footerRightContent,
      // 其他功能开关
      'chineseConverterType': chineseConverterType,
      'chineseTraditional': chineseTraditional,
      'cleanChapterTitle': cleanChapterTitle,
      'textBottomJustify': textBottomJustify,
      'doublePage': doublePage,
      'readBodyToLh': readBodyToLh,
    };
  }
}
