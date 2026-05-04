import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/models/backup_restore_ignore_config.dart';
import '../../../core/services/webdav_service.dart';
import 'backup_settings_helpers.dart';

/// 弹出文本编辑对话框（WebDav URL/账号/密码/路径等）。
Future<void> showBackupFieldEditDialog({
  required BuildContext context,
  required String title,
  required String placeholder,
  required String initialValue,
  required Future<void> Function(String value) onSave,
  bool obscureText = false,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          maxLines: 1,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null) return;
  await onSave(result.trim());
  if (!context.mounted) return;
  unawaited(showAppToast(context, message: '已保存'));
}

/// 选择要恢复的 WebDav 备份文件。
Future<WebDavRemoteEntry?> showBackupFilePicker({
  required BuildContext context,
  required List<WebDavRemoteEntry> backups,
}) {
  return showCupertinoBottomSheetDialog<WebDavRemoteEntry>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('选择恢复文件'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in backups)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => Navigator.pop(dialogContext, entry),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displayName,
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        backupEntrySummary(entry),
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .tabLabelTextStyle
                            .copyWith(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey
                                  .resolveFrom(context),
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}

/// 编辑「恢复时忽略」选项集合。
Future<Set<String>?> showRestoreIgnoreDialog({
  required BuildContext context,
  required BackupRestoreIgnoreConfig current,
}) async {
  final selected = <String>{
    for (final option in BackupRestoreIgnoreConfig.options)
      if (current.isIgnored(option.key)) option.key,
  };
  return showCupertinoBottomSheetDialog<Set<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => CupertinoAlertDialog(
        title: const Text('恢复时忽略'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final option in BackupRestoreIgnoreConfig.options)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 34),
                    onPressed: () {
                      setDialogState(() {
                        if (!selected.add(option.key)) {
                          selected.remove(option.key);
                        }
                      });
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.title,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(fontSize: 16),
                          ),
                        ),
                        if (selected.contains(option.key))
                          const Icon(CupertinoIcons.check_mark, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.pop(dialogContext, Set<String>.from(selected)),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

/// 通用的提示对话框。
Future<void> showBackupMessageDialog(
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
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

/// WebDav 列表 / 下载 / 恢复出错时的回退询问框，返回是否选择「回退本地恢复」。
Future<bool> confirmWebDavRestoreFallback({
  required BuildContext context,
  required String errorMessage,
}) async {
  final shouldFallback = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('恢复'),
      content: Text('WebDavError\n$errorMessage\n将从本地备份恢复。'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('回退本地恢复'),
        ),
      ],
    ),
  );
  return shouldFallback == true;
}

/// 「确认覆盖导入」二次确认。
Future<bool> confirmBackupOverwriteImport(BuildContext context) async {
  final ok = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('确认覆盖导入？'),
      content: const Text('\n将清空当前书架、书源与缓存，再从备份恢复。此操作不可撤销。'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('继续'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// 「检测到较新的 WebDav 备份」恢复二次确认。
Future<bool> confirmRestoreDetectedBackup({
  required BuildContext context,
  required WebDavRemoteEntry entry,
}) async {
  final ok = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('恢复'),
      content: Text(
        '检测到 WebDav 备份比本地更新，是否恢复？\n'
        '${entry.displayName}\n'
        '${backupEntrySummary(entry)}',
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('恢复'),
        ),
      ],
    ),
  );
  return ok == true;
}
