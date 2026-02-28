import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

class AppPopoverMenuItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDestructiveAction;

  const AppPopoverMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.enabled = true,
    this.isDestructiveAction = false,
  });
}

class _PopoverAnchor {
  final Rect rect;
  final Size overlaySize;
  final EdgeInsets safePadding;

  const _PopoverAnchor({
    required this.rect,
    required this.overlaySize,
    required this.safePadding,
  });
}

class _PopoverPosition {
  final double left;
  final double top;

  const _PopoverPosition({
    required this.left,
    required this.top,
  });
}

Future<T?> showAppPopoverMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<AppPopoverMenuItem<T>> items,
  double width = 196,
  double itemHeight = 44,
  double radius = 12,
  double verticalPadding = 6,
}) {
  assert(items.isNotEmpty, 'items should not be empty');
  final anchor = _resolveAnchor(context: context, anchorKey: anchorKey);
  final estimatedHeight = _estimateHeight(
    itemCount: items.length,
    itemHeight: itemHeight,
    verticalPadding: verticalPadding,
  );
  final position = _resolvePosition(
    anchor: anchor,
    width: width,
    estimatedHeight: estimatedHeight,
  );
  return showCupertinoModalPopup<T>(
    context: context,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.06),
    barrierDismissible: true,
    builder: (popupContext) {
      final labelColor = CupertinoColors.label.resolveFrom(popupContext);
      final iconColor = CupertinoColors.secondaryLabel.resolveFrom(popupContext);
      final destructiveColor = CupertinoColors.systemRed.resolveFrom(popupContext);
      final bg = CupertinoColors.systemBackground.resolveFrom(popupContext);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(popupContext).pop(),
        child: Stack(
          children: [
            Positioned(
              left: position.left,
              top: position.top,
              width: width,
              child: _PopoverSurface(
                backgroundColor: bg,
                radius: radius,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: verticalPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _PopoverMenuRow(
                          height: itemHeight,
                          icon: items[i].icon,
                          label: items[i].label,
                          enabled: items[i].enabled,
                          iconColor: items[i].isDestructiveAction
                              ? destructiveColor
                              : iconColor,
                          textColor: items[i].isDestructiveAction
                              ? destructiveColor
                              : labelColor,
                          onTap: items[i].enabled
                              ? () => Navigator.of(popupContext).pop(items[i].value)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

_PopoverAnchor _resolveAnchor({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) {
    throw FlutterError('showAppPopoverMenu: anchorKey has no currentContext');
  }
  final renderBox = anchorContext.findRenderObject();
  if (renderBox is! RenderBox || !renderBox.hasSize) {
    throw FlutterError('showAppPopoverMenu: anchorKey renderBox not ready');
  }
  final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
  final anchorOffset = renderBox.localToGlobal(Offset.zero);
  return _PopoverAnchor(
    rect: anchorOffset & renderBox.size,
    overlaySize: overlayBox.size,
    safePadding: MediaQuery.of(context).padding,
  );
}

double _estimateHeight({
  required int itemCount,
  required double itemHeight,
  required double verticalPadding,
}) {
  return verticalPadding * 2 + itemHeight * math.max(1, itemCount);
}

_PopoverPosition _resolvePosition({
  required _PopoverAnchor anchor,
  required double width,
  required double estimatedHeight,
}) {
  const screenEdgePadding = 10.0;
  final overlaySize = anchor.overlaySize;
  final maxLeft = overlaySize.width - width - screenEdgePadding;
  final desiredLeft = anchor.rect.right - width;
  final clampedLeft = desiredLeft.clamp(screenEdgePadding, maxLeft).toDouble();

  final belowTop = anchor.rect.bottom + 8;
  final aboveTop = anchor.rect.top - estimatedHeight - 8;
  final canShowBelow = belowTop + estimatedHeight <=
      overlaySize.height -
          math.max(anchor.safePadding.bottom, screenEdgePadding);
  final top = canShowBelow
      ? belowTop
      : math.max(screenEdgePadding + anchor.safePadding.top, aboveTop);

  return _PopoverPosition(left: clampedLeft, top: top.toDouble());
}

class _PopoverSurface extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double radius;

  const _PopoverSurface({
    required this.child,
    required this.backgroundColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _PopoverMenuRow extends StatelessWidget {
  final double height;
  final IconData icon;
  final String label;
  final bool enabled;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _PopoverMenuRow({
    required this.height,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
