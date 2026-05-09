import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

enum TxtTocRuleMenuAction {
  importDefault,
  importLocal,
  importOnline,
  importQr,
  help,
}

enum TxtTocRuleItemMenuAction {
  top,
  bottom,
  delete,
}

enum TxtTocRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  exportSelection,
}

Future<TxtTocRuleMenuAction?> showTxtTocRuleMoreMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  return showAppPopoverMenu<TxtTocRuleMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: const [
      AppPopoverMenuItem(
        value: TxtTocRuleMenuAction.importLocal,
        icon: CupertinoIcons.doc,
        label: '本地导入',
      ),
      AppPopoverMenuItem(
        value: TxtTocRuleMenuAction.importOnline,
        icon: CupertinoIcons.globe,
        label: '网络导入',
      ),
      AppPopoverMenuItem(
        value: TxtTocRuleMenuAction.importQr,
        icon: CupertinoIcons.qrcode,
        label: '二维码导入',
      ),
      AppPopoverMenuItem(
        value: TxtTocRuleMenuAction.importDefault,
        icon: CupertinoIcons.wand_rays,
        label: '导入默认规则',
      ),
      AppPopoverMenuItem(
        value: TxtTocRuleMenuAction.help,
        icon: CupertinoIcons.question_circle,
        label: '帮助',
      ),
    ],
  );
}

Future<TxtTocRuleSelectionMenuAction?> showTxtTocRuleSelectionMoreMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  return showAppPopoverMenu<TxtTocRuleSelectionMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: const [
      AppPopoverMenuItem(
        value: TxtTocRuleSelectionMenuAction.enableSelection,
        icon: CupertinoIcons.check_mark,
        label: '启用所选',
      ),
      AppPopoverMenuItem(
        value: TxtTocRuleSelectionMenuAction.disableSelection,
        icon: CupertinoIcons.xmark,
        label: '禁用所选',
      ),
      AppPopoverMenuItem(
        value: TxtTocRuleSelectionMenuAction.exportSelection,
        icon: CupertinoIcons.square_arrow_up,
        label: '导出所选',
      ),
    ],
  );
}

Future<TxtTocRuleItemMenuAction?> showTxtTocRuleItemActionSheet({
  required BuildContext context,
  required String ruleName,
}) {
  return showCupertinoBottomSheetDialog<TxtTocRuleItemMenuAction>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => CupertinoActionSheet(
      title: Text(ruleName.trim().isEmpty ? '未命名规则' : ruleName.trim()),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.pop(sheetContext, TxtTocRuleItemMenuAction.top),
          child: const Text('置顶'),
        ),
        CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.pop(sheetContext, TxtTocRuleItemMenuAction.bottom),
          child: const Text('置底'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () =>
              Navigator.pop(sheetContext, TxtTocRuleItemMenuAction.delete),
          child: const Text('删除'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const Text('取消'),
      ),
    ),
  );
}
