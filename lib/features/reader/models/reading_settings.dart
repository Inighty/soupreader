import 'package:flutter/cupertino.dart';

import 'reading_settings_helpers.dart';
import 'reading_settings_json.dart';
import 'reading_settings_read_style.dart';
import 'reading_settings_types.dart';

export 'reading_settings_copy.dart';
export 'reading_settings_helpers.dart';
export 'reading_settings_json.dart';
export 'reading_settings_read_style.dart';
export 'reading_settings_sanitize.dart';
export 'reading_settings_types.dart';

/// 阅读设置模型
class ReadingSettings {
  // legacy 旧默认（v1）：用于历史数据识别与一次性迁移。
  static const double legacyV1FontSize = 24.0;
  static const double legacyV1LineHeight = 1.42;
  static const double legacyV1ParagraphSpacing = 6.0;
  static const double legacyV1PaddingHorizontal = 22.0;
  static const double legacyV1PaddingTop = 5.0;
  static const double legacyV1PaddingBottom = 4.0;
  static const double legacyV1MarginVertical = 5.0;

  // legado 对齐默认（v2）：正文更满、同屏信息密度更高。
  static const double legadoV2FontSize = 20.0;
  static const double legadoV2LineHeight = 1.2;
  static const double legadoV2ParagraphSpacing = 2.0;
  static const double legadoV2PaddingHorizontal = 16.0;
  static const double legadoV2PaddingVertical = 6.0;

  static const int layoutPresetVersionLegacy = 1;
  static const int layoutPresetVersionLegadoV2 = 2;

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double marginHorizontal; // 左右页边距
  final double marginVertical; // 上下页边距
  final int themeIndex; // 阅读主题索引（白天/普通模式）
  final int nightThemeIndex; // 夜间主题索引（跟随系统深色模式时使用）
  final int eInkThemeIndex; // EInk 主题索引（对标 legado EInk 模式）
  final int fontFamilyIndex; // 字体选择索引
  final PageTurnMode pageTurnMode;
  final bool keepScreenOn;
  final int keepLightSeconds; // legado keep_light：0/60/300/600/-1
  final bool showStatusBar; // 是否显示系统状态栏
  final bool hideNavigationBar; // 是否隐藏系统导航栏
  final bool paddingDisplayCutouts; // 刘海屏留边（对标 legado paddingDisplayCutouts）
  final bool showBattery;
  final bool showTime;
  final bool showProgress;
  final bool showChapterProgress; // 显示章节内进度
  final double brightness; // 0.0 - 1.0
  final bool useSystemBrightness;
  final bool showBrightnessView; // 是否显示阅读菜单亮度调节栏
  final bool brightnessViewOnRight; // 亮度侧边栏位置（true:右侧，false:左侧）
  final bool showReadTitleAddition; // 显示阅读标题附加信息（对标 showReadTitleAddition）
  final bool readBarStyleFollowPage; // 阅读菜单样式跟随页面（对标 readBarStyleFollowPage）
  final bool expandTextMenu; // 展开文本菜单（对标 legado expandTextMenu）
  final int layoutPresetVersion; // 排版预设版本：用于历史默认值迁移
  final ProgressBarBehavior progressBarBehavior; // 进度条行为（页内/章节）
  final bool confirmSkipChapter; // 章节进度条跳转确认（对标 legado）

  // === 新增字段 ===
  final int textBold; // 0:正常 1:粗体 2:细体
  final String paragraphIndent; // 段落缩进字符，默认"　　"（两个全角空格）
  final int titleMode; // 0:居左 1:居中 2:隐藏
  final int titleSize; // 标题字体大小偏移 (-4 to +8)
  final double titleTopSpacing; // 标题顶部间距
  final double titleBottomSpacing; // 标题底部间距
  final bool textFullJustify; // 两端对齐
  final bool underline; // 下划线
  final bool shareLayout; // 样式面板共享排版布局（对标 legado）
  final List<ReadStyleConfig>
      readStyleConfigs; // 对标 legado configList（样式名+背景类型/背景值/透明度/文字色）

  // 精细化边距
  final double paddingTop;
  final double paddingBottom;
  final double paddingLeft;
  final double paddingRight;
  final double headerPaddingTop;
  final double headerPaddingBottom;
  final double headerPaddingLeft;
  final double headerPaddingRight;
  final double footerPaddingTop;
  final double footerPaddingBottom;
  final double footerPaddingLeft;
  final double footerPaddingRight;

  // 点击区域配置 (9宫格)
  final Map<String, int> clickActions;

  // 自动阅读
  final int autoReadSpeed; // 自动阅读速度（秒/页，1-120）

  // === 翻页动画 ===
  final int pageAnimDuration; // 对标 legado：固定 300ms
  final PageDirection pageDirection; // 翻页方向 (水平/垂直)
  final int pageTouchSlop; // 翻页触发阈值（0=系统默认，1-9999=自定义）
  final bool noAnimScrollPage; // 滚动翻页无动画（对标 legado）
  final bool volumeKeyPage; // 音量键翻页
  final bool volumeKeyPageOnPlay; // 朗读时允许音量键翻页（对标 legado）
  final bool mouseWheelPage; // 鼠标滚轮翻页（对标 legado）
  final bool keyPageOnLongPress; // 按键长按翻页（对标 legado）
  final bool disableReturnKey; // 禁用返回键（对标 legado）
  final bool autoChangeSource; // 章节加载失败自动换源（对标 legado autoChangeSource）
  final bool selectText; // 允许选择正文文本（对标 legado selectText）
  final int screenOrientation; // 屏幕方向（0~4，对标 legado）
  final List<int> prevKeys; // 自定义上一页按键 keyId 列表（对标 legado prevKeys）
  final List<int> nextKeys; // 自定义下一页按键 keyId 列表（对标 legado nextKeys）

  // === 页眉/页脚配置 ===
  final bool hideHeader; // 隐藏页眉
  final bool hideFooter; // 隐藏页脚
  final bool showHeaderLine; // 显示页眉分割线
  final bool showFooterLine; // 显示页脚分割线
  final int headerMode; // 0:显示状态栏时隐藏 1:显示 2:隐藏
  final int footerMode; // 0:显示 1:隐藏
  final int tipColor; // 0:同正文颜色 其它:自定义色(ARGB)
  final int tipDividerColor; // -1:默认 0:同正文颜色 其它:自定义色(ARGB)
  final int headerLeftContent; // 页眉左侧内容：0=书名 1=章节名 2=无
  final int headerCenterContent; // 页眉中间内容
  final int headerRightContent; // 页眉右侧内容
  final int footerLeftContent; // 页脚左侧内容：0=进度 1=页码 2=时间 3=电量 4=无
  final int footerCenterContent; // 页脚中间内容
  final int footerRightContent; // 页脚右侧内容

  // === 其他功能开关 ===
  final int chineseConverterType; // 简繁转换（0=关闭 1=繁转简 2=简转繁）
  final bool cleanChapterTitle; // 净化正文章节名称
  final bool textBottomJustify; // 底部对齐（对标 legado）
  final bool doublePage; // 双页模式（对标 legado doublePageHorizontal）
  final bool readBodyToLh; // 正文适应左手（对标 legado readBodyToLh）


  static const int chineseConverterOff = 0;
  static const int chineseConverterTraditionalToSimplified = 1;
  static const int chineseConverterSimplifiedToTraditional = 2;
  static const int legacyPageAnimDuration = 300;
  static const int headerModeHideWhenStatusBarShown = 0;
  static const int headerModeShow = 1;
  static const int headerModeHide = 2;
  static const int footerModeShow = 0;
  static const int footerModeHide = 1;
  static const int tipColorFollowContent = 0;
  static const int tipDividerColorDefault = -1;
  static const int tipDividerColorFollowContent = 0;
  static const int keepLightFollowSystem = 0;
  static const int keepLightOneMinute = 60;
  static const int keepLightFiveMinutes = 300;
  static const int keepLightTenMinutes = 600;
  static const int keepLightAlways = -1;
  static const int screenOrientationUnspecified = 0;
  static const int screenOrientationPortrait = 1;
  static const int screenOrientationLandscape = 2;
  static const int screenOrientationSensor = 3;
  static const int screenOrientationReversePortrait = 4;

  static PageDirection pageDirectionForMode(PageTurnMode mode) {
    return mode == PageTurnMode.scroll
        ? PageDirection.vertical
        : PageDirection.horizontal;
  }

  const ReadingSettings({
    // 安装后默认值：尽量对齐 Legado 的阅读默认体验
    this.fontSize = legadoV2FontSize,
    this.lineHeight = legadoV2LineHeight,
    this.letterSpacing = 0.0,
    this.paragraphSpacing = legadoV2ParagraphSpacing,
    this.marginHorizontal = legadoV2PaddingHorizontal,
    this.marginVertical = legadoV2PaddingVertical,
    // Legado 默认首套排版的纸色主题（本项目在 AppColors.readingThemes 末尾追加）
    this.themeIndex = 9,
    // 迁移策略：夜间默认使用 nightTheme（通常为索引 1），EInk 默认使用 inkTheme（通常为索引 3）
    // 注意：索引的最终有效性在 sanitize()/渲染侧会根据可用样式数量进行保护性裁剪。
    this.nightThemeIndex = 1,
    this.eInkThemeIndex = 3,
    this.fontFamilyIndex = 0,
    // Legado 默认翻页：覆盖
    this.pageTurnMode = PageTurnMode.cover,
    this.keepScreenOn = false,
    this.keepLightSeconds = keepLightFollowSystem,
    this.showStatusBar = true,
    this.hideNavigationBar = false,
    this.paddingDisplayCutouts = false,
    this.showBattery = true,
    this.showTime = true,
    this.showProgress = true,
    this.showChapterProgress = true,
    this.brightness = 1.0,
    this.useSystemBrightness = true,
    this.showBrightnessView = true,
    this.brightnessViewOnRight = false,
    this.showReadTitleAddition = true,
    this.readBarStyleFollowPage = false,
    this.expandTextMenu = false,
    this.layoutPresetVersion = layoutPresetVersionLegadoV2,
    this.progressBarBehavior = ProgressBarBehavior.chapter,
    this.confirmSkipChapter = true,
    // 新增字段默认值
    this.textBold = 0,
    this.paragraphIndent = '　　',
    this.titleMode = 0,
    this.titleSize = 4,
    this.titleTopSpacing = 0,
    this.titleBottomSpacing = 0,
    this.textFullJustify = true,
    this.underline = false,
    this.shareLayout = true,
    this.readStyleConfigs = const <ReadStyleConfig>[],
    this.paddingTop = legadoV2PaddingVertical,
    this.paddingBottom = legadoV2PaddingVertical,
    this.paddingLeft = legadoV2PaddingHorizontal,
    this.paddingRight = legadoV2PaddingHorizontal,
    this.headerPaddingTop = 4.0,
    this.headerPaddingBottom = 4.0,
    this.headerPaddingLeft = legadoV2PaddingHorizontal,
    this.headerPaddingRight = legadoV2PaddingHorizontal,
    this.footerPaddingTop = 4.0,
    this.footerPaddingBottom = 4.0,
    this.footerPaddingLeft = legadoV2PaddingHorizontal,
    this.footerPaddingRight = legadoV2PaddingHorizontal,
    this.clickActions = const {},
    this.autoReadSpeed = 10,
    // 对标 legado：翻页动画时长固定为 300ms
    this.pageAnimDuration = legacyPageAnimDuration,
    // 产品约束：除“滚动”以外的翻页模式一律水平；滚动模式由渲染层决定纵向滚动
    this.pageDirection = PageDirection.horizontal,
    this.pageTouchSlop = 0,
    // 对标 legado：滚动翻页默认保留动画
    this.noAnimScrollPage = false,
    this.volumeKeyPage = true,
    this.volumeKeyPageOnPlay = true,
    this.mouseWheelPage = true,
    this.keyPageOnLongPress = false,
    this.disableReturnKey = false,
    this.autoChangeSource = false,
    this.selectText = false,
    this.screenOrientation = screenOrientationUnspecified,
    this.prevKeys = const <int>[],
    this.nextKeys = const <int>[],
    // 页眉/页脚配置默认值
    this.hideHeader = false,
    this.hideFooter = false,
    this.showHeaderLine = false,
    this.showFooterLine = true,
    this.headerMode = headerModeHideWhenStatusBarShown,
    this.footerMode = footerModeShow,
    this.tipColor = tipColorFollowContent,
    this.tipDividerColor = tipDividerColorDefault,
    this.headerLeftContent = 3, // 时间
    this.headerCenterContent = 2, // 无
    this.headerRightContent = 4, // 电量
    this.footerLeftContent = 5, // 章节名
    this.footerCenterContent = 4, // 无
    this.footerRightContent = 8, // 页码/总页
    // 其他功能开关
    this.chineseConverterType = chineseConverterOff,
    this.cleanChapterTitle = false,
    this.textBottomJustify = true,
    this.doublePage = false,
    this.readBodyToLh = true,
  });

  /// 兼容旧调用：`true` 等价于「简转繁」。
  bool get chineseTraditional =>
      chineseConverterType == chineseConverterSimplifiedToTraditional;

  /// 获取 padding（兼容旧代码）
  EdgeInsets get padding => EdgeInsets.symmetric(
        horizontal: marginHorizontal,
        vertical: marginVertical,
      );

  bool shouldShowHeader({required bool showStatusBar}) {
    switch (headerMode) {
      case headerModeShow:
        return true;
      case headerModeHide:
        return false;
      case headerModeHideWhenStatusBarShown:
      default:
        return !showStatusBar;
    }
  }

  bool shouldShowFooter() {
    return footerMode != footerModeHide;
  }

  Color resolveTipTextColor(Color contentColor) {
    if (tipColor == tipColorFollowContent) {
      return contentColor;
    }
    return Color(ReadingSettingsHelpers.normalizeColorInt(
      tipColor,
      fallback: tipColorFollowContent,
      allowNegativeOne: false,
      allowZero: true,
    ));
  }

  Color resolveTipDividerColor({
    required Color contentColor,
    required Color defaultDividerColor,
  }) {
    final normalized = ReadingSettingsHelpers.normalizeColorInt(
      tipDividerColor,
      fallback: tipDividerColorDefault,
      allowNegativeOne: true,
      allowZero: true,
    );
    if (normalized == tipDividerColorDefault) {
      return defaultDividerColor;
    }
    if (normalized == tipDividerColorFollowContent) {
      return contentColor;
    }
    return Color(normalized);
  }

  /// JSON 反序列化转发到 [ReadingSettingsJson.fromJson]。
  factory ReadingSettings.fromJson(Map<String, dynamic> json) =>
      ReadingSettingsJson.fromJson(json);
}

