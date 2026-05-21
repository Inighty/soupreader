import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'package:battery_plus/battery_plus.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_resolver.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'legacy_justified_text.dart';
import 'page_factory.dart';
import 'reader_text_selection_overlay.dart';
import 'simulation_page_painter.dart';
import 'simulation_page_painter2.dart';

part 'paged_reader_public_api.dart';
part 'paged_reader_state_sync.dart';
part 'paged_reader_metrics.dart';
part 'paged_reader_recording.dart';
part 'paged_reader_tip_painting.dart';
part 'paged_reader_picture_cache.dart';
part 'paged_reader_precache.dart';
part 'paged_reader_turn_programmatic.dart';
part 'paged_reader_turn_scroll.dart';
part 'paged_reader_selection_start.dart';
part 'paged_reader_selection_geometry.dart';
part 'paged_reader_selection_words.dart';
part 'paged_reader_build_content.dart';
part 'paged_reader_slide_cover.dart';
part 'paged_reader_simulation_modes.dart';
part 'paged_reader_gestures.dart';
part 'paged_reader_body_images.dart';
part 'paged_reader_image_tracking.dart';
part 'paged_reader_overlay.dart';
part 'paged_reader_support.dart';

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // === 对标 Legado PageDelegate 的状态变量 ===
  bool _isMoved = false; // 是否已移动（触发方向判断）
  bool _isRunning = false; // 动画是否运行中（控制渲染）
  bool _isStarted = false; // Scroller 是否已启动
  bool _isCancel = false; // 是否取消翻页
  _PageDirection _direction = _PageDirection.none; // 翻页方向

  // === 坐标系统（对标 Legado ReadView） ===
  double _startX = 0; // 按下的起始点
  double _startY = 0;
  double _lastX = 0; // 上一帧触摸点
  double _touchX = 0.1; // 当前触摸点（P1: 不让x,y为0,否则在点计算时会有问题）
  double _touchY = 0.1;

  // === P2: 角点状态变量（对标 Legado mCornerX, mCornerY）===
  double _cornerX = 0;
  double _cornerY = 0;

  // === Scroller 风格动画（对标 Legado Scroller） ===
  double _scrollStartX = 0;
  double _scrollStartY = 0;
  double _scrollDx = 0;
  double _scrollDy = 0;

  // 页面 Picture 缓存（仿真模式用）
  ui.Picture? _curPagePicture;
  ui.Picture? _prevPagePicture;
  ui.Picture? _nextPagePicture;
  Size? _lastSize;

  // 页眉/页脚坐标使用稳定系统安全区，避免系统栏 inset 延迟变化导致分割线抖动
  EdgeInsets? _stableSystemPadding;
  Orientation? _stablePaddingOrientation;
  bool? _stableShowHeader;
  bool? _stableShowFooter;
  bool _pendingSystemPaddingRefresh = false;

  ui.Image? _curPageImage;
  ui.Image? _targetPageImage;
  bool _isCurImageLoading = false;
  bool _isTargetImageLoading = false;
  final Set<String> _imageSizeTrackingInFlight = <String>{};

  // 手势拖拽期间尽量不做同步预渲染，避免卡顿
  bool _gestureInProgress = false;

  // 预渲染调度（拆分为多帧，避免一次性卡住 UI）
  bool _precacheScheduled = false;
  int _precacheEpoch = 0;
  // 动画/拖拽期间延迟执行 Picture 失效，避免收尾阶段出现二次重绘。
  bool _pendingPictureInvalidation = false;
  bool _pendingPictureInvalidationFlushScheduled = false;

  // 仿真翻页门闩：启动动画前必须等待关键帧资源就绪
  bool _isPreparingSimulationTurn = false;

  // === 选文状态 ===
  _TextSelection? _activeSelection;
  List<LegacyComposedLine>? _selectionLines; // 当前页排版缓存
  final GlobalKey<ReaderTextSelectionOverlayState> _selectionOverlayKey =
      GlobalKey<ReaderTextSelectionOverlayState>();
  int _simulationPrepareToken = 0;

  // 电池状态
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _initBattery();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animDuration),
    );

    // === 对标 Legado computeScroll ===
    // 使用 AnimationController 的 listener 来驱动动画
    _animController.addListener(_computeScroll);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimComplete();
      }
    });
    widget.controller?._attach(this);

    widget.pageFactory
        .addContentChangedListener(_onPageFactoryContentChangedForRender);

    // 首次进入页面后，利用空闲帧预渲染当前/相邻页，避免首次拖拽翻页卡顿
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _schedulePrecache();
      _warmupSimulationFrames();
    });
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 动画时长变化时更新 AnimationController
    if (oldWidget.animDuration != widget.animDuration) {
      _animController.duration = Duration(milliseconds: widget.animDuration);
    }
    if (oldWidget.pageFactory != widget.pageFactory) {
      oldWidget.pageFactory.removeContentChangedListener(
        _onPageFactoryContentChangedForRender,
      );
      widget.pageFactory.addContentChangedListener(
        _onPageFactoryContentChangedForRender,
      );
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.pageFactory != widget.pageFactory ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.backgroundUiImage != widget.backgroundUiImage ||
        oldWidget.backgroundImageOpacity != widget.backgroundImageOpacity ||
        oldWidget.padding != widget.padding ||
        oldWidget.settings != widget.settings ||
        oldWidget.searchHighlightQuery != widget.searchHighlightQuery ||
        oldWidget.searchHighlightColor != widget.searchHighlightColor ||
        oldWidget.searchHighlightTextColor != widget.searchHighlightTextColor) {
      _invalidatePictures();
      _schedulePrecache();
    }
    if (oldWidget.pageTurnMode != widget.pageTurnMode &&
        widget.pageTurnMode == PageTurnMode.simulation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _warmupSimulationFrames();
      });
    }
  }

  @override
  void dispose() {
    _cancelPendingSimulationPreparation();
    _batteryStateSubscription?.cancel();
    widget.controller?._detach(this);
    widget.pageFactory.removeContentChangedListener(
      _onPageFactoryContentChangedForRender,
    );
    _animController.dispose();
    _invalidatePictures();
    _imageSizeTrackingInFlight.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: _buildPageContent(),
    );
  }
}
