import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../models/rss_source.dart';

/// 订阅源右键菜单的动作。
enum RssSubscriptionSourceAction {
  moveToTop,
  edit,
  disable,
  delete,
}

/// 弹出"订阅源长按操作"菜单。
Future<RssSubscriptionSourceAction?> showRssSubscriptionSourceActionsSheet({
  required BuildContext context,
  required RssSource source,
}) {
  return showAppActionListSheet<RssSubscriptionSourceAction>(
    context: context,
    title: source.sourceName,
    showCancel: true,
    items: const [
      AppActionListItem<RssSubscriptionSourceAction>(
        value: RssSubscriptionSourceAction.moveToTop,
        icon: CupertinoIcons.arrow_up_circle,
        label: '置顶',
      ),
      AppActionListItem<RssSubscriptionSourceAction>(
        value: RssSubscriptionSourceAction.edit,
        icon: CupertinoIcons.pencil,
        label: '编辑',
      ),
      AppActionListItem<RssSubscriptionSourceAction>(
        value: RssSubscriptionSourceAction.disable,
        icon: CupertinoIcons.pause_circle,
        label: '禁用',
      ),
      AppActionListItem<RssSubscriptionSourceAction>(
        value: RssSubscriptionSourceAction.delete,
        icon: CupertinoIcons.delete,
        label: '删除',
        isDestructiveAction: true,
      ),
    ],
  );
}

/// 规则订阅入口 tile。
class RssSubscriptionRuleEntry extends StatelessWidget {
  final VoidCallback onTap;

  const RssSubscriptionRuleEntry({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context)
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: CupertinoListTile.notched(
        leading: const Icon(CupertinoIcons.square_list),
        title: const Text('规则订阅'),
        additionalInfo: Text(
          '导入地址',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        trailing: const CupertinoListTileChevron(),
        onTap: onTap,
      ),
    );
  }
}

/// 单个订阅源 tile。
class RssSubscriptionSourceItem extends StatelessWidget {
  final RssSource source;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onToggleEnabled;

  const RssSubscriptionSourceItem({
    super.key,
    required this.source,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground
              .resolveFrom(context)
              .resolveFrom(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        ),
        child: CupertinoListTile.notched(
          leading: _SourceIcon(iconUrl: source.sourceIcon),
          title: Text(source.sourceName),
          subtitle: source.sourceGroup?.trim().isNotEmpty == true
              ? Text(
                  source.sourceGroup!.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                )
              : null,
          trailing: CupertinoSwitch(
            value: source.enabled,
            onChanged: onToggleEnabled,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final String iconUrl;

  const _SourceIcon({required this.iconUrl});

  @override
  Widget build(BuildContext context) {
    final url = iconUrl.trim();
    if (url.isEmpty) {
      return const _DefaultSourceIcon();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _DefaultSourceIcon(),
      ),
    );
  }
}

class _DefaultSourceIcon extends StatelessWidget {
  const _DefaultSourceIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.dot_radiowaves_left_right, size: 18),
    );
  }
}

/// 订阅页空态：「无启用订阅源」或「筛选无结果」。
class RssSubscriptionEmptyState extends StatelessWidget {
  final int enabledCount;
  final VoidCallback onOpenSourceSettings;
  final VoidCallback onClearFilter;

  const RssSubscriptionEmptyState({
    super.key,
    required this.enabledCount,
    required this.onOpenSourceSettings,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final noEnabled = enabledCount == 0;
    final title = noEnabled ? '暂无启用订阅源' : '没有匹配结果';
    final action = noEnabled ? '返回订阅源管理' : '清除筛选';
    final message =
        noEnabled ? '请先在订阅源管理中启用订阅源' : '当前筛选条件下暂无结果';
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 84),
      title: title,
      message: message,
      action: CupertinoButton(
        onPressed: noEnabled ? onOpenSourceSettings : onClearFilter,
        child: Text(action),
      ),
    );
  }
}
