import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页视图（严格对标 AnliaLee/BookPage）
/// 使用 Bitmap 预渲染 + Scroller 动画 + 完整11点坐标系统
class SimulationPageView extends StatefulWidget {
  final String currentPageContent;
  final String nextPageContent;
  final String prevPageContent;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final VoidCallback? onNextPage;
  final VoidCallback? onPrevPage;
  final VoidCallback? onTap;
  final String chapterTitle;
  final int currentPage;
  final int totalPages;

  const SimulationPageView({
    super.key,
    required this.currentPageContent,
    required this.nextPageContent,
    required this.prevPageContent,
    required this.textStyle,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.onNextPage,
    this.onPrevPage,
    this.onTap,
    this.chapterTitle = '',
    this.currentPage = 0,
    this.totalPages = 1,
  });

  @override
  State<SimulationPageView> createState() => _SimulationPageViewState();
}

class _SimulationPageViewState extends State<SimulationPageView>
    with SingleTickerProviderStateMixin {
  // 触摸点和角点
  final _Point _a = _Point(); // 触摸点
  final _Point _f = _Point(); // 翻页起始角
  final _Point _g = _Point(); // a和f的中点
  final _Point _e = _Point(); // 贝塞尔控制点（下边缘）
  final _Point _h = _Point(); // 贝塞尔控制点（右边缘）
  final _Point _c = _Point(); // 贝塞尔起点（下边缘）
  final _Point _j = _Point(); // 贝塞尔起点（右边缘）
  final _Point _b = _Point(); // 交点
  final _Point _k = _Point(); // 交点
  final _Point _d = _Point(); // 贝塞尔顶点
  final _Point _i = _Point(); // 贝塞尔顶点

  // 阴影距离
  double _lPathAShadowDis = 0;
  double _rPathAShadowDis = 0;

  // 动画控制
  late AnimationController _animController;
  Animation<Offset>? _animation;

  // 状态
  String _style = _StyleConst.lowerRight;
  bool _isAnimating = false;

  // 页面 Bitmap
  ui.Image? _currentPageBitmap;
  ui.Image? _nextPageBitmap;
  ui.Image? _prevPageBitmap;

  // 渐变阴影 Drawable
  late List<Color> _gradientColorsLeft;
  late List<Color> _gradientColorsRight;
  late List<Color> _gradientColorsB;
  late List<Color> _gradientColorsC;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _a.x = -1;
    _a.y = -1;
    _initGradientColors();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preparePageBitmaps();
  }

  @override
  void didUpdateWidget(SimulationPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPageContent != widget.currentPageContent ||
        oldWidget.nextPageContent != widget.nextPageContent ||
        oldWidget.prevPageContent != widget.prevPageContent ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      _preparePageBitmaps();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _currentPageBitmap?.dispose();
    _nextPageBitmap?.dispose();
    _prevPageBitmap?.dispose();
    super.dispose();
  }

  void _initGradientColors() {
    _gradientColorsLeft = [const Color(0x01333333), const Color(0x33333333)];
    _gradientColorsRight = [
      const Color(0x22333333),
      const Color(0x01333333),
      const Color(0x01333333)
    ];
    _gradientColorsB = [const Color(0x55111111), const Color(0x00111111)];
    _gradientColorsC = [const Color(0x00333333), const Color(0x55333333)];
  }

  /// 预渲染页面为 Bitmap
  Future<void> _preparePageBitmaps() async {
    final size = MediaQuery.of(context).size;
    final width = size.width.toInt();
    final height = size.height.toInt();

    if (width <= 0 || height <= 0) return;

    // 渲染当前页
    _currentPageBitmap?.dispose();
    _currentPageBitmap = await _renderPageToBitmap(
      widget.currentPageContent,
      width,
      height,
    );

    // 渲染下一页
    _nextPageBitmap?.dispose();
    _nextPageBitmap = await _renderPageToBitmap(
      widget.nextPageContent,
      width,
      height,
    );

    // 渲染上一页
    _prevPageBitmap?.dispose();
    _prevPageBitmap = await _renderPageToBitmap(
      widget.prevPageContent,
      width,
      height,
    );

    if (mounted) setState(() {});
  }

  /// 将页面内容渲染为 Bitmap
  Future<ui.Image> _renderPageToBitmap(
    String content,
    int width,
    int height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    // 绘制背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = widget.backgroundColor,
    );

    // 绘制内容
    if (content.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(text: content, style: widget.textStyle),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.justify,
      );
      final contentWidth =
          size.width - widget.padding.left - widget.padding.right;
      textPainter.layout(maxWidth: contentWidth);

      final topSafe = MediaQuery.of(context).padding.top;
      textPainter.paint(
        canvas,
        Offset(widget.padding.left, topSafe + 37),
      );
    }

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  /// 计算所有控制点（对标 BookPage calcPointsXY）
  void _calcPointsXY() {
    _g.x = (_a.x + _f.x) / 2;
    _g.y = (_a.y + _f.y) / 2;

    _e.x = _g.x - (_f.y - _g.y) * (_f.y - _g.y) / (_f.x - _g.x);
    _e.y = _f.y;

    _h.x = _f.x;
    _h.y = _g.y - (_f.x - _g.x) * (_f.x - _g.x) / (_f.y - _g.y);

    _c.x = _e.x - (_f.x - _e.x) / 2;
    _c.y = _f.y;

    _j.x = _f.x;
    _j.y = _h.y - (_f.y - _h.y) / 2;

    _getIntersectionPoint(_a, _e, _c, _j, _b);
    _getIntersectionPoint(_a, _h, _c, _j, _k);

    _d.x = (_c.x + 2 * _e.x + _b.x) / 4;
    _d.y = (2 * _e.y + _c.y + _b.y) / 4;

    _i.x = (_j.x + 2 * _h.x + _k.x) / 4;
    _i.y = (2 * _h.y + _j.y + _k.y) / 4;

    // 计算阴影距离
    final lA = _a.y - _e.y;
    final lB = _e.x - _a.x;
    final lC = _a.x * _e.y - _e.x * _a.y;
    _lPathAShadowDis =
        (lA * _d.x + lB * _d.y + lC).abs() / math.sqrt(lA * lA + lB * lB);

    final rA = _a.y - _h.y;
    final rB = _h.x - _a.x;
    final rC = _a.x * _h.y - _h.x * _a.y;
    _rPathAShadowDis =
        (rA * _i.x + rB * _i.y + rC).abs() / math.sqrt(rA * rA + rB * rB);
  }

  /// 计算两线段交点
  void _getIntersectionPoint(
      _Point p1, _Point p2, _Point p3, _Point p4, _Point result) {
    final x1 = p1.x, y1 = p1.y;
    final x2 = p2.x, y2 = p2.y;
    final x3 = p3.x, y3 = p3.y;
    final x4 = p4.x, y4 = p4.y;

    result.x =
        ((x1 - x2) * (x3 * y4 - x4 * y3) - (x3 - x4) * (x1 * y2 - x2 * y1)) /
            ((x3 - x4) * (y1 - y2) - (x1 - x2) * (y3 - y4));
    result.y =
        ((y1 - y2) * (x3 * y4 - x4 * y3) - (x1 * y2 - x2 * y1) * (y3 - y4)) /
            ((y1 - y2) * (x3 - x4) - (x1 - x2) * (y3 - y4));
  }

  /// 计算 C 点 X 坐标
  double _calcPointCX(_Point touch, _Point corner) {
    final gx = (touch.x + corner.x) / 2;
    final gy = (touch.y + corner.y) / 2;
    final ex = gx - (corner.y - gy) * (corner.y - gy) / (corner.x - gx);
    return ex - (corner.x - ex) / 2;
  }

  /// 如果 c 点 x 坐标小于 0，重新计算 a 点
  void _calcPointAByTouchPoint(Size size) {
    final w0 = size.width - _c.x;
    final w1 = (_f.x - _a.x).abs();
    final w2 = size.width * w1 / w0;
    _a.x = (_f.x - w2).abs();

    final h1 = (_f.y - _a.y).abs();
    final h2 = w2 * h1 / w1;
    _a.y = (_f.y - h2).abs();
  }

  /// 设置触摸点
  void _setTouchPoint(double x, double y, String style, Size size) {
    _a.x = x;
    _a.y = y;
    _style = style;

    switch (style) {
      case _StyleConst.topRight:
        _f.x = size.width;
        _f.y = 0;
        _calcPointsXY();
        final touchPoint = _Point()
          ..x = x
          ..y = y;
        if (_calcPointCX(touchPoint, _f) < 0) {
          _calcPointAByTouchPoint(size);
          _calcPointsXY();
        }
        break;
      case _StyleConst.left:
      case _StyleConst.right:
        _a.y = size.height - 1;
        _f.x = size.width;
        _f.y = size.height;
        _calcPointsXY();
        break;
      case _StyleConst.lowerRight:
        _f.x = size.width;
        _f.y = size.height;
        _calcPointsXY();
        final touchPoint = _Point()
          ..x = x
          ..y = y;
        if (_calcPointCX(touchPoint, _f) < 0) {
          _calcPointAByTouchPoint(size);
          _calcPointsXY();
        }
        break;
    }
  }

  /// 开始取消动画
  void _startCancelAnim(Size size) {
    if (_isAnimating) return;
    _isAnimating = true;

    double dx, dy;
    if (_style == _StyleConst.topRight) {
      dx = size.width - 1 - _a.x;
      dy = 1 - _a.y;
    } else {
      dx = size.width - 1 - _a.x;
      dy = size.height - 1 - _a.y;
    }

    final startPoint = Offset(_a.x, _a.y);
    final endPoint = Offset(_a.x + dx, _a.y + dy);

    _animation = Tween<Offset>(begin: startPoint, end: endPoint).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.reset();
    _animController.addListener(_onAnimUpdate);
    _animController.addStatusListener(_onCancelAnimStatus);
    _animController.forward();
  }

  /// 开始确认翻页动画
  void _startConfirmAnim(Size size) {
    if (_isAnimating) return;
    _isAnimating = true;

    double targetX, targetY;
    if (_style == _StyleConst.topRight) {
      targetX = -size.width;
      targetY = size.height;
    } else {
      targetX = -size.width;
      targetY = 0;
    }

    final startPoint = Offset(_a.x, _a.y);
    final endPoint = Offset(targetX, targetY);

    _animation = Tween<Offset>(begin: startPoint, end: endPoint).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.reset();
    _animController.addListener(_onAnimUpdate);
    _animController.addStatusListener(_onConfirmAnimStatus);
    _animController.forward();
  }

  void _onAnimUpdate() {
    if (_animation == null) return;
    final value = _animation!.value;
    final size = MediaQuery.of(context).size;
    _setTouchPoint(value.dx, value.dy, _style, size);
    setState(() {});
  }

  void _onCancelAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _animController.removeListener(_onAnimUpdate);
      _animController.removeStatusListener(_onCancelAnimStatus);
      _setDefaultPath();
      _isAnimating = false;
    }
  }

  void _onConfirmAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _animController.removeListener(_onAnimUpdate);
      _animController.removeStatusListener(_onConfirmAnimStatus);
      _setDefaultPath();
      _isAnimating = false;

      // 执行翻页回调
      if (_style == _StyleConst.left) {
        widget.onPrevPage?.call();
      } else {
        widget.onNextPage?.call();
      }
    }
  }

  void _setDefaultPath() {
    _a.x = -1;
    _a.y = -1;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapUp: _onTapUp,
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _BookPagePainter(
          a: _a,
          f: _f,
          e: _e,
          h: _h,
          c: _c,
          j: _j,
          b: _b,
          k: _k,
          d: _d,
          i: _i,
          style: _style,
          currentPageBitmap: _currentPageBitmap,
          nextPageBitmap: _nextPageBitmap,
          prevPageBitmap: _prevPageBitmap,
          backgroundColor: widget.backgroundColor,
          lPathAShadowDis: _lPathAShadowDis,
          rPathAShadowDis: _rPathAShadowDis,
          gradientColorsLeft: _gradientColorsLeft,
          gradientColorsRight: _gradientColorsRight,
          gradientColorsB: _gradientColorsB,
          gradientColorsC: _gradientColorsC,
        ),
      ),
    );
  }

  void _onTapUp(TapUpDetails details) {
    if (_isAnimating) return;
    final size = MediaQuery.of(context).size;
    final x = details.localPosition.dx;

    if (x <= size.width / 3) {
      // 左侧点击 - 上一页
      if (widget.prevPageContent.isEmpty) return;
      _style = _StyleConst.left;
      _setTouchPoint(size.width * 0.1, size.height - 1, _style, size);
      setState(() {});
      _startConfirmAnim(size);
    } else if (x >= size.width * 2 / 3) {
      // 右侧点击 - 下一页
      if (widget.nextPageContent.isEmpty) return;
      _style = _StyleConst.lowerRight;
      _setTouchPoint(size.width * 0.9, size.height * 0.9, _style, size);
      setState(() {});
      _startConfirmAnim(size);
    } else {
      // 中间点击
      widget.onTap?.call();
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating) return;
    final size = MediaQuery.of(context).size;
    final x = details.localPosition.dx;
    final y = details.localPosition.dy;

    if (x <= size.width / 3) {
      _style = _StyleConst.left;
    } else if (x > size.width / 3 && y <= size.height / 3) {
      _style = _StyleConst.topRight;
    } else if (x > size.width * 2 / 3 &&
        y > size.height / 3 &&
        y <= size.height * 2 / 3) {
      _style = _StyleConst.right;
    } else if (x > size.width / 3 && y > size.height * 2 / 3) {
      _style = _StyleConst.lowerRight;
    } else {
      _style = _StyleConst.middle;
      return;
    }

    // 检查是否有内容可翻
    if (_style == _StyleConst.left && widget.prevPageContent.isEmpty) {
      _style = _StyleConst.middle;
      return;
    }
    if (_style != _StyleConst.left && widget.nextPageContent.isEmpty) {
      _style = _StyleConst.middle;
      return;
    }

    _setTouchPoint(x, y, _style, size);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating || _style == _StyleConst.middle) return;
    final size = MediaQuery.of(context).size;
    _setTouchPoint(
        details.localPosition.dx, details.localPosition.dy, _style, size);
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating || _style == _StyleConst.middle) return;
    final size = MediaQuery.of(context).size;

    // 判断是否翻页
    final isTurnPage = _a.x < size.width / 2;
    if (isTurnPage) {
      _startConfirmAnim(size);
    } else {
      _startCancelAnim(size);
    }
  }
}

/// 控制点类（对标 BookPage MyPoint）
class _Point {
  double x = 0;
  double y = 0;
}

/// 样式常量（对标 BookPage STYLE_*）
class _StyleConst {
  static const String left = 'STYLE_LEFT';
  static const String right = 'STYLE_RIGHT';
  static const String middle = 'STYLE_MIDDLE';
  static const String topRight = 'STYLE_TOP_RIGHT';
  static const String lowerRight = 'STYLE_LOWER_RIGHT';
}

/// 绘制器（对标 BookPage onDraw）
class _BookPagePainter extends CustomPainter {
  final _Point a, f, e, h, c, j, b, k, d, i;
  final String style;
  final ui.Image? currentPageBitmap;
  final ui.Image? nextPageBitmap;
  final ui.Image? prevPageBitmap;
  final Color backgroundColor;
  final double lPathAShadowDis;
  final double rPathAShadowDis;
  final List<Color> gradientColorsLeft;
  final List<Color> gradientColorsRight;
  final List<Color> gradientColorsB;
  final List<Color> gradientColorsC;

  _BookPagePainter({
    required this.a,
    required this.f,
    required this.e,
    required this.h,
    required this.c,
    required this.j,
    required this.b,
    required this.k,
    required this.d,
    required this.i,
    required this.style,
    required this.currentPageBitmap,
    required this.nextPageBitmap,
    required this.prevPageBitmap,
    required this.backgroundColor,
    required this.lPathAShadowDis,
    required this.rPathAShadowDis,
    required this.gradientColorsLeft,
    required this.gradientColorsRight,
    required this.gradientColorsB,
    required this.gradientColorsC,
  });

  final Path _pathA = Path();
  final Path _pathC = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (currentPageBitmap == null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor,
      );
      return;
    }

    // 默认状态，直接绘制当前页
    if (a.x == -1 && a.y == -1) {
      canvas.drawImage(currentPageBitmap!, Offset.zero, Paint());
      return;
    }

    // 根据翻页方向绘制
    if (f.x == size.width && f.y == 0) {
      // 右上角翻页
      final pathA = _getPathAFromTopRight(size);
      _drawPathAContent(canvas, size, pathA);
      _drawPathCContent(canvas, size, pathA);
      _drawPathBContent(canvas, size, pathA);
    } else if (f.x == size.width && f.y == size.height) {
      // 右下角翻页
      final pathA = _getPathAFromLowerRight(size);
      _drawPathAContent(canvas, size, pathA);
      _drawPathCContent(canvas, size, pathA);
      _drawPathBContent(canvas, size, pathA);
    }
  }

  /// 获取 A 区域路径（右上角翻页）
  Path _getPathAFromTopRight(Size size) {
    _pathA.reset();
    _pathA.lineTo(c.x, c.y);
    _pathA.quadraticBezierTo(e.x, e.y, b.x, b.y);
    _pathA.lineTo(a.x, a.y);
    _pathA.lineTo(k.x, k.y);
    _pathA.quadraticBezierTo(h.x, h.y, j.x, j.y);
    _pathA.lineTo(size.width, size.height);
    _pathA.lineTo(0, size.height);
    _pathA.close();
    return _pathA;
  }

  /// 获取 A 区域路径（右下角翻页）
  Path _getPathAFromLowerRight(Size size) {
    _pathA.reset();
    _pathA.lineTo(0, size.height);
    _pathA.lineTo(c.x, c.y);
    _pathA.quadraticBezierTo(e.x, e.y, b.x, b.y);
    _pathA.lineTo(a.x, a.y);
    _pathA.lineTo(k.x, k.y);
    _pathA.quadraticBezierTo(h.x, h.y, j.x, j.y);
    _pathA.lineTo(size.width, 0);
    _pathA.close();
    return _pathA;
  }

  /// 获取 C 区域路径
  Path _getPathC() {
    _pathC.reset();
    _pathC.moveTo(i.x, i.y);
    _pathC.lineTo(d.x, d.y);
    _pathC.lineTo(b.x, b.y);
    _pathC.lineTo(a.x, a.y);
    _pathC.lineTo(k.x, k.y);
    _pathC.close();
    return _pathC;
  }

  /// 绘制 A 区域内容
  void _drawPathAContent(Canvas canvas, Size size, Path pathA) {
    canvas.save();
    canvas.clipPath(pathA);
    canvas.drawImage(currentPageBitmap!, Offset.zero, Paint());

    // 绘制 A 区域阴影
    if (style != _StyleConst.left && style != _StyleConst.right) {
      _drawPathALeftShadow(canvas, size, pathA);
      _drawPathARightShadow(canvas, size, pathA);
    }
    canvas.restore();
  }

  /// 绘制 A 区域左阴影
  void _drawPathALeftShadow(Canvas canvas, Size size, Path pathA) {
    canvas.save();

    final isTopRight = style == _StyleConst.topRight;
    final shadowWidth = lPathAShadowDis / 2;

    final shadowPath = Path();
    shadowPath.moveTo(
        a.x - math.max(rPathAShadowDis, lPathAShadowDis) / 2, a.y);
    shadowPath.lineTo(d.x, d.y);
    shadowPath.lineTo(e.x, e.y);
    shadowPath.lineTo(a.x, a.y);
    shadowPath.close();

    canvas.clipPath(pathA);
    canvas.clipPath(shadowPath);

    final mDegrees = math.atan2(e.x - a.x, a.y - e.y);
    canvas.translate(e.x, e.y);
    canvas.rotate(mDegrees);

    final colors =
        isTopRight ? gradientColorsLeft : gradientColorsLeft.reversed.toList();

    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(
          isTopRight ? -shadowWidth : 0,
          0,
          isTopRight ? 0 : shadowWidth,
          size.height,
        ),
      );

    canvas.drawRect(
      Rect.fromLTRB(-shadowWidth, 0, shadowWidth, size.height),
      paint,
    );

    canvas.restore();
  }

  /// 绘制 A 区域右阴影
  void _drawPathARightShadow(Canvas canvas, Size size, Path pathA) {
    canvas.save();

    final isTopRight = style == _StyleConst.topRight;
    final shadowWidth = rPathAShadowDis / 2;
    final viewDiagonalLength =
        math.sqrt(size.width * size.width + size.height * size.height);

    final shadowPath = Path();
    shadowPath.moveTo(
        a.x - math.max(rPathAShadowDis, lPathAShadowDis) / 2, a.y);
    shadowPath.lineTo(h.x, h.y);
    shadowPath.lineTo(a.x, a.y);
    shadowPath.close();

    canvas.clipPath(pathA);
    canvas.clipPath(shadowPath);

    final mDegrees = math.atan2(a.y - h.y, a.x - h.x);
    canvas.translate(h.x, h.y);
    canvas.rotate(mDegrees);

    final colors = isTopRight
        ? gradientColorsRight
        : gradientColorsRight.reversed.toList();

    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(
          0,
          isTopRight ? -shadowWidth : 0,
          viewDiagonalLength * 10,
          isTopRight ? 0 : shadowWidth,
        ),
      );

    canvas.drawRect(
      Rect.fromLTRB(0, -shadowWidth, viewDiagonalLength * 10, shadowWidth),
      paint,
    );

    canvas.restore();
  }

  /// 绘制 B 区域内容
  void _drawPathBContent(Canvas canvas, Size size, Path pathA) {
    final targetBitmap =
        style == _StyleConst.left ? prevPageBitmap : nextPageBitmap;
    if (targetBitmap == null) return;

    canvas.save();

    // 裁剪出 B 区域
    final pathC = _getPathC();
    final fullRect = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final pathACUnion = Path.combine(PathOperation.union, pathA, pathC);
    final pathB = Path.combine(PathOperation.difference, fullRect, pathACUnion);

    canvas.clipPath(pathB);
    canvas.drawImage(targetBitmap, Offset.zero, Paint());

    // 绘制 B 区域阴影
    _drawPathBShadow(canvas, size);

    canvas.restore();
  }

  /// 绘制 B 区域阴影
  void _drawPathBShadow(Canvas canvas, Size size) {
    canvas.save();

    final isTopRight = style == _StyleConst.topRight;
    final aTof = math.sqrt(math.pow(a.x - f.x, 2) + math.pow(a.y - f.y, 2));
    final viewDiagonalLength =
        math.sqrt(size.width * size.width + size.height * size.height);
    final shadowWidth = aTof / 4;

    final colors =
        isTopRight ? gradientColorsB : gradientColorsB.reversed.toList();

    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(
          isTopRight ? 0 : -shadowWidth,
          0,
          isTopRight ? shadowWidth : 0,
          viewDiagonalLength,
        ),
      );

    final rotateDegrees = math.atan2(e.x - f.x, h.y - f.y);
    canvas.translate(c.x, c.y);
    canvas.rotate(rotateDegrees);

    canvas.drawRect(
      Rect.fromLTRB(-shadowWidth, 0, shadowWidth, viewDiagonalLength),
      paint,
    );

    canvas.restore();
  }

  /// 绘制 C 区域内容
  void _drawPathCContent(Canvas canvas, Size size, Path pathA) {
    if (currentPageBitmap == null) return;

    canvas.save();

    // 裁剪出 C 区域
    final pathC = _getPathC();
    final pathCMinusA = Path.combine(PathOperation.difference, pathC, pathA);
    canvas.clipPath(pathCMinusA);

    // 计算镜像变换
    final eh = math.sqrt(math.pow(f.x - e.x, 2) + math.pow(h.y - f.y, 2));
    if (eh < 0.001) {
      canvas.restore();
      return;
    }

    final sin0 = (f.x - e.x) / eh;
    final cos0 = (h.y - f.y) / eh;

    final a11 = -(1 - 2 * sin0 * sin0);
    final a12 = 2 * sin0 * cos0;
    final a21 = 2 * sin0 * cos0;
    final a22 = 1 - 2 * sin0 * sin0;

    // 构建变换矩阵
    final matrix = Matrix4(
      a11,
      a21,
      0,
      0,
      a12,
      a22,
      0,
      0,
      0,
      0,
      1,
      0,
      e.x - a11 * e.x - a12 * e.y,
      e.y - a21 * e.x - a22 * e.y,
      0,
      1,
    );

    canvas.transform(matrix.storage);
    canvas.drawImage(currentPageBitmap!, Offset.zero, Paint());

    // 添加半透明遮罩
    canvas.drawPaint(Paint()..color = backgroundColor.withValues(alpha: 0.3));

    canvas.restore();

    // 绘制 C 区域阴影
    canvas.save();
    canvas.clipPath(pathCMinusA);
    _drawPathCShadow(canvas, size);
    canvas.restore();
  }

  /// 绘制 C 区域阴影
  void _drawPathCShadow(Canvas canvas, Size size) {
    canvas.save();

    final isTopRight = style == _StyleConst.topRight;
    final viewDiagonalLength =
        math.sqrt(size.width * size.width + size.height * size.height);

    final midpointCE = (c.x + e.x) / 2;
    final midpointJH = (j.y + h.y) / 2;
    final minDis = math.min((midpointCE - e.x).abs(), (midpointJH - h.y).abs());

    final colors =
        isTopRight ? gradientColorsC : gradientColorsC.reversed.toList();

    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(
          isTopRight ? 0 : -minDis,
          0,
          isTopRight ? minDis : 0,
          viewDiagonalLength,
        ),
      );

    final mDegrees = math.atan2(e.x - f.x, h.y - f.y);
    canvas.translate(c.x, c.y);
    canvas.rotate(mDegrees);

    canvas.drawRect(
      Rect.fromLTRB(-minDis - 30, 0, minDis + 1, viewDiagonalLength),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BookPagePainter oldDelegate) {
    return a.x != oldDelegate.a.x ||
        a.y != oldDelegate.a.y ||
        currentPageBitmap != oldDelegate.currentPageBitmap ||
        nextPageBitmap != oldDelegate.nextPageBitmap;
  }
}
