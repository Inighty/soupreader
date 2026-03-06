import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

/// 统一 squircle 玻璃容器（用于卡片/分组等管理页表面）。
class AppSquircleSurface extends StatelessWidget {
  const AppSquircleSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    required this.backgroundColor,
    required this.borderColor,
    this.borderWidth = AppDesignTokens.hairlineBorderWidth,
    this.radius = AppDesignTokens.radiusCard,
    this.blurBackground = true,
    this.blurSigma = AppDesignTokens.glassBlurSigma,
    this.shadows = const <BoxShadow>[],
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final bool blurBackground;
  final double blurSigma;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final side = borderWidth > 0
        ? BorderSide(color: borderColor, width: borderWidth)
        : BorderSide.none;
    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      side: side,
    );
    final decorated = DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: shape,
        shadows: shadows,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!blurBackground) return decorated;

    return RepaintBoundary(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: decorated,
        ),
      ),
    );
  }
}
