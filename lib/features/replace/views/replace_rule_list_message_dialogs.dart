import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../settings/views/app_help_dialog.dart';

void showReplaceRuleMessage(BuildContext context, String message) {
  showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提示'),
      content: Text('\n$message'),
      actions: [
        CupertinoDialogAction(
          child: const Text('好'),
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ],
    ),
  );
}

Future<void> showReplaceRuleMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

Future<void> showReplaceRuleExportPathDialog({
  required BuildContext context,
  required String outputPath,
}) async {
  final path = outputPath.trim();
  if (path.isEmpty) return;
  final uri = Uri.tryParse(path);
  final isHttpPath = uri != null &&
      (uri.scheme.toLowerCase() == 'http' ||
          uri.scheme.toLowerCase() == 'https');
  final lines = <String>[
    '导出路径：',
    path,
    if (isHttpPath) '',
    if (isHttpPath) '检测到网络链接，可直接复制后分享。',
  ];
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('导出成功'),
      content: Text('\n${lines.join('\n')}'),
      actions: [
        CupertinoDialogAction(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: path));
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
          },
          child: const Text('复制路径'),
        ),
      ],
    ),
  );
}

Future<void> showReplaceRuleHelp(BuildContext context) async {
  try {
    final markdownText =
        await rootBundle.loadString('assets/web/help/md/replaceRuleHelp.md');
    if (!context.mounted) return;
    await showAppHelpDialog(context, markdownText: markdownText);
  } catch (error) {
    if (!context.mounted) return;
    showReplaceRuleMessage(context, '帮助文档加载失败：$error');
  }
}
