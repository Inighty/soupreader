import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../services/reader_legacy_menu_helper.dart';

/// 当前菜单项的勾选状态（用于在标签前显示 ✓）。
class ReaderCatalogTocFlags {
  const ReaderCatalogTocFlags({
    required this.isReversed,
    required this.useReplace,
    required this.loadWordCount,
    required this.splitLongChapter,
  });

  final bool isReversed;
  final bool useReplace;
  final bool loadWordCount;
  final bool splitLongChapter;
}

String readerCatalogTocActionLabel(
  ReaderLegacyTocMenuAction action,
  ReaderCatalogTocFlags flags,
) {
  final raw = ReaderLegacyMenuHelper.tocMenuLabel(action);
  final checked = switch (action) {
    ReaderLegacyTocMenuAction.reverseToc => flags.isReversed,
    ReaderLegacyTocMenuAction.useReplace => flags.useReplace,
    ReaderLegacyTocMenuAction.loadWordCount => flags.loadWordCount,
    ReaderLegacyTocMenuAction.splitLongChapter => flags.splitLongChapter,
    _ => false,
  };
  return checked ? '✓ $raw' : raw;
}

/// 弹出目录抽屉的「更多操作」菜单。
///
/// [bookmarkTab] 决定是否显示「导出书签 / 导出 Markdown」之类仅书签 tab 才有意义的项；
/// [isLocalTxt] 决定是否显示 TXT 目录规则相关项。
Future<void> showReaderCatalogTocActionsMenu({
  required BuildContext context,
  required bool bookmarkTab,
  required bool isLocalTxt,
  required ReaderCatalogTocFlags flags,
  required Future<void> Function(ReaderLegacyTocMenuAction action) onAction,
}) {
  final actions = ReaderLegacyMenuHelper.buildTocMenuActions(
    bookmarkTab: bookmarkTab,
    isLocalTxt: isLocalTxt,
  );
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      title: const Text('目录操作'),
      actions: actions
          .map(
            (action) => CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await onAction(action);
              },
              child: Text(readerCatalogTocActionLabel(action, flags)),
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

/// 弹出「清理缓存」二次确认。
Future<bool> confirmReaderCatalogClearCache({
  required BuildContext context,
  required int cachedCount,
}) async {
  final ok = await showCupertinoBottomSheetDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('清理缓存'),
          content: Text('\n将清理本书已缓存的 $cachedCount 章内容（不删除目录）。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('清理'),
            ),
          ],
        ),
      ) ??
      false;
  return ok;
}

/// 把字节数格式化为人类友好的「KB/MB/GB」字符串。
String formatReaderCatalogBytes(int bytes) {
  if (bytes <= 0) return '0B';
  const k = 1024.0;
  final kb = bytes / k;
  if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)}MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)}GB';
}
