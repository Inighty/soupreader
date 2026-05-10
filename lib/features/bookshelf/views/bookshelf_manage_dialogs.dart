import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/bookshelf_book_group.dart';

/// 选择「分组」面板的输出。
class BookshelfManageGroupSheetResult {
  final bool openGroupManage;
  final int? selectedGroupId;

  const BookshelfManageGroupSheetResult({
    required this.openGroupManage,
    required this.selectedGroupId,
  });
}

/// 弹出「分组」选择面板，附带「分组管理」入口。
Future<BookshelfManageGroupSheetResult> showBookshelfManageGroupMenu({
  required BuildContext context,
  required List<BookshelfBookGroup> groups,
  required int currentGroupId,
}) async {
  var openGroupManage = false;
  int? selectedGroupId;
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (popupContext) {
      return CupertinoActionSheet(
        title: const Text('分组'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              openGroupManage = true;
              Navigator.of(popupContext).pop();
            },
            child: const Text('分组管理'),
          ),
          ...groups.map(
            (group) => CupertinoActionSheetAction(
              onPressed: () {
                selectedGroupId = group.groupId;
                Navigator.of(popupContext).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentGroupId == group.groupId)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  Text(group.groupName),
                ],
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('取消'),
        ),
      );
    },
  );
  return BookshelfManageGroupSheetResult(
    openGroupManage: openGroupManage,
    selectedGroupId: selectedGroupId,
  );
}

/// 弹出「更多」操作面板（点击书名打开详情 + 导出所有书的书源）。
Future<void> showBookshelfManageMoreMenu({
  required BuildContext context,
  required bool openBookInfoByClickTitle,
  required VoidCallback onToggleOpenBookInfoByClickTitle,
  required VoidCallback onExportAllUsedBookSources,
}) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (popupContext) {
      return CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(popupContext).pop();
              onToggleOpenBookInfoByClickTitle();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (openBookInfoByClickTitle)
                  const Icon(CupertinoIcons.check_mark, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 6),
                const Text('点击书名打开详情'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(popupContext).pop();
              onExportAllUsedBookSources();
            },
            child: const Text('导出所有书的书源'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('取消'),
        ),
      );
    },
  );
}

/// 「确认删除选中的书」对话框，返回 (是否删除原文件)；取消返回 null。
Future<bool?> confirmBookshelfManageDeleteSelection({
  required BuildContext context,
  required bool initialDeleteOriginal,
}) async {
  var deleteOriginal = initialDeleteOriginal;
  final confirmed = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (innerContext, setDialogState) {
          return CupertinoAlertDialog(
            title: const Text('提醒'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('是否确认删除？'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '删除源文件',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      CupertinoSwitch(
                        value: deleteOriginal,
                        onChanged: (value) {
                          setDialogState(() => deleteOriginal = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          );
        },
      );
    },
  );
  if (confirmed != true) return null;
  return deleteOriginal;
}

/// 通用提示对话框。
Future<void> showBookshelfManageMessage(
  BuildContext context,
  String message,
) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提示'),
      content: Text('\n$message'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

/// 「导出成功」展示路径并支持复制。
Future<void> showBookshelfManageExportPathDialog({
  required BuildContext context,
  required String outputPath,
  required void Function(String message) onToast,
}) async {
  final path = outputPath.trim();
  if (path.isEmpty) {
    onToast('导出成功');
    return;
  }
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('导出成功'),
      content: Text('\n导出路径：\n$path'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
        CupertinoDialogAction(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: path));
            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            onToast('已复制导出路径');
          },
          child: const Text('复制路径'),
        ),
      ],
    ),
  );
}
