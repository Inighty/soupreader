import 'package:flutter/cupertino.dart';

Widget buildCupertinoBottomSheetDragHandle(BuildContext context) {
  final handleColor = CupertinoColors.systemGrey3
      .resolveFrom(context)
      .withValues(alpha: 0.72);
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: handleColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

List<Widget> buildCupertinoBottomSheetHeader({
  required Widget? title,
  required Widget? message,
  required Color titleColor,
  required Color messageColor,
}) {
  final widgets = <Widget>[];
  if (title != null) {
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: DefaultTextStyle(
          style: TextStyle(
            color: titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          child: Center(child: title),
        ),
      ),
    );
  }
  if (message != null) {
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        child: DefaultTextStyle(
          style: TextStyle(color: messageColor, fontSize: 13, height: 1.3),
          child: Center(child: message),
        ),
      ),
    );
  }
  return widgets;
}

