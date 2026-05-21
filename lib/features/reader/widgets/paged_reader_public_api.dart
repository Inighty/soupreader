part of 'paged_reader_widget.dart';

class PagedReaderLongPressSelection {
  const PagedReaderLongPressSelection({
    required this.text,
    required this.globalPosition,
  });

  final String text;
  final Offset globalPosition;
}

/// 分页阅读器控制器
/// 用于外部触发与手势同路径的翻页动画。
class PagedReaderController {
  _PagedReaderWidgetState? _state;

  bool get isAttached => _state != null;

  bool turnNextPage() {
    final state = _state;
    if (state == null) return false;
    return state._nextPageByAnim();
  }

  bool turnPrevPage() {
    final state = _state;
    if (state == null) return false;
    return state._prevPageByAnim();
  }

  void _attach(_PagedReaderWidgetState state) {
    _state = state;
  }

  void _detach(_PagedReaderWidgetState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

/// 翻页阅读器组件（对标 Legado ReadView + flutter_novel）
/// 核心优化：使用 PictureRecorder 预渲染页面，避免截图开销
class PagedReaderWidget extends StatefulWidget {
  final PageFactory pageFactory;
  final PageTurnMode pageTurnMode;
  final TextStyle textStyle;
  final Color backgroundColor;
  final Color? shaderBackgroundColor;
  final ui.Image? backgroundUiImage;
  final double backgroundImageOpacity;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool showStatusBar;
  final ReadingSettings settings;
  final bool paddingDisplayCutouts;
  final String bookTitle;
  final Map<String, int> clickActions;
  final ValueChanged<int>? onAction;
  final String? searchHighlightQuery;
  final Color? searchHighlightColor;
  final Color? searchHighlightTextColor;
  final String legacyImageStyle;
  final VoidCallback? onImageSizeCacheUpdated;
  final void Function(String src, Size resolvedSize)? onImageSizeResolved;
  final ValueChanged<String>? onImageTap;
  final bool showTipBars;
  final ValueChanged<PagedReaderLongPressSelection>? onTextLongPress;
  final PagedReaderController? controller;

  // === 选文功能 ===
  final bool selectTextEnabled;
  final ValueChanged<String>? onCopySelectedText;
  final ValueChanged<String>? onBookmarkSelectedText;
  final ValueChanged<String>? onReadAloudSelectedText;
  final ValueChanged<String>? onDictSelectedText;
  final ValueChanged<String>? onSearchSelectedText;
  final ValueChanged<String>? onShareSelectedText;

  // === 翻页动画增强 ===
  final int animDuration; // 动画时长 (100-600ms)
  final PageDirection pageDirection; // 翻页方向
  final int pageTouchSlop; // 翻页触发阈值（0=系统默认，1-9999=自定义）

  // legado 提示层基线参数：用于分页模式的页眉/页脚占位计算（含边缘间距与分割线节奏）。
  static const double _tipHeaderFontSize = 12.0;
  static const double _tipFooterFontSize = 11.0;
  static const double _tipHeaderEdgeInset = 6.0;
  static const double _tipFooterEdgeInset = 0.0;
  static const double _tipLineGap = 6.0;
  static const double _tipDividerThickness = 0.5;
  static const double topOffset = 37;
  static const double bottomOffset = 37;

  static double resolveHeaderSlotHeight({
    required ReadingSettings settings,
    required bool showStatusBar,
  }) {
    if (!settings.shouldShowHeader(showStatusBar: showStatusBar)) return 0.0;
    final dividerHeight =
        settings.showHeaderLine ? _tipLineGap + _tipDividerThickness : 0.0;
    return _tipHeaderEdgeInset +
        settings.headerPaddingTop +
        _tipHeaderFontSize +
        settings.headerPaddingBottom +
        dividerHeight;
  }

  static double resolveFooterSlotHeight({
    required ReadingSettings settings,
  }) {
    if (!settings.shouldShowFooter()) return 0.0;
    final dividerHeight =
        settings.showFooterLine ? _tipLineGap + _tipDividerThickness : 0.0;
    return _tipFooterEdgeInset +
        settings.footerPaddingBottom +
        _tipFooterFontSize +
        settings.footerPaddingTop +
        dividerHeight;
  }

  const PagedReaderWidget({
    super.key,
    required this.pageFactory,
    required this.pageTurnMode,
    required this.textStyle,
    required this.backgroundColor,
    this.shaderBackgroundColor,
    this.backgroundUiImage,
    this.backgroundImageOpacity = 1.0,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.showStatusBar = true,
    required this.settings,
    this.paddingDisplayCutouts = false,
    required this.bookTitle,
    this.clickActions = const {},
    this.onAction,
    this.searchHighlightQuery,
    this.searchHighlightColor,
    this.searchHighlightTextColor,
    this.legacyImageStyle = 'DEFAULT',
    this.onImageSizeCacheUpdated,
    this.onImageSizeResolved,
    this.onImageTap,
    this.showTipBars = true,
    this.onTextLongPress,
    this.controller,
    // 翻页动画增强默认值
    this.animDuration = 300,
    this.pageDirection = PageDirection.horizontal,
    this.pageTouchSlop = 0,
    this.enableGestures = true,
    // 选文功能
    this.selectTextEnabled = false,
    this.onCopySelectedText,
    this.onBookmarkSelectedText,
    this.onReadAloudSelectedText,
    this.onDictSelectedText,
    this.onSearchSelectedText,
    this.onShareSelectedText,
  });

  final bool enableGestures;

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}
