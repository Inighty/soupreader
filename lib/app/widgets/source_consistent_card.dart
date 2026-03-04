import 'package:flutter/cupertino.dart';

import '../theme/source_ui_tokens.dart';
import 'app_squircle_surface.dart';

/// 书源页统一卡片容器。
class SourceConsistentCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  const SourceConsistentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBackground = backgroundColor ??
        SourceUiTokens.resolveCardBackgroundColor(context)
            .withValues(alpha: 0.9);
    final resolvedBorder =
        borderColor ?? SourceUiTokens.resolveSeparatorColor(context);
    final shadowColor = CupertinoColors.black.withValues(alpha: 0.22);

    return AppSquircleSurface(
      padding: padding,
      backgroundColor: resolvedBackground,
      borderColor: resolvedBorder.withValues(
        alpha: SourceUiTokens.discoveryExpandedCardBorderAlpha,
      ),
      borderWidth: SourceUiTokens.borderWidth,
      radius: SourceUiTokens.radiusCard,
      blurBackground: true,
      shadows: <BoxShadow>[
        BoxShadow(
          color: shadowColor,
          offset: const Offset(0, 7),
          blurRadius: 20,
          spreadRadius: -11,
        ),
      ],
      child: child,
    );
  }
}
