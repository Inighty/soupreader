import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页绘制器（对标 AnliaLee/BookPage）
/// 使用完整的11点坐标系统实现真实书页翻转效果
///
/// 控制点说明：
/// - a: 触摸点
/// - f: 翻页起始角（右下/右上）
/// - g: a和f的中点
/// - e: 贝塞尔曲线控制点（下边缘）
/// - h: 贝塞尔曲线控制点（右边缘）
/// - c,j: 贝塞尔曲线起点
/// - b,k: 贝塞尔曲线与对角线交点
/// - d,i: 贝塞尔曲线顶点（用于阴影计算）
class SimulationPagePainter extends CustomPainter {
  /// 当前页面 Picture（被翻起的页面）
  final ui.Picture? curPagePicture;

  /// 目标页面 Picture（底下露出的页面）
  final ui.Picture? nextPagePicture;

  /// 触摸点坐标
  final Offset touch;

  /// 视图尺寸
  final Size viewSize;

  /// 是否翻向下一页
  final bool isTurnToNext;

  /// 背景颜色
  final Color backgroundColor;

  /// 角点X（翻页的起始角）
  final double cornerX;

  /// 角点Y
  final double cornerY;

  SimulationPagePainter({
    required this.curPagePicture,
    required this.nextPagePicture,
    required this.touch,
    required this.viewSize,
    required this.isTurnToNext,
    required this.backgroundColor,
    required this.cornerX,
    required this.cornerY,
  });

  // 11个控制点（对标 BookPage）
  late Offset a; // 触摸点
  late Offset f; // 翻页起始角
  late Offset g; // a和f的中点
  late Offset e; // 贝塞尔控制点（下边缘）
  late Offset h; // 贝塞尔控制点（右边缘）
  late Offset c; // 贝塞尔起点（下边缘）
  late Offset j; // 贝塞尔起点（右边缘）
  late Offset b; // 交点
  late Offset k; // 交点
  late Offset d; // 贝塞尔顶点（用于阴影）
  late Offset i; // 贝塞尔顶点（用于阴影）

  // 阴影距离参数
  late double lPathAShadowDis;
  late double rPathAShadowDis;

  // Path 对象
  Path pathA = Path();
  Path pathB = Path();
  Path pathC = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (curPagePicture == null) return;

    // 初始化 a 和 f 点
    a = touch;
    f = Offset(cornerX, cornerY);

    // 如果触摸点无效，直接画当前页
    if (a.dx <= 0 && a.dy <= 0) {
      canvas.drawPicture(curPagePicture!);
      return;
    }

    // 限制触摸点范围，确保c点x坐标不小于0
    a = _adjustTouchPoint(a, f);

    // 计算所有控制点坐标
    _calcPointsXY();

    // 绘制三个区域
    _drawPathAContent(canvas);
    _drawPathCContent(canvas);
    _drawPathBContent(canvas);
  }

  /// 调整触摸点，确保c点x坐标不小于0
  Offset _adjustTouchPoint(Offset touch, Offset corner) {
    // 计算c点x坐标
    final gx = (touch.dx + corner.dx) / 2;
    final gy = (touch.dy + corner.dy) / 2;

    double ex;
    if ((corner.dx - gx).abs() < 0.001) {
      ex = gx;
    } else {
      ex = gx - (corner.dy - gy) * (corner.dy - gy) / (corner.dx - gx);
    }
    final cx = ex - (corner.dx - ex) / 2;

    if (cx < 0) {
      // 如果c点x坐标小于0，重新计算a点
      final w0 = viewSize.width - cx;
      final w1 = (corner.dx - touch.dx).abs();
      final w2 = viewSize.width * w1 / w0;
      final newAx = (corner.dx - w2).abs();

      final h1 = (corner.dy - touch.dy).abs();
      final h2 = w2 * h1 / w1;
      final newAy = (corner.dy - h2).abs();

      return Offset(newAx, newAy);
    }
    return touch;
  }

  /// 计算所有控制点坐标（对标 BookPage calcPointsXY）
  void _calcPointsXY() {
    // g点：a和f的中点
    g = Offset((a.dx + f.dx) / 2, (a.dy + f.dy) / 2);

    // e点：贝塞尔控制点（沿下边缘）
    double ex;
    if ((f.dx - g.dx).abs() < 0.001) {
      ex = g.dx;
    } else {
      ex = g.dx - (f.dy - g.dy) * (f.dy - g.dy) / (f.dx - g.dx);
    }
    e = Offset(ex, f.dy);

    // h点：贝塞尔控制点（沿右边缘）
    double hy;
    if ((f.dy - g.dy).abs() < 0.001) {
      hy = g.dy;
    } else {
      hy = g.dy - (f.dx - g.dx) * (f.dx - g.dx) / (f.dy - g.dy);
    }
    h = Offset(f.dx, hy);

    // c点：贝塞尔起点（下边缘）
    c = Offset(e.dx - (f.dx - e.dx) / 2, f.dy);

    // j点：贝塞尔起点（右边缘）
    j = Offset(f.dx, h.dy - (f.dy - h.dy) / 2);

    // b点和k点：贝塞尔曲线与对角线的交点
    b = _getIntersectionPoint(a, e, c, j);
    k = _getIntersectionPoint(a, h, c, j);

    // d点和i点：贝塞尔曲线顶点
    d = Offset(
      (c.dx + 2 * e.dx + b.dx) / 4,
      (2 * e.dy + c.dy + b.dy) / 4,
    );
    i = Offset(
      (j.dx + 2 * h.dx + k.dx) / 4,
      (2 * h.dy + j.dy + k.dy) / 4,
    );

    // 计算阴影距离
    // d点到ae的距离
    final lA = a.dy - e.dy;
    final lB = e.dx - a.dx;
    final lC = a.dx * e.dy - e.dx * a.dy;
    lPathAShadowDis =
        (lA * d.dx + lB * d.dy + lC).abs() / math.sqrt(lA * lA + lB * lB);

    // i点到ah的距离
    final rA = a.dy - h.dy;
    final rB = h.dx - a.dx;
    final rC = a.dx * h.dy - h.dx * a.dy;
    rPathAShadowDis =
        (rA * i.dx + rB * i.dy + rC).abs() / math.sqrt(rA * rA + rB * rB);
  }

  /// 计算两线段交点
  Offset _getIntersectionPoint(Offset p1, Offset p2, Offset p3, Offset p4) {
    final x1 = p1.dx, y1 = p1.dy;
    final x2 = p2.dx, y2 = p2.dy;
    final x3 = p3.dx, y3 = p3.dy;
    final x4 = p4.dx, y4 = p4.dy;

    final denominator = (x3 - x4) * (y1 - y2) - (x1 - x2) * (y3 - y4);
    if (denominator.abs() < 0.001) {
      return Offset((x1 + x2 + x3 + x4) / 4, (y1 + y2 + y3 + y4) / 4);
    }

    final pointX =
        ((x1 - x2) * (x3 * y4 - x4 * y3) - (x3 - x4) * (x1 * y2 - x2 * y1)) /
            denominator;
    final pointY =
        ((y1 - y2) * (x3 * y4 - x4 * y3) - (x1 * y2 - x2 * y1) * (y3 - y4)) /
            ((y1 - y2) * (x3 - x4) - (x1 - x2) * (y3 - y4));

    return Offset(pointX, pointY);
  }

  /// 获取A区域路径（当前页可见区域）
  Path _getPathA() {
    pathA.reset();
    final isTopRight = f.dy == 0;

    if (isTopRight) {
      // f点在右上角
      pathA.moveTo(0, 0);
      pathA.lineTo(c.dx, c.dy);
      pathA.quadraticBezierTo(e.dx, e.dy, b.dx, b.dy);
      pathA.lineTo(a.dx, a.dy);
      pathA.lineTo(k.dx, k.dy);
      pathA.quadraticBezierTo(h.dx, h.dy, j.dx, j.dy);
      pathA.lineTo(viewSize.width, viewSize.height);
      pathA.lineTo(0, viewSize.height);
      pathA.close();
    } else {
      // f点在右下角
      pathA.moveTo(0, 0);
      pathA.lineTo(0, viewSize.height);
      pathA.lineTo(c.dx, c.dy);
      pathA.quadraticBezierTo(e.dx, e.dy, b.dx, b.dy);
      pathA.lineTo(a.dx, a.dy);
      pathA.lineTo(k.dx, k.dy);
      pathA.quadraticBezierTo(h.dx, h.dy, j.dx, j.dy);
      pathA.lineTo(viewSize.width, 0);
      pathA.close();
    }
    return pathA;
  }

  /// 获取C区域路径（翻起的背面）
  Path _getPathC() {
    pathC.reset();
    pathC.moveTo(i.dx, i.dy);
    pathC.lineTo(d.dx, d.dy);
    pathC.lineTo(b.dx, b.dy);
    pathC.lineTo(a.dx, a.dy);
    pathC.lineTo(k.dx, k.dy);
    pathC.close();
    return pathC;
  }

  /// 绘制A区域内容（当前页）
  void _drawPathAContent(Canvas canvas) {
    canvas.save();
    canvas.clipPath(_getPathA());
    canvas.drawPicture(curPagePicture!);

    // 绘制A区域阴影
    _drawPathALeftShadow(canvas);
    _drawPathARightShadow(canvas);

    canvas.restore();
  }

  /// 绘制A区域左侧阴影
  void _drawPathALeftShadow(Canvas canvas) {
    canvas.save();

    final isTopRight = f.dy == 0;
    final shadowWidth = lPathAShadowDis / 2;

    // 创建阴影区域
    Path shadowPath = Path();
    shadowPath.moveTo(
        a.dx - math.max(rPathAShadowDis, lPathAShadowDis) / 2, a.dy);
    shadowPath.lineTo(d.dx, d.dy);
    shadowPath.lineTo(e.dx, e.dy);
    shadowPath.lineTo(a.dx, a.dy);
    shadowPath.close();

    canvas.clipPath(shadowPath);

    final mDegrees = math.atan2(e.dx - a.dx, a.dy - e.dy);
    canvas.translate(e.dx, e.dy);
    canvas.rotate(mDegrees);

    final colors = isTopRight
        ? [const Color(0x01333333), const Color(0x33333333)]
        : [const Color(0x33333333), const Color(0x01333333)];

    final shadowPaint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(
          isTopRight ? -shadowWidth : 0,
          0,
          isTopRight ? 0 : shadowWidth,
          viewSize.height,
        ),
      );

    canvas.drawRect(
      Rect.fromLTRB(-shadowWidth, 0, shadowWidth, viewSize.height),
      shadowPaint,
    );

    canvas.restore();
  }

  /// 绘制A区域右侧阴影
  void _drawPathARightShadow(Canvas canvas) {
    canvas.save();

    final isTopRight = f.dy == 0;
    final shadowWidth = rPathAShadowDis / 2;
    final viewDiagonalLength = math.sqrt(
        viewSize.width * viewSize.width + viewSize.height * viewSize.height);

    // 创建阴影区域
    Path shadowPath = Path();
    shadowPath.moveTo(
        a.dx - math.max(rPathAShadowDis, lPathAShadowDis) / 2, a.dy);
    shadowPath.lineTo(h.dx, h.dy);
    shadowPath.lineTo(a.dx, a.dy);
    shadowPath.close();

    canvas.clipPath(shadowPath);

    final mDegrees = math.atan2(a.dy - h.dy, a.dx - h.dx);
    canvas.translate(h.dx, h.dy);
    canvas.rotate(mDegrees);

    final colors = isTopRight
        ? [
            const Color(0x22333333),
            const Color(0x01333333),
            const Color(0x01333333)
          ]
        : [
            const Color(0x01333333),
            const Color(0x01333333),
            const Color(0x22333333)
          ];

    final shadowPaint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(0, isTopRight ? -shadowWidth : 0, viewDiagonalLength * 10,
            isTopRight ? 0 : shadowWidth),
      );

    canvas.drawRect(
      Rect.fromLTRB(0, -shadowWidth, viewDiagonalLength * 10, shadowWidth),
      shadowPaint,
    );

    canvas.restore();
  }

  /// 绘制B区域内容（底层页面）
  void _drawPathBContent(Canvas canvas) {
    if (nextPagePicture == null) return;

    canvas.save();

    // 裁剪出B区域：整个页面 - A区域 - C区域
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, viewSize.width, viewSize.height));

    final pathACombined =
        Path.combine(PathOperation.union, _getPathA(), _getPathC());
    final pathB =
        Path.combine(PathOperation.difference, fullPath, pathACombined);

    canvas.clipPath(pathB);
    canvas.drawPicture(nextPagePicture!);

    // 绘制B区域阴影
    _drawPathBShadow(canvas);

    canvas.restore();
  }

  /// 绘制B区域阴影
  void _drawPathBShadow(Canvas canvas) {
    canvas.save();

    final isTopRight = f.dy == 0;
    final aTof = math.sqrt(math.pow(a.dx - f.dx, 2) + math.pow(a.dy - f.dy, 2));
    final viewDiagonalLength = math.sqrt(
        viewSize.width * viewSize.width + viewSize.height * viewSize.height);

    final shadowWidth = aTof / 4;

    final colors = isTopRight
        ? [const Color(0x55111111), const Color(0x00111111)]
        : [const Color(0x00111111), const Color(0x55111111)];

    final shadowPaint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(
          isTopRight ? 0 : -shadowWidth,
          0,
          isTopRight ? shadowWidth : 0,
          viewDiagonalLength,
        ),
      );

    final rotateDegrees = math.atan2(e.dx - f.dx, h.dy - f.dy);
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotateDegrees);

    canvas.drawRect(
      Rect.fromLTRB(-shadowWidth, 0, shadowWidth, viewDiagonalLength),
      shadowPaint,
    );

    canvas.restore();
  }

  /// 绘制C区域内容（翻起页的背面）
  void _drawPathCContent(Canvas canvas) {
    canvas.save();

    // 裁剪出C区域（C区域 - A区域的交集的补集部分）
    final pathCMinusA =
        Path.combine(PathOperation.difference, _getPathC(), _getPathA());
    canvas.clipPath(pathCMinusA);

    // 计算镜像变换矩阵
    final eh = math.sqrt(math.pow(f.dx - e.dx, 2) + math.pow(h.dy - f.dy, 2));
    if (eh < 0.001) {
      canvas.restore();
      return;
    }

    final sin0 = (f.dx - e.dx) / eh;
    final cos0 = (h.dy - f.dy) / eh;

    // 设置翻转和旋转矩阵
    final a11 = -(1 - 2 * sin0 * sin0);
    final a12 = 2 * sin0 * cos0;
    final a21 = 2 * sin0 * cos0;
    final a22 = 1 - 2 * sin0 * sin0;

    // 构建变换矩阵：先平移到原点，翻转旋转，再平移回来
    // M = T(e) * R * T(-e) 其中 R 是镜像矩阵
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
      e.dx - a11 * e.dx - a12 * e.dy,
      e.dy - a21 * e.dx - a22 * e.dy,
      0,
      1,
    );

    canvas.transform(matrix.storage);
    canvas.drawPicture(curPagePicture!);

    // 绘制半透明遮罩模拟纸张背面
    canvas.drawPaint(Paint()..color = backgroundColor.withValues(alpha: 0.4));

    // 重置变换
    canvas.restore();
    canvas.save();
    canvas.clipPath(pathCMinusA);

    // 绘制C区域阴影
    _drawPathCShadow(canvas);

    canvas.restore();
  }

  /// 绘制C区域阴影
  void _drawPathCShadow(Canvas canvas) {
    canvas.save();

    final isTopRight = f.dy == 0;
    final viewDiagonalLength = math.sqrt(
        viewSize.width * viewSize.width + viewSize.height * viewSize.height);

    final midpointCE = (c.dx + e.dx) / 2;
    final midpointJH = (j.dy + h.dy) / 2;
    final minDisToControlPoint = math.min(
      (midpointCE - e.dx).abs(),
      (midpointJH - h.dy).abs(),
    );

    final colors = isTopRight
        ? [const Color(0x00333333), const Color(0x55333333)]
        : [const Color(0x55333333), const Color(0x00333333)];

    final shadowWidth = minDisToControlPoint;

    final shadowPaint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromLTRB(
          isTopRight ? 0 : -shadowWidth,
          0,
          isTopRight ? shadowWidth : 0,
          viewDiagonalLength,
        ),
      );

    final mDegrees = math.atan2(e.dx - f.dx, h.dy - f.dy);
    canvas.translate(c.dx, c.dy);
    canvas.rotate(mDegrees);

    canvas.drawRect(
      Rect.fromLTRB(-shadowWidth - 30, 0, shadowWidth + 1, viewDiagonalLength),
      shadowPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SimulationPagePainter oldDelegate) {
    return touch != oldDelegate.touch ||
        curPagePicture != oldDelegate.curPagePicture ||
        nextPagePicture != oldDelegate.nextPagePicture ||
        cornerX != oldDelegate.cornerX ||
        cornerY != oldDelegate.cornerY;
  }
}
