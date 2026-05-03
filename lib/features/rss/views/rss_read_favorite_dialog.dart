import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

/// 收藏对话框结果。
enum RssFavoriteDialogAction { cancel, confirm, delete }

/// 收藏对话框确认时返回的标题/分组。
class RssFavoriteDialogResult {
  final RssFavoriteDialogAction action;
  final String title;
  final String group;

  const RssFavoriteDialogResult({
    required this.action,
    required this.title,
    required this.group,
  });
}

/// 弹出"收藏设置"对话框（标题/分组编辑 + 删除/取消/确定）。
Future<RssFavoriteDialogResult> showRssFavoriteDialog({
  required BuildContext context,
  required String initialTitle,
  required String initialGroup,
}) async {
  final titleController = TextEditingController(text: initialTitle);
  final groupController = TextEditingController(text: initialGroup);
  try {
    final action = await showCupertinoBottomSheetDialog<RssFavoriteDialogAction>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('收藏设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: titleController,
              placeholder: '标题',
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: groupController,
              placeholder: '分组',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(RssFavoriteDialogAction.delete),
            child: const Text('删除收藏'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.of(dialogContext).pop(RssFavoriteDialogAction.cancel),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext)
                .pop(RssFavoriteDialogAction.confirm),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return RssFavoriteDialogResult(
      action: action ?? RssFavoriteDialogAction.cancel,
      title: titleController.text,
      group: groupController.text,
    );
  } finally {
    titleController.dispose();
    groupController.dispose();
  }
}
