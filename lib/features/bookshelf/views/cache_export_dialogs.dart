import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'cache_export_helpers.dart';

/// 当前导出菜单的勾选状态（用于在 ActionSheet 文案前显示 ✓）。
class CacheExportToggleFlags {
  const CacheExportToggleFlags({
    required this.exportUseReplace,
    required this.enableCustomExport,
    required this.exportToWebDav,
    required this.exportNoChapterName,
    required this.exportPictureFile,
    required this.parallelExportBook,
  });

  final bool exportUseReplace;
  final bool enableCustomExport;
  final bool exportToWebDav;
  final bool exportNoChapterName;
  final bool exportPictureFile;
  final bool parallelExportBook;
}

/// 「更多」菜单回调集合。
class CacheExportMoreCallbacks {
  const CacheExportMoreCallbacks({
    required this.onExportAll,
    required this.onToggleUseReplace,
    required this.onToggleCustomExport,
    required this.onToggleExportToWebDav,
    required this.onToggleNoChapterName,
    required this.onToggleExportPicture,
    required this.onToggleParallel,
    required this.onPickFolder,
    required this.onPickFileName,
    required this.onPickType,
    required this.onPickCharset,
  });

  final VoidCallback onExportAll;
  final VoidCallback onToggleUseReplace;
  final VoidCallback onToggleCustomExport;
  final VoidCallback onToggleExportToWebDav;
  final VoidCallback onToggleNoChapterName;
  final VoidCallback onToggleExportPicture;
  final VoidCallback onToggleParallel;
  final VoidCallback onPickFolder;
  final VoidCallback onPickFileName;
  final VoidCallback onPickType;
  final VoidCallback onPickCharset;
}

CupertinoActionSheetAction _toggleAction({
  required BuildContext sheetContext,
  required bool checked,
  required String label,
  required VoidCallback onTap,
}) {
  return CupertinoActionSheetAction(
    onPressed: () {
      Navigator.pop(sheetContext);
      onTap();
    },
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checked)
          const Icon(CupertinoIcons.check_mark, size: 16)
        else
          const SizedBox(width: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    ),
  );
}

/// 弹出「更多」操作面板（含导出全部、各类开关、导出文件夹/文件名/格式/编码入口）。
Future<void> showCacheExportMoreSheet({
  required BuildContext context,
  required CacheExportToggleFlags flags,
  required String currentExportTypeName,
  required String currentExportCharset,
  required CacheExportMoreCallbacks callbacks,
}) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) {
      return CupertinoActionSheet(
        title: const Text('更多'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              callbacks.onExportAll();
            },
            child: const Text('导出所有'),
          ),
          _toggleAction(
            sheetContext: sheetContext,
            checked: flags.exportUseReplace,
            label: '替换净化',
            onTap: callbacks.onToggleUseReplace,
          ),
          _toggleAction(
            sheetContext: sheetContext,
            checked: flags.enableCustomExport,
            label: '自定义Epub导出章节',
            onTap: callbacks.onToggleCustomExport,
          ),
          _toggleAction(
            sheetContext: sheetContext,
            checked: flags.exportToWebDav,
            label: '导出到 WebDav',
            onTap: callbacks.onToggleExportToWebDav,
          ),
          _toggleAction(
            sheetContext: sheetContext,
            checked: flags.exportNoChapterName,
            label: 'TXT 不导出章节名',
            onTap: callbacks.onToggleNoChapterName,
          ),
          _toggleAction(
            sheetContext: sheetContext,
            checked: flags.exportPictureFile,
            label: 'TXT 导出图片',
            onTap: callbacks.onToggleExportPicture,
          ),
          _toggleAction(
            sheetContext: sheetContext,
            checked: flags.parallelExportBook,
            label: '多线程导出',
            onTap: callbacks.onToggleParallel,
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              callbacks.onPickFolder();
            },
            child: const Text('导出文件夹'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              callbacks.onPickFileName();
            },
            child: const Text('导出文件名'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              callbacks.onPickType();
            },
            child: Text('导出格式($currentExportTypeName)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              callbacks.onPickCharset();
            },
            child: Text('导出编码($currentExportCharset)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      );
    },
  );
}

/// 弹出「分组」选择面板，返回选中的 group id；取消时返回 null。
Future<int?> showCacheExportBookGroupSheet({
  required BuildContext context,
  required int selectedGroupId,
}) {
  final options = cacheLegacyBookGroups.toList(growable: false)
    ..sort((a, b) => a.order.compareTo(b.order));
  return showCupertinoBottomSheetDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('分组'),
      actions: options
          .map(
            (option) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, option.id),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedGroupId == option.id)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  Text(option.title),
                ],
              ),
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

/// 弹出「下载之后/全部章节」长按菜单。
Future<void> showCacheDownloadActionLongPressSheet({
  required BuildContext context,
  required Future<void> Function() onDownloadAfter,
  required Future<void> Function() onDownloadAll,
}) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(sheetContext);
            await onDownloadAfter();
          },
          child: const Text('下载之后章节'),
        ),
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(sheetContext);
            await onDownloadAll();
          },
          child: const Text('下载全部章节'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('取消'),
      ),
    ),
  );
}

/// 「确认开始缓存」弹窗，true 表示用户点了确定。
Future<bool> confirmCacheStartDownload(BuildContext context) async {
  final result = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提醒'),
      content: const Text('是否确认缓存当前列表书籍？'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return result == true;
}

/// 通用提示对话框。
Future<void> showCacheExportMessage(
  BuildContext context,
  String message,
) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

/// 「导出文件名」编辑对话框，返回用户输入；取消时返回 null。
Future<String?> showCacheExportFileNameDialog({
  required BuildContext context,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    final shouldSave = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出文件名'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Variable: name, author.'),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              placeholder: 'file name js',
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (shouldSave != true) return null;
    return controller.text;
  } finally {
    controller.dispose();
  }
}

/// 「导出格式」选择面板，返回选中的索引；取消/未变更时返回 null。
Future<int?> showCacheExportTypeSheet({
  required BuildContext context,
  required List<String> options,
  required int currentIndex,
}) {
  return showCupertinoBottomSheetDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('导出格式'),
      actions: List<Widget>.generate(options.length, (index) {
        final option = options[index];
        return CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, index),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentIndex == index)
                const Icon(CupertinoIcons.check_mark, size: 16)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 6),
              Text(option),
            ],
          ),
        );
      }),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('取消'),
      ),
    ),
  );
}

/// 「设置编码」对话框（带「常用编码列表」副本）。
Future<String?> showCacheExportCharsetDialog({
  required BuildContext context,
  required String initialValue,
  required List<String> legacyOptions,
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置编码'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: controller,
                placeholder: 'charset name',
              ),
              const SizedBox(height: 10),
              Text(
                legacyOptions.join(' / '),
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel
                      .resolveFrom(dialogContext),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
