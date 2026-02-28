import 'package:flutter/cupertino.dart';

import 'cupertino_bottom_sheet_helpers.dart';

class CupertinoActionSheetBottomSheet extends StatelessWidget {
  final CupertinoActionSheet sheet;

  const CupertinoActionSheetBottomSheet({
    super.key,
    required this.sheet,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final subtle = CupertinoColors.secondaryLabel.resolveFrom(context);
    final destructive = CupertinoColors.systemRed.resolveFrom(context);
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset =
        mediaQuery.padding.bottom > 0 ? mediaQuery.padding.bottom : 8.0;

    final headerWidgets = buildCupertinoBottomSheetHeader(
      title: sheet.title,
      message: sheet.message,
      titleColor: labelColor,
      messageColor: subtle,
    );

    final actionTiles = <Widget>[];
    for (final action in sheet.actions ?? const <Widget>[]) {
      final tile = _convertSheetActionToTile(
        labelColor: labelColor,
        destructiveColor: destructive,
        action: action,
      );
      if (tile == null) continue;
      actionTiles.add(tile);
    }

    final cancelTile = _convertSheetActionToTile(
      labelColor: labelColor,
      destructiveColor: destructive,
      action: sheet.cancelButton,
      forceDefaultWeight: true,
    );

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, bottomInset),
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: [
              buildCupertinoBottomSheetDragHandle(context),
              ...headerWidgets,
              if (actionTiles.isNotEmpty)
                CupertinoListSection.insetGrouped(
                  children: actionTiles,
                ),
              if (cancelTile != null)
                CupertinoListSection.insetGrouped(
                  children: [cancelTile],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _convertSheetActionToTile({
    required Color labelColor,
    required Color destructiveColor,
    required Widget? action,
    bool forceDefaultWeight = false,
  }) {
    if (action == null) return null;
    if (action is! CupertinoActionSheetAction) return action;
    final color = action.isDestructiveAction ? destructiveColor : labelColor;
    final title = DefaultTextStyle(
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: (forceDefaultWeight || action.isDefaultAction)
            ? FontWeight.w700
            : FontWeight.w600,
      ),
      child: action.child,
    );
    return CupertinoListTile.notched(
      title: title,
      onTap: action.onPressed,
    );
  }
}
