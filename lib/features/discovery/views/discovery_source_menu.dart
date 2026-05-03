import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../core/models/book_source.dart';

/// 发现页书源长按菜单的可选动作。
enum DiscoverySourceMenuAction {
  edit,
  moveToTop,
  login,
  search,
  refresh,
  delete,
}

/// 弹出书源长按菜单（编辑 / 置顶 / 登录 / 搜索 / 刷新 / 删除）。
Future<DiscoverySourceMenuAction?> showDiscoverySourceActionsMenu({
  required BuildContext context,
  required BookSource source,
}) {
  final hasLogin = (source.loginUrl ?? '').trim().isNotEmpty;
  final items = <AppActionListItem<DiscoverySourceMenuAction>>[
    const AppActionListItem<DiscoverySourceMenuAction>(
      value: DiscoverySourceMenuAction.edit,
      icon: CupertinoIcons.pencil,
      label: '编辑',
    ),
    const AppActionListItem<DiscoverySourceMenuAction>(
      value: DiscoverySourceMenuAction.moveToTop,
      icon: CupertinoIcons.arrow_up_circle,
      label: '置顶',
    ),
    if (hasLogin)
      const AppActionListItem<DiscoverySourceMenuAction>(
        value: DiscoverySourceMenuAction.login,
        icon: CupertinoIcons.person_crop_circle,
        label: '登录',
      ),
    const AppActionListItem<DiscoverySourceMenuAction>(
      value: DiscoverySourceMenuAction.search,
      icon: CupertinoIcons.search,
      label: '搜索',
    ),
    const AppActionListItem<DiscoverySourceMenuAction>(
      value: DiscoverySourceMenuAction.refresh,
      icon: CupertinoIcons.refresh,
      label: '刷新',
    ),
    const AppActionListItem<DiscoverySourceMenuAction>(
      value: DiscoverySourceMenuAction.delete,
      icon: CupertinoIcons.delete,
      label: '删除',
      isDestructiveAction: true,
    ),
  ];
  return showAppActionListSheet<DiscoverySourceMenuAction>(
    context: context,
    title: source.bookSourceName,
    message: source.bookSourceUrl,
    showCancel: true,
    items: items,
  );
}
