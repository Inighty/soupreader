import 'package:flutter/cupertino.dart';

/// 远程书籍选择条（对齐 legado `SelectActionBar` 的核心语义）。
///
/// 目标：
/// - 显示“全选/取消全选（已选/总数）”；
/// - 支持反选；
/// - 支持清空（退出选择态）。
class RemoteBooksSelectActionBar extends StatelessWidget {
  const RemoteBooksSelectActionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.allSelected,
    this.mainActionText = '加入书架',
    this.mainActionBusy = false,
    this.onToggleSelectAll,
    this.onRevertSelection,
    this.onClearSelection,
    this.onMainAction,
  });

  /// 当前已选数量（仅统计可选文件项，不包含目录）。
  final int selectedCount;

  /// 当前目录下可选文件总数（不包含目录）。
  final int totalCount;

  /// 是否已全选（`selectedCount >= totalCount` 且 `totalCount > 0`）。
  final bool allSelected;

  /// 主动作按钮文本（默认“加入书架”）。
  final String mainActionText;

  /// 主动作是否正在执行（用于展示 loading 并禁用重复点击）。
  final bool mainActionBusy;

  /// 点击“全选/取消全选”。
  final VoidCallback? onToggleSelectAll;

  /// 点击“反选”。
  final VoidCallback? onRevertSelection;

  /// 点击“清空”（清空当前选择）。
  final VoidCallback? onClearSelection;

  /// 点击主动作（加入书架）。
  final VoidCallback? onMainAction;

  @override
  Widget build(BuildContext context) {
    final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    final canSelect = totalCount > 0;
    final hasSelection = selectedCount > 0;
    final canTriggerMainAction = hasSelection && !mainActionBusy;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          border: Border(
            top: BorderSide(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(30, 30),
                alignment: Alignment.centerLeft,
                onPressed: canSelect ? onToggleSelectAll : null,
                child: Text(
                  allSelected
                      ? '取消全选（$selectedCount/$totalCount）'
                      : '全选（$selectedCount/$totalCount）',
                  style: TextStyle(
                    fontSize: 13,
                    color: canSelect ? enabledColor : disabledColor,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: canSelect && hasSelection ? onRevertSelection : null,
              child: Text(
                '反选',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      canSelect && hasSelection ? enabledColor : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: hasSelection ? onClearSelection : null,
              child: Text(
                '清空',
                style: TextStyle(
                  fontSize: 13,
                  color: hasSelection ? enabledColor : disabledColor,
                ),
              ),
            ),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: canTriggerMainAction ? onMainAction : null,
              child: mainActionBusy
                  ? const CupertinoActivityIndicator(radius: 9)
                  : Text(
                      mainActionText,
                      style: const TextStyle(fontSize: 13),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
