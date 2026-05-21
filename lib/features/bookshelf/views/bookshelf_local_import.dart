// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfLocalImport on BookshelfViewState {
  // --- from bookshelf_view_import.dart ---
  Future<void> importLocalBook() async {
    if (isImporting || isScanningImportFolder) return;

    setState(() => isImporting = true);

    try {
      final result = await importService.importLocalBook();

      if (result.success && result.book != null) {
        loadBooks();
        if (mounted) {
          showMessage('导入成功：${result.book!.title}\n共 ${result.chapterCount} 章');
        }
      } else if (!result.cancelled && result.errorMessage != null) {
        if (mounted) {
          showMessage('导入失败：${result.errorMessage}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => isImporting = false);
      }
    }
  }

  Future<void> selectImportFolder() async {
    if (isImporting || isSelectingImportFolder || isScanningImportFolder) {
      return;
    }

    final action = await showCupertinoBottomSheetDialog<ImportFolderAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('选择文件夹'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(sheetContext, ImportFolderAction.select),
            child: const Text('选择文件夹'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(sheetContext, ImportFolderAction.create),
            child: const Text('创建文件夹'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == ImportFolderAction.select) {
      setState(() => isSelectingImportFolder = true);
      try {
        final result = await importService.selectImportDirectory();
        if (!mounted) return;
        if (result.success && result.directoryPath != null) {
          unawaited(
              showAppToast(context, message: '已选择文件夹：${result.directoryPath}'));
          return;
        }
        if (!result.cancelled && result.errorMessage != null) {
          showMessage('选择文件夹失败：${result.errorMessage}');
        }
      } finally {
        if (mounted) {
          setState(() => isSelectingImportFolder = false);
        }
      }
      return;
    }

    setState(() => isSelectingImportFolder = true);
    String? parentDirectoryPath;
    try {
      parentDirectoryPath = importService.getSavedImportDirectory();
      if (parentDirectoryPath == null || parentDirectoryPath.trim().isEmpty) {
        final parentResult = await importService.selectImportDirectory();
        if (!mounted) return;
        if (parentResult.success && parentResult.directoryPath != null) {
          parentDirectoryPath = parentResult.directoryPath!;
        } else {
          if (!parentResult.cancelled && parentResult.errorMessage != null) {
            showMessage('选择文件夹失败：${parentResult.errorMessage}');
          }
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() => isSelectingImportFolder = false);
      }
    }
    if (!mounted) return;

    final folderName = await showCreateFolderNameDialog();
    if (!mounted || folderName == null) return;

    setState(() => isSelectingImportFolder = true);
    try {
      final result = await importService.createImportDirectory(
        parentDirectoryPath: parentDirectoryPath,
        folderName: folderName,
      );
      if (!mounted) return;
      if (result.success && result.directoryPath != null) {
        unawaited(
            showAppToast(context, message: '已选择文件夹：${result.directoryPath}'));
      } else if (result.errorMessage != null &&
          result.errorMessage!.isNotEmpty) {
        showMessage('创建文件夹失败：${result.errorMessage}');
      }
    } finally {
      if (mounted) {
        setState(() => isSelectingImportFolder = false);
      }
    }
  }

  Future<String?> showCreateFolderNameDialog() async {
    final controller = TextEditingController();
    String? name;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('创建文件夹'),
              content: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoTextField(
                      controller: controller,
                      placeholder: '文件夹名',
                    ),
                    if (errorText != null && errorText!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: CupertinoColors.systemRed.resolveFrom(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        errorText = '文件夹名不能为空';
                      });
                      return;
                    }
                    name = value;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return name;
  }

  Future<void> showImportFileNameRuleDialog() async {
    final controller = TextEditingController(
      text: bookImportFileNameRuleService.getRule(),
    );
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('导入文件名'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '使用js处理文件名变量src，将书名作者分别赋值到变量name author',
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: controller,
                  placeholder: 'js',
                  maxLines: 5,
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
              isDefaultAction: true,
              onPressed: () async {
                final rule = controller.text;
                Navigator.pop(dialogContext);
                await bookImportFileNameRuleService.saveRule(rule);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }
}
