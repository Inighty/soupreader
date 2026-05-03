import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/rss_source.dart';

/// 阅读页右上角“更多”菜单的可选动作。
enum RssReadMenuAction {
  login,
  browserOpen,
}

String _readMenuActionText(RssReadMenuAction action) {
  switch (action) {
    case RssReadMenuAction.login:
      return '登录';
    case RssReadMenuAction.browserOpen:
      return '浏览器打开';
  }
}

List<RssReadMenuAction> _buildReadMenuActions({required bool canOpenLogin}) {
  final actions = <RssReadMenuAction>[];
  if (canOpenLogin) {
    actions.add(RssReadMenuAction.login);
  }
  actions.add(RssReadMenuAction.browserOpen);
  return actions;
}

/// 是否允许展示登录入口（依据当前订阅源是否配置了 loginUrl）。
bool canOpenRssSourceLogin(RssSource? source) {
  return (source?.loginUrl ?? '').trim().isNotEmpty;
}

/// 弹出 RSS 阅读页底部“更多”菜单。
Future<RssReadMenuAction?> showRssReadMoreMenu({
  required BuildContext context,
  required RssSource? source,
}) async {
  final actions =
      _buildReadMenuActions(canOpenLogin: canOpenRssSourceLogin(source));
  return showCupertinoBottomSheetDialog<RssReadMenuAction>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: actions
          .map(
            (action) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, action),
              child: Text(_readMenuActionText(action)),
            ),
          )
          .toList(growable: false),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('取消'),
      ),
    ),
  );
}
