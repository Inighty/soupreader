import 'package:flutter/cupertino.dart';

import 'reading_settings_read_style.dart';
import 'reading_settings_sanitize.dart';
import 'reading_settings_types.dart';

export 'reading_settings_copy.dart';
export 'reading_settings_helpers.dart';
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
    return Color(_normalizeColorInt(
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
    final normalized = _normalizeColorInt(
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

  static double _toDouble(dynamic raw, double fallback) {
    if (raw is num && raw.isFinite) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return fallback;
  }

  static int _toInt(dynamic raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num && raw.isFinite) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static bool _toBool(dynamic raw, bool fallback) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      if (raw == '1' || raw.toLowerCase() == 'true') return true;
      if (raw == '0' || raw.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  static bool _isCloseTo(double value, double target) {
    return (value - target).abs() <= 0.0001;
  }


  static int _normalizeColorInt(
    int raw, {
    required int fallback,
    required bool allowNegativeOne,
    required bool allowZero,
  }) {
    if (allowNegativeOne && raw == -1) {
      return -1;
    }
    if (allowZero && raw == 0) {
      return 0;
    }
    var value = raw;
    if (value < 0) {
      value = value & 0xFFFFFFFF;
    }
    if (value < 0 || value > 0xFFFFFFFF) {
      return fallback;
    }
    if (value == 0 && !allowZero) {
      return fallback;
    }
    if (value != 0xFFFFFFFF && (value & 0xFF000000) == 0) {
      value = value | 0xFF000000;
    }
    return value;
  }

  static Map<String, int> _parseClickActions(dynamic raw) {
    if (raw is! Map) {
      return ClickAction.normalizeConfig(const <String, int>{});
    }
    final parsed = <String, int>{};
    for (final entry in raw.entries) {
      parsed[entry.key.toString()] = _toInt(entry.value, ClickAction.showMenu);
    }
    return ClickAction.normalizeConfig(parsed);
  }

  static List<int> _parseKeyCodeList(dynamic raw) {
    final values = <int>[];
    if (raw is List) {
      for (final item in raw) {
        values.add(_toInt(item, -1));
      }
      return _normalizeKeyCodeList(values);
    }
    if (raw is String) {
      for (final token in raw.split(',')) {
        final normalized = token.trim();
        if (normalized.isEmpty) continue;
        values.add(_toInt(normalized, -1));
      }
      return _normalizeKeyCodeList(values);
    }
    if (raw is int) {
      return _normalizeKeyCodeList(<int>[raw]);
    }
    if (raw is num && raw.isFinite) {
      return _normalizeKeyCodeList(<int>[raw.toInt()]);
    }
    return const <int>[];
  }

  static List<int> _normalizeKeyCodeList(List<int> raw) {
    if (raw.isEmpty) return const <int>[];
    final normalizedSet = <int>{};
    for (final code in raw) {
      if (code > 0) {
        normalizedSet.add(code);
      }
    }
    if (normalizedSet.isEmpty) return const <int>[];
    final sorted = normalizedSet.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  static List<ReadStyleConfig> _parseReadStyleConfigs(dynamic raw) {
    if (raw is! List) {
      return const <ReadStyleConfig>[];
    }
    final parsed = <ReadStyleConfig>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        parsed.add(ReadStyleConfig.fromJson(item).sanitize());
        continue;
      }
      if (item is Map) {
        parsed.add(
          ReadStyleConfig.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ).sanitize(),
        );
      }
    }
    return parsed;
  }

  static ProgressBarBehavior _parseProgressBarBehavior(
    dynamic raw, {
    ProgressBarBehavior fallback = ProgressBarBehavior.page,
  }) {
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'chapter') return ProgressBarBehavior.chapter;
      if (normalized == 'page') return ProgressBarBehavior.page;
    }
    if (raw is num && raw.isFinite) {
      final index = raw.toInt().clamp(0, ProgressBarBehavior.values.length - 1);
      return ProgressBarBehavior.values[index];
    }
    return fallback;
  }

  static bool _isValidKeepLightSeconds(int value) {
    return value == keepLightFollowSystem ||
        value == keepLightOneMinute ||
        value == keepLightFiveMinutes ||
        value == keepLightTenMinutes ||
        value == keepLightAlways;
  }

  static int _normalizeKeepLightSeconds(int value, {required int fallback}) {
    if (_isValidKeepLightSeconds(value)) {
      return value;
    }
    if (_isValidKeepLightSeconds(fallback)) {
      return fallback;
    }
    return keepLightFollowSystem;
  }

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    final rawPageTurnMode = json['pageTurnMode'];
    final pageTurnModeIndex = _toInt(rawPageTurnMode, PageTurnMode.cover.index);
    final safePageTurnModeIndex =
        pageTurnModeIndex.clamp(0, PageTurnMode.values.length - 1);
    final safePageTurnMode = PageTurnMode.values[safePageTurnModeIndex];

    final defaultPageDirectionIndex =
        pageDirectionForMode(safePageTurnMode).index;
    final rawPageDirection = json['pageDirection'];
    final pageDirectionIndex =
        _toInt(rawPageDirection, defaultPageDirectionIndex);
    final safePageDirectionIndex =
        pageDirectionIndex.clamp(0, PageDirection.values.length - 1);
    final legacyKeepScreenOn = _toBool(json['keepScreenOn'], false);
    final keepLightFallback =
        legacyKeepScreenOn ? keepLightAlways : keepLightFollowSystem;
    final rawKeepLightSeconds = json.containsKey('keepLightSeconds')
        ? _toInt(json['keepLightSeconds'], keepLightFallback)
        : keepLightFallback;
    final keepLightSeed =
        legacyKeepScreenOn && rawKeepLightSeconds == keepLightFollowSystem
            ? keepLightAlways
            : rawKeepLightSeconds;
    final parsedKeepLightSeconds = _normalizeKeepLightSeconds(
      keepLightSeed,
      fallback: keepLightFallback,
    );
    final legacyChineseTraditional = _toBool(json['chineseTraditional'], false);
    final chineseConverterType = json.containsKey('chineseConverterType')
        ? _toInt(json['chineseConverterType'], chineseConverterOff)
        : (legacyChineseTraditional
            ? chineseConverterSimplifiedToTraditional
            : chineseConverterOff);
    final hasHeaderMode = json.containsKey('headerMode');
    final hasFooterMode = json.containsKey('footerMode');
    final hasHideHeader = json.containsKey('hideHeader');
    final hasHideFooter = json.containsKey('hideFooter');
    final parsedHeaderMode = hasHeaderMode
        ? _toInt(json['headerMode'], headerModeHideWhenStatusBarShown)
        : (hasHideHeader
            ? (_toBool(json['hideHeader'], false)
                ? headerModeHide
                : headerModeShow)
            : headerModeHideWhenStatusBarShown);
    final parsedFooterMode = hasFooterMode
        ? _toInt(json['footerMode'], footerModeShow)
        : (hasHideFooter
            ? (_toBool(json['hideFooter'], false)
                ? footerModeHide
                : footerModeShow)
            : footerModeShow);

    var layoutPresetVersion = _toInt(
      json['layoutPresetVersion'],
      layoutPresetVersionLegacy,
    );
    var fontSize = _toDouble(json['fontSize'], legacyV1FontSize);
    var lineHeight = _toDouble(json['lineHeight'], legacyV1LineHeight);
    const letterSpacing = 0.0;
    var paragraphSpacing =
        _toDouble(json['paragraphSpacing'], legacyV1ParagraphSpacing);
    var marginHorizontal = json.containsKey('marginHorizontal')
        ? _toDouble(json['marginHorizontal'], legacyV1PaddingHorizontal)
        : _toDouble(json['paddingH'], legacyV1PaddingHorizontal);
    var marginVertical = json.containsKey('marginVertical')
        ? _toDouble(json['marginVertical'], legacyV1MarginVertical)
        : _toDouble(json['paddingV'], legacyV1MarginVertical);
    var paddingTop = _toDouble(json['paddingTop'], legacyV1PaddingTop);
    var paddingBottom = _toDouble(json['paddingBottom'], legacyV1PaddingBottom);
    var paddingLeft = _toDouble(json['paddingLeft'], legacyV1PaddingHorizontal);
    var paddingRight =
        _toDouble(json['paddingRight'], legacyV1PaddingHorizontal);
    var headerPaddingTop = _toDouble(json['headerPaddingTop'], 4.0);
    var headerPaddingBottom = _toDouble(json['headerPaddingBottom'], 4.0);
    var headerPaddingLeft = _toDouble(
      json['headerPaddingLeft'],
      _toDouble(json['paddingLeft'], legacyV1PaddingHorizontal),
    );
    var headerPaddingRight = _toDouble(
      json['headerPaddingRight'],
      _toDouble(json['paddingRight'], legacyV1PaddingHorizontal),
    );
    var footerPaddingTop = _toDouble(json['footerPaddingTop'], 4.0);
    var footerPaddingBottom = _toDouble(json['footerPaddingBottom'], 4.0);
    var footerPaddingLeft = _toDouble(
      json['footerPaddingLeft'],
      _toDouble(json['paddingLeft'], legacyV1PaddingHorizontal),
    );
    var footerPaddingRight = _toDouble(
      json['footerPaddingRight'],
      _toDouble(json['paddingRight'], legacyV1PaddingHorizontal),
    );

    if (layoutPresetVersion < layoutPresetVersionLegadoV2) {
      if (_isCloseTo(fontSize, legacyV1FontSize)) {
        fontSize = legadoV2FontSize;
      }
      if (_isCloseTo(lineHeight, legacyV1LineHeight)) {
        lineHeight = legadoV2LineHeight;
      }
      if (_isCloseTo(paragraphSpacing, legacyV1ParagraphSpacing)) {
        paragraphSpacing = legadoV2ParagraphSpacing;
      }
      if (_isCloseTo(marginHorizontal, legacyV1PaddingHorizontal)) {
        marginHorizontal = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(marginVertical, legacyV1MarginVertical)) {
        marginVertical = legadoV2PaddingVertical;
      }
      if (_isCloseTo(paddingTop, legacyV1PaddingTop)) {
        paddingTop = legadoV2PaddingVertical;
      }
      if (_isCloseTo(paddingBottom, legacyV1PaddingBottom)) {
        paddingBottom = legadoV2PaddingVertical;
      }
      if (_isCloseTo(paddingLeft, legacyV1PaddingHorizontal)) {
        paddingLeft = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(paddingRight, legacyV1PaddingHorizontal)) {
        paddingRight = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(headerPaddingLeft, legacyV1PaddingHorizontal)) {
        headerPaddingLeft = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(headerPaddingRight, legacyV1PaddingHorizontal)) {
        headerPaddingRight = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(footerPaddingLeft, legacyV1PaddingHorizontal)) {
        footerPaddingLeft = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(footerPaddingRight, legacyV1PaddingHorizontal)) {
        footerPaddingRight = legadoV2PaddingHorizontal;
      }
      layoutPresetVersion = layoutPresetVersionLegadoV2;
    }

    final parsedThemeIndex = _toInt(json['themeIndex'], 9);
    final parsedReadStyleConfigs = _parseReadStyleConfigs(
      json['readStyleConfigs'],
    );
    final parsedNightThemeIndex = json.containsKey('nightThemeIndex')
        ? _toInt(json['nightThemeIndex'], 1)
        : _inferNightThemeIndex(
            dayThemeIndex: parsedThemeIndex,
            styles: parsedReadStyleConfigs,
          );
    final parsedEInkThemeIndex = json.containsKey('eInkThemeIndex')
        ? _toInt(json['eInkThemeIndex'], 3)
        : _inferEInkThemeIndex(
            dayThemeIndex: parsedThemeIndex,
            styles: parsedReadStyleConfigs,
          );

    return ReadingSettings(
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: _toDouble(json['letterSpacing'], letterSpacing),
      paragraphSpacing: paragraphSpacing,
      marginHorizontal: marginHorizontal,
      marginVertical: marginVertical,
      themeIndex: parsedThemeIndex,
      nightThemeIndex: parsedNightThemeIndex,
      eInkThemeIndex: parsedEInkThemeIndex,
      fontFamilyIndex: _toInt(json['fontFamilyIndex'], 0),
      pageTurnMode: safePageTurnMode,
      keepScreenOn: parsedKeepLightSeconds == keepLightAlways,
      keepLightSeconds: parsedKeepLightSeconds,
      showStatusBar: _toBool(json['showStatusBar'], true),
      hideNavigationBar: _toBool(json['hideNavigationBar'], false),
      paddingDisplayCutouts: _toBool(json['paddingDisplayCutouts'], false),
      showBattery: _toBool(json['showBattery'], true),
      showTime: _toBool(json['showTime'], true),
      showProgress: _toBool(json['showProgress'], true),
      showChapterProgress: _toBool(json['showChapterProgress'], true),
      brightness: _toDouble(json['brightness'], 1.0),
      useSystemBrightness: _toBool(json['useSystemBrightness'], true),
      showBrightnessView: _toBool(json['showBrightnessView'], true),
      brightnessViewOnRight: _toBool(json['brightnessViewOnRight'], false),
      showReadTitleAddition: _toBool(json['showReadTitleAddition'], true),
      readBarStyleFollowPage: _toBool(json['readBarStyleFollowPage'], false),
      expandTextMenu: _toBool(json['expandTextMenu'], false),
      layoutPresetVersion: layoutPresetVersion,
      progressBarBehavior:
          _parseProgressBarBehavior(json['progressBarBehavior']),
      confirmSkipChapter: _toBool(json['confirmSkipChapter'], true),
      // 新增字段
      textBold: _toInt(json['textBold'], 0),
      paragraphIndent: json['paragraphIndent'] as String? ?? '　　',
      titleMode: _toInt(json['titleMode'], 0),
      titleSize: _toInt(json['titleSize'], 4),
      titleTopSpacing: _toDouble(json['titleTopSpacing'], 0),
      titleBottomSpacing: _toDouble(json['titleBottomSpacing'], 0),
      textFullJustify: _toBool(json['textFullJustify'], true),
      underline: _toBool(json['underline'], false),
      shareLayout: _toBool(json['shareLayout'], true),
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
      clickActions: _parseClickActions(json['clickActions']),
      autoReadSpeed: _toInt(json['autoReadSpeed'], 10),
      // 对标 legado：翻页动画时长固定为 300ms（兼容读取旧字段但不生效）
      pageAnimDuration: legacyPageAnimDuration,
      pageDirection: PageDirection.values[safePageDirectionIndex],
      pageTouchSlop: _toInt(json['pageTouchSlop'], 0),
      noAnimScrollPage: _toBool(json['noAnimScrollPage'], false),
      volumeKeyPage: _toBool(json['volumeKeyPage'], true),
      volumeKeyPageOnPlay: _toBool(json['volumeKeyPageOnPlay'], true),
      mouseWheelPage: _toBool(json['mouseWheelPage'], true),
      keyPageOnLongPress: _toBool(json['keyPageOnLongPress'], false),
      disableReturnKey: _toBool(json['disableReturnKey'], false),
      autoChangeSource: _toBool(json['autoChangeSource'], false),
      selectText: _toBool(json['selectText'], false),
      screenOrientation: _toInt(
        json['screenOrientation'],
        screenOrientationUnspecified,
      ),
      prevKeys: _parseKeyCodeList(json['prevKeys']),
      nextKeys: _parseKeyCodeList(json['nextKeys']),
      // 页眉/页脚配置
      hideHeader:
          _toBool(json['hideHeader'], parsedHeaderMode == headerModeHide),
      hideFooter:
          _toBool(json['hideFooter'], parsedFooterMode == footerModeHide),
      showHeaderLine: _toBool(json['showHeaderLine'], false),
      showFooterLine: _toBool(json['showFooterLine'], true),
      headerMode: parsedHeaderMode,
      footerMode: parsedFooterMode,
      tipColor: _toInt(json['tipColor'], tipColorFollowContent),
      tipDividerColor: _toInt(json['tipDividerColor'], tipDividerColorDefault),
      headerLeftContent: _toInt(json['headerLeftContent'], 3),
      headerCenterContent: _toInt(json['headerCenterContent'], 2),
      headerRightContent: _toInt(json['headerRightContent'], 4),
      footerLeftContent: _toInt(json['footerLeftContent'], 5),
      footerCenterContent: _toInt(json['footerCenterContent'], 4),
      footerRightContent: _toInt(json['footerRightContent'], 8),
      // 其他功能开关
      chineseConverterType: chineseConverterType,
      cleanChapterTitle: _toBool(json['cleanChapterTitle'], false),
      textBottomJustify: _toBool(json['textBottomJustify'], true),
      doublePage: _toBool(json['doublePage'], false),
      readBodyToLh: _toBool(json['readBodyToLh'], true),
    ).sanitize();
  }

  /// legacy 兼容：旧版本仅保存 `themeIndex`，新增字段缺失时需要推断夜间/EInk 的默认索引。
  ///
  /// 规则：
  /// - 若存在样式列表：优先选择“第一个暗色背景”的样式作为夜间主题；
  /// - 若不存在：回退到默认索引（night=1）。
  static int _inferNightThemeIndex({
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
  static int _inferEInkThemeIndex({
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
      'pageAnimDuration': legacyPageAnimDuration,
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

