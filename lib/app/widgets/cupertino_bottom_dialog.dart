import 'package:flutter/cupertino.dart';

import 'cupertino_action_sheet_bottom_sheet.dart';
import 'cupertino_bottom_sheet_helpers.dart';

Future<T?> showCupertinoBottomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  String? barrierLabel,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
  final resolvedBarrierColor = barrierColor ??
      (isDark ? const Color(0x99000000) : const Color(0x4D000000));
  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierColor: resolvedBarrierColor,
    barrierDismissible: barrierDismissible,
    semanticsDismissible: barrierDismissible,
    routeSettings: routeSettings,
    builder: (popupContext) {
      final child = builder(popupContext);
      return CupertinoTheme(
        data: CupertinoTheme.of(context),
        child: _adaptDialogToBottomSheet(child),
      );
    },
  );
}

Widget _adaptDialogToBottomSheet(Widget child) {
  if (child is CupertinoAlertDialog) {
    return _CupertinoAlertBottomSheet(dialog: child);
  }
  if (child is CupertinoActionSheet) {
    return CupertinoActionSheetBottomSheet(sheet: child);
  }
  return child;
}

bool _isCancelAction(Widget child) {
  if (child is! Text) return false;
  final text = child.data?.trim() ?? '';
  return text == '取消' || text == '关闭';
}

class _CupertinoAlertBottomSheet extends StatelessWidget {
  final CupertinoAlertDialog dialog;

  const _CupertinoAlertBottomSheet({
    required this.dialog,
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

    final actions = _splitActions(
      actions: dialog.actions,
      labelColor: labelColor,
      destructiveColor: destructive,
    );
    final headerWidgets = buildCupertinoBottomSheetHeader(
      title: dialog.title,
      message: dialog.content,
      titleColor: labelColor,
      messageColor: subtle,
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
              if (actions.normal.isNotEmpty)
                CupertinoListSection.insetGrouped(
                  children: actions.normal,
                ),
              if (actions.cancel != null)
                CupertinoListSection.insetGrouped(
                  children: [actions.cancel!],
                ),
            ],
          ),
        ),
      ),
    );
  }

  _DialogSheetActions _splitActions({
    required List<Widget> actions,
    required Color labelColor,
    required Color destructiveColor,
  }) {
    final normal = <Widget>[];
    Widget? cancel;
    for (final action in actions) {
      final tile = _convertActionToTile(
        labelColor: labelColor,
        destructiveColor: destructiveColor,
        action: action,
      );
      if (tile == null) continue;
      if (cancel == null && _isCancelLikeAction(action)) {
        cancel = tile;
        continue;
      }
      normal.add(tile);
    }
    return _DialogSheetActions(normal: normal, cancel: cancel);
  }

  bool _isCancelLikeAction(Widget rawAction) {
    if (rawAction is! CupertinoDialogAction) return false;
    return _isCancelAction(rawAction.child);
  }

  Widget? _convertActionToTile({
    required Color labelColor,
    required Color destructiveColor,
    required Widget action,
  }) {
    if (action is! CupertinoDialogAction) return action;
    final enabled = action.onPressed != null;
    final color = action.isDestructiveAction ? destructiveColor : labelColor;
    final title = DefaultTextStyle(
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: action.isDefaultAction ? FontWeight.w700 : FontWeight.w600,
      ),
      child: action.child,
    );
    return CupertinoListTile.notched(
      title: title,
      onTap: enabled ? action.onPressed : null,
    );
  }
}

class _DialogSheetActions {
  final List<Widget> normal;
  final Widget? cancel;

  const _DialogSheetActions({
    required this.normal,
    required this.cancel,
  });
}
