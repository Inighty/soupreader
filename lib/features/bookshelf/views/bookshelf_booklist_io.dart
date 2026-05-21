// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../services/bookshelf_booklist_import_service.dart';
import '../services/bookshelf_import_export_service.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfBooklistIo on BookshelfViewState {
  Future<void> exportBookshelf() async {
    final result = await bookshelfIo.exportToFile(books);
    if (!result.success) {
      if (result.cancelled) return;
      showMessage(result.errorMessage ?? '导出书籍出错');
      return;
    }
    final hint = result.outputPathOrHint;
    if (hint == null || hint.isEmpty) {
      unawaited(showAppToast(context, message: '导出成功'));
      return;
    }
    showExportSuccessDialog(hint);
  }

  void showExportSuccessDialog(String pathOrHint) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(pathOrHint),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pathOrHint));
              if (!mounted) return;
              Navigator.pop(dialogContext);
              unawaited(showAppToast(context, message: '已复制到剪贴板'));
            },
            child: const Text('复制'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> showImportBookshelfDialog() async {
    final controller = TextEditingController();
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('导入书单'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'url/json',
              autofocus: true,
              maxLines: 4,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(importBookshelfFromFile());
              },
              child: const Text('选择文件'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final rawInput = controller.text;
                Navigator.pop(dialogContext);
                unawaited(importBookshelfFromInput(rawInput));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> importBookshelfFromInput(String rawInput) async {
    if (isImporting) return;
    setState(() => isImporting = true);

    final parseResult = await bookshelfIo.importFromInput(rawInput);
    await startBooklistImport(parseResult);
  }

  Future<void> importBookshelfFromFile() async {
    if (isImporting) return;
    setState(() => isImporting = true);

    final parseResult = await bookshelfIo.importFromFile();
    await startBooklistImport(parseResult);
  }

  Future<void> startBooklistImport(
    BookshelfImportParseResult parseResult,
  ) async {
    if (!parseResult.success) {
      if (mounted) setState(() => isImporting = false);
      if (parseResult.cancelled) return;
      showMessage(parseResult.errorMessage ?? '导入失败');
      return;
    }

    final progress = ValueNotifier<BooklistImportProgress>(
      BooklistImportProgress(
        done: 0,
        total: parseResult.items.length,
        currentName: '',
        currentSource: '',
      ),
    );

    if (!mounted) return;
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('正在导入书单'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ValueListenableBuilder<BooklistImportProgress>(
            valueListenable: progress,
            builder: (context, p, _) {
              final name = p.currentName.isEmpty ? '—' : p.currentName;
              final src = p.currentSource.isEmpty ? '—' : p.currentSource;
              return Column(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 10),
                  Text('进度：${p.done}/${p.total}'),
                  const SizedBox(height: 6),
                  Text('当前：$name'),
                  const SizedBox(height: 6),
                  Text('书源：$src'),
                ],
              );
            },
          ),
        ),
      ),
    );

    final summary = await booklistImporter.importBySearching(
      parseResult.items,
      onProgress: (p) => progress.value = p,
    );

    if (mounted) {
      Navigator.pop(context);
      setState(() => isImporting = false);
      loadBooks();

      final details = summary.errors.isEmpty
          ? ''
          : '\n\n失败详情（最多 5 条）：\n${summary.errors.take(5).join('\n')}';
      showMessage('${summary.summaryText}$details');
    }
    progress.dispose();
  }
}
