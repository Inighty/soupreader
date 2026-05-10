import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../services/reader_source_switch_helper.dart';

/// 候选行长按菜单的可选动作。
enum SourceSwitchCandidateAction {
  topSource,
  editSource,
  bottomSource,
  disableSource,
  deleteSource,
}

/// 「更多」菜单的可选动作。
enum SourceSwitchMenuAction {
  checkAuthor,
  loadInfo,
  loadWordCount,
  loadToc,
  changeSourceDelay,
}

/// 弹出候选行的长按菜单。
Future<SourceSwitchCandidateAction?> showSourceSwitchCandidateActions({
  required BuildContext context,
  required bool showTop,
  required bool showBottom,
  required bool showEdit,
  required bool showDisable,
  required bool showDelete,
}) {
  return showCupertinoBottomSheetDialog<SourceSwitchCandidateAction>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: [
        if (showTop)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchCandidateAction.topSource),
            child: const Text('置顶'),
          ),
        if (showBottom)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchCandidateAction.bottomSource),
            child: const Text('置底'),
          ),
        if (showEdit)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchCandidateAction.editSource),
            child: const Text('编辑源'),
          ),
        if (showDisable)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchCandidateAction.disableSource),
            child: const Text('禁用源'),
          ),
        if (showDelete)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchCandidateAction.deleteSource),
            child: const Text('删除源'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text('取消'),
      ),
    ),
  );
}

/// 「确认删除源」二次确认。
Future<bool> confirmSourceSwitchDelete({
  required BuildContext context,
  required ReaderSourceSwitchCandidate candidate,
}) async {
  final confirmed = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提醒'),
      content: Text('是否确认删除？\n${candidate.source.bookSourceName}'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 「确认切换到全部分组」二次确认。
Future<bool> confirmSourceSwitchGroupToAll({
  required BuildContext context,
  required String group,
}) async {
  final confirmed = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提醒'),
      content: Text('当前分组：$group\n切换到全部书源会清空筛选，是否继续？'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('继续'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 弹出「分组」选择面板，返回选中的 group；取消时返回 null。
Future<String?> showSourceSwitchGroupActions({
  required BuildContext context,
  required List<String> groups,
  required String selectedGroup,
}) {
  return showCupertinoBottomSheetDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('分组'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(''),
          child: Text(selectedGroup.isEmpty ? '✓ 全部书源' : '全部书源'),
        ),
        ...groups.map(
          (group) => CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(group),
            child: Text(selectedGroup == group ? '✓ $group' : group),
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text('取消'),
      ),
    ),
  );
}

/// 弹出「更多」操作菜单。
Future<SourceSwitchMenuAction?> showSourceSwitchMoreActions({
  required BuildContext context,
  required bool showCheckAuthor,
  required bool showLoadWordCount,
  required bool showLoadInfo,
  required bool showLoadToc,
  required bool showChangeSourceDelay,
  required bool checkAuthorEnabled,
  required bool loadWordCountEnabled,
  required bool loadInfoEnabled,
  required bool loadTocEnabled,
  required int changeSourceDelaySeconds,
}) {
  return showCupertinoBottomSheetDialog<SourceSwitchMenuAction>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: [
        if (showCheckAuthor)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchMenuAction.checkAuthor),
            child: Text(checkAuthorEnabled ? '✓ 校验作者' : '校验作者'),
          ),
        if (showLoadWordCount)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchMenuAction.loadWordCount),
            child: Text(loadWordCountEnabled ? '✓ 加载字数' : '加载字数'),
          ),
        if (showLoadInfo)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchMenuAction.loadInfo),
            child: Text(loadInfoEnabled ? '✓ 加载详情页' : '加载详情页'),
          ),
        if (showLoadToc)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchMenuAction.loadToc),
            child: Text(loadTocEnabled ? '✓ 加载目录' : '加载目录'),
          ),
        if (showChangeSourceDelay)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext)
                .pop(SourceSwitchMenuAction.changeSourceDelay),
            child: Text('换源间隔（${changeSourceDelaySeconds}秒）'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text('取消'),
      ),
    ),
  );
}

/// 「换源间隔」时长选择器。
Future<int?> showSourceSwitchDelayPicker({
  required BuildContext context,
  required int initialSeconds,
}) async {
  final initialValue = initialSeconds.clamp(0, 9999).toInt();
  final pickerController = FixedExtentScrollController(
    initialItem: initialValue,
  );
  var selectedValue = initialValue;
  final result = await showCupertinoBottomSheetDialog<int>(
    context: context,
    builder: (sheetContext) {
      final theme = CupertinoTheme.of(sheetContext);
      final backgroundColor = theme.scaffoldBackgroundColor;
      return Container(
        height: 320,
        color: backgroundColor,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('取消'),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          '换源间隔',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(selectedValue),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: CupertinoPicker.builder(
                  itemExtent: 36,
                  scrollController: pickerController,
                  onSelectedItemChanged: (index) => selectedValue = index,
                  childCount: 10000,
                  itemBuilder: (context, index) =>
                      Center(child: Text('$index 秒')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  pickerController.dispose();
  return result;
}
