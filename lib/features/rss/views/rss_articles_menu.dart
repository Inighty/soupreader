import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_popover_menu.dart';
import '../models/rss_source.dart';

/// 文章列表「更多」菜单的可选动作。
enum RssArticlesMenuAction {
  login,
  refreshSort,
  setSourceVariable,
  editSource,
  switchLayout,
  readRecord,
  clear,
}

String rssArticlesMenuActionText(RssArticlesMenuAction action) {
  switch (action) {
    case RssArticlesMenuAction.login:
      return '登录';
    case RssArticlesMenuAction.refreshSort:
      return '刷新分类';
    case RssArticlesMenuAction.setSourceVariable:
      return '设置源变量';
    case RssArticlesMenuAction.editSource:
      return '编辑源';
    case RssArticlesMenuAction.switchLayout:
      return '切换布局';
    case RssArticlesMenuAction.readRecord:
      return '阅读记录';
    case RssArticlesMenuAction.clear:
      return '清除';
  }
}

IconData rssArticlesMenuActionIcon(RssArticlesMenuAction action) {
  switch (action) {
    case RssArticlesMenuAction.login:
      return CupertinoIcons.person;
    case RssArticlesMenuAction.refreshSort:
      return CupertinoIcons.refresh;
    case RssArticlesMenuAction.setSourceVariable:
      return CupertinoIcons.slider_horizontal_3;
    case RssArticlesMenuAction.editSource:
      return CupertinoIcons.pencil;
    case RssArticlesMenuAction.switchLayout:
      return CupertinoIcons.square_grid_2x2;
    case RssArticlesMenuAction.readRecord:
      return CupertinoIcons.clock;
    case RssArticlesMenuAction.clear:
      return CupertinoIcons.delete;
  }
}

List<RssArticlesMenuAction> buildRssArticlesMenuActions(RssSource source) {
  final actions = <RssArticlesMenuAction>[
    RssArticlesMenuAction.refreshSort,
    RssArticlesMenuAction.setSourceVariable,
    RssArticlesMenuAction.editSource,
    RssArticlesMenuAction.switchLayout,
    RssArticlesMenuAction.readRecord,
    RssArticlesMenuAction.clear,
  ];
  if ((source.loginUrl ?? '').trim().isNotEmpty) {
    actions.insert(0, RssArticlesMenuAction.login);
  }
  return actions;
}

Future<RssArticlesMenuAction?> showRssArticlesMoreMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<RssArticlesMenuAction> actions,
}) {
  return showAppPopoverMenu<RssArticlesMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: actions
        .map(
          (action) => AppPopoverMenuItem(
            value: action,
            icon: rssArticlesMenuActionIcon(action),
            label: rssArticlesMenuActionText(action),
            isDestructiveAction: action == RssArticlesMenuAction.clear,
          ),
        )
        .toList(growable: false),
  );
}
