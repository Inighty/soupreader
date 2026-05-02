import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_nav_bar_button.dart';

/// 阅读样式列表右上角菜单动作。
enum ReaderStyleListMenuAction { addNew, import_, export_, share }

/// 阅读样式列表 sheet 的顶部 header（拖动条 + 标题 + 多选/更多按钮）。
class ReaderStyleListHeader extends StatelessWidget {
  final Color labelColor;
  final Color sep;
  final Color accent;
  final bool isSelecting;
  final bool hasConfigs;
  final VoidCallback onBack;
  final VoidCallback? onToggleSelecting;
  final VoidCallback? onShowMoreMenu;
  final GlobalKey moreMenuKey;

  const ReaderStyleListHeader({
    super.key,
    required this.labelColor,
    required this.sep,
    required this.accent,
    required this.isSelecting,
    required this.hasConfigs,
    required this.onBack,
    required this.onToggleSelecting,
    required this.onShowMoreMenu,
    required this.moreMenuKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: sep,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              AppNavBarButton(
                onPressed: onBack,
                child: Icon(CupertinoIcons.back, color: accent, size: 22),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '背景文字样式',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              AppNavBarButton(
                onPressed: onToggleSelecting,
                child: Text(
                  isSelecting ? '完成' : '多选',
                  style: TextStyle(color: accent, fontSize: 13),
                ),
              ),
              AppNavBarButton(
                key: moreMenuKey,
                onPressed: onShowMoreMenu,
                child: Icon(
                  CupertinoIcons.ellipsis,
                  color: isSelecting ? CupertinoColors.inactiveGray : accent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Container(height: 0.5, color: sep),
      ],
    );
  }
}

/// 阅读样式列表中的"内置"标签徽章。
class ReaderStyleBuiltinBadge extends StatelessWidget {
  final Color secondaryLabel;

  const ReaderStyleBuiltinBadge({super.key, required this.secondaryLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: secondaryLabel.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '内置',
        style: TextStyle(color: secondaryLabel, fontSize: 11),
      ),
    );
  }
}

/// 显示样式背景色/文字色的小圆点。
class ReaderStyleColorDot extends StatelessWidget {
  final Color color;
  final Color border;

  const ReaderStyleColorDot({
    super.key,
    required this.color,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 0.5),
      ),
    );
  }
}

/// 多选批量操作底部 Bar：全选/反选/删除。
class ReaderStyleBatchBar extends StatelessWidget {
  final Color sep;
  final Color accent;
  final bool allSelected;
  final bool hasChecked;
  final VoidCallback onToggleSelectAll;
  final VoidCallback? onInvertSelection;
  final VoidCallback? onDeleteChecked;

  const ReaderStyleBatchBar({
    super.key,
    required this.sep,
    required this.accent,
    required this.allSelected,
    required this.hasChecked,
    required this.onToggleSelectAll,
    required this.onInvertSelection,
    required this.onDeleteChecked,
  });

  @override
  Widget build(BuildContext context) {
    final barBg =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    const disabledColor = CupertinoColors.inactiveGray;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: sep, width: 0.5)),
        color: barBg,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(30, 30),
                onPressed: onToggleSelectAll,
                child: Text(
                  allSelected ? '取消全选' : '全选',
                  style: TextStyle(color: accent, fontSize: 13),
                ),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(30, 30),
                onPressed: hasChecked ? onInvertSelection : null,
                child: Text(
                  '反选',
                  style: TextStyle(
                    color: hasChecked ? accent : disabledColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(30, 30),
                onPressed: hasChecked ? onDeleteChecked : null,
                child: Text(
                  '删除',
                  style: TextStyle(
                    color: hasChecked
                        ? CupertinoColors.destructiveRed
                        : disabledColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
