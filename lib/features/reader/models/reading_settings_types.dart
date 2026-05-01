import 'package:flutter/cupertino.dart';

enum ProgressBarBehavior {
  page, // 进度条拖动定位到章节内页
  chapter, // 进度条拖动切换章节
}

extension ProgressBarBehaviorExtension on ProgressBarBehavior {
  String get label {
    switch (this) {
      case ProgressBarBehavior.page:
        return '页内进度';
      case ProgressBarBehavior.chapter:
        return '章节进度';
    }
  }
}

class ChineseConverterType {
  static const int off = 0;
  static const int traditionalToSimplified = 1;
  static const int simplifiedToTraditional = 2;

  static const List<int> values = <int>[
    off,
    traditionalToSimplified,
    simplifiedToTraditional,
  ];

  static String label(int value) {
    switch (value) {
      case traditionalToSimplified:
        return '繁转简';
      case simplifiedToTraditional:
        return '简转繁';
      case off:
      default:
        return '关闭';
    }
  }
}

class ReaderScreenOrientation {
  static const int unspecified = 0;
  static const int portrait = 1;
  static const int landscape = 2;
  static const int sensor = 3;
  static const int reversePortrait = 4;

  static const List<int> values = <int>[
    unspecified,
    portrait,
    landscape,
    sensor,
    reversePortrait,
  ];

  static String label(int value) {
    switch (value) {
      case portrait:
        return '竖屏';
      case landscape:
        return '横屏';
      case sensor:
        return '自动旋转';
      case reversePortrait:
        return '反向竖屏';
      case unspecified:
      default:
        return '跟随系统';
    }
  }
}

/// 点击动作类型
class ClickAction {
  static const int off = -1;
  static const int showMenu = 0;
  static const int nextPage = 1;
  static const int prevPage = 2;
  static const int nextChapter = 3;
  static const int prevChapter = 4;
  static const int readAloudPrevParagraph = 5;
  static const int readAloudNextParagraph = 6;
  static const int addBookmark = 7;
  static const int editContent = 8;
  static const int toggleReplaceRule = 9;
  static const int openChapterList = 10;
  static const int searchContent = 11;
  static const int syncBookProgress = 12;
  static const int readAloudPauseResume = 13;

  static const List<String> zoneOrder = <String>[
    'tl',
    'tc',
    'tr',
    'ml',
    'mc',
    'mr',
    'bl',
    'bc',
    'br',
  ];

  static const Map<String, int> defaultZoneConfig = <String, int>{
    'tl': prevPage,
    'tc': prevPage,
    'tr': nextPage,
    'ml': prevPage,
    'mc': showMenu,
    'mr': nextPage,
    'bl': prevPage,
    'bc': nextPage,
    'br': nextPage,
  };

  static const List<int> allActions = <int>[
    off,
    showMenu,
    nextPage,
    prevPage,
    nextChapter,
    prevChapter,
    readAloudPrevParagraph,
    readAloudNextParagraph,
    addBookmark,
    editContent,
    toggleReplaceRule,
    openChapterList,
    searchContent,
    syncBookProgress,
    readAloudPauseResume,
  ];

  static bool isValidAction(int action) => allActions.contains(action);

  static bool isTtsAction(int action) {
    return action == readAloudPrevParagraph ||
        action == readAloudNextParagraph ||
        action == readAloudPauseResume;
  }

  static List<int> availableActions({required bool excludeTts}) {
    if (!excludeTts) return allActions;
    return allActions.where((action) => !isTtsAction(action)).toList();
  }

  static bool hasMenuZone(Map<String, int> config) {
    for (final zone in zoneOrder) {
      if ((config[zone] ?? defaultZoneConfig[zone] ?? showMenu) == showMenu) {
        return true;
      }
    }
    return false;
  }

  static Map<String, int> normalizeConfig(Map<String, int> rawConfig) {
    final normalized = <String, int>{...defaultZoneConfig};
    for (final zone in zoneOrder) {
      if (!rawConfig.containsKey(zone)) continue;
      final action = rawConfig[zone];
      if (action == null) continue;
      normalized[zone] = isValidAction(action) ? action : showMenu;
    }
    if (!hasMenuZone(normalized)) {
      normalized['mc'] = showMenu;
    }
    return normalized;
  }

  static Map<String, int> normalizeConfigForExclusions(
    Map<String, int> rawConfig, {
    required bool excludeTts,
  }) {
    final normalized = normalizeConfig(rawConfig);
    if (!excludeTts) return normalized;

    final adjusted = Map<String, int>.from(normalized);
    for (final zone in zoneOrder) {
      final action = adjusted[zone] ?? showMenu;
      if (isTtsAction(action)) {
        adjusted[zone] = showMenu;
      }
    }
    if (!hasMenuZone(adjusted)) {
      adjusted['mc'] = showMenu;
    }
    return normalizeConfig(adjusted);
  }

  static String getName(int action) {
    switch (action) {
      case off:
        return '无';
      case showMenu:
        return '菜单';
      case nextPage:
        return '下一页';
      case prevPage:
        return '上一页';
      case nextChapter:
        return '下一章';
      case prevChapter:
        return '上一章';
      case readAloudPrevParagraph:
        return '朗读上一段';
      case readAloudNextParagraph:
        return '朗读下一段';
      case addBookmark:
        return '书签';
      case editContent:
        return '编辑正文';
      case toggleReplaceRule:
        return '替换开关';
      case openChapterList:
        return '目录';
      case searchContent:
        return '搜索正文';
      case syncBookProgress:
        return '同步进度';
      case readAloudPauseResume:
        return '朗读暂停/继续';
      default:
        return '无';
    }
  }
}

/// 翻页模式
enum PageTurnMode {
  slide, // 滑动
  simulation, // 仿真翻页 (Shader)
  cover, // 覆盖
  none, // 无动画
  scroll, // 滚动
  simulation2, // 仿真翻页2 (贝塞尔曲线，参考 flutter_novel)
}

extension PageTurnModeExtension on PageTurnMode {
  String get name {
    switch (this) {
      case PageTurnMode.slide:
        return '滑动';
      case PageTurnMode.simulation:
        return '仿真';
      case PageTurnMode.cover:
        return '覆盖';
      case PageTurnMode.none:
        return '无';
      case PageTurnMode.scroll:
        return '滚动';
      case PageTurnMode.simulation2:
        return '仿真2';
    }
  }

  IconData get icon {
    switch (this) {
      case PageTurnMode.slide:
        return CupertinoIcons.arrow_left_right;
      case PageTurnMode.simulation:
        return CupertinoIcons.book;
      case PageTurnMode.cover:
        return CupertinoIcons.square_stack;
      case PageTurnMode.none:
        return CupertinoIcons.stop;
      case PageTurnMode.scroll:
        return CupertinoIcons.arrow_up_arrow_down;
      case PageTurnMode.simulation2:
        return CupertinoIcons.book;
    }
  }
}

/// 翻页模式在 UI 中的展示顺序（对标 legado）
///
/// 约定：
/// - `simulation2` 默认隐藏（不出现在可选项里）
/// - `none`（无动画）永远放在最后
class PageTurnModeUi {
  static bool isHidden(PageTurnMode mode) => mode == PageTurnMode.simulation2;

  /// 返回用于 UI 展示/选择的翻页模式列表。
  ///
  /// - 当当前模式为隐藏项（`simulation2`）时，会把它插入到列表中（但 UI 应禁用点击）
  ///   以避免“当前选中值在 UI 里消失”的困惑。
  static List<PageTurnMode> values({required PageTurnMode current}) {
    final list = <PageTurnMode>[
      PageTurnMode.cover,
      PageTurnMode.slide,
      PageTurnMode.simulation,
      PageTurnMode.scroll,
      PageTurnMode.none, // 放最后
    ];

    if (current == PageTurnMode.simulation2) {
      list.insert(3, PageTurnMode.simulation2);
    }

    return list;
  }
}

/// 翻页方向
enum PageDirection {
  horizontal, // 水平（左右）
  vertical, // 垂直（上下）
}

extension PageDirectionExtension on PageDirection {
  String get name {
    switch (this) {
      case PageDirection.horizontal:
        return '水平';
      case PageDirection.vertical:
        return '垂直';
    }
  }

  IconData get icon {
    switch (this) {
      case PageDirection.horizontal:
        return CupertinoIcons.arrow_left_right;
      case PageDirection.vertical:
        return CupertinoIcons.arrow_up_arrow_down;
    }
  }
}
