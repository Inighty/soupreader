import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_popover_menu.dart';

enum DictRuleMenuAction {
  importLocal,
  importOnline,
  importQr,
  importDefault,
  help,
}

enum DictRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  exportSelection,
}

Future<DictRuleMenuAction?> showDictRuleMoreMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  return showAppPopoverMenu<DictRuleMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: const [
      AppPopoverMenuItem(
        value: DictRuleMenuAction.importLocal,
        icon: CupertinoIcons.doc,
        label: '本地导入',
      ),
      AppPopoverMenuItem(
        value: DictRuleMenuAction.importOnline,
        icon: CupertinoIcons.globe,
        label: '网络导入',
      ),
      AppPopoverMenuItem(
        value: DictRuleMenuAction.importQr,
        icon: CupertinoIcons.qrcode,
        label: '二维码导入',
      ),
      AppPopoverMenuItem(
        value: DictRuleMenuAction.importDefault,
        icon: CupertinoIcons.wand_rays,
        label: '导入默认规则',
      ),
      AppPopoverMenuItem(
        value: DictRuleMenuAction.help,
        icon: CupertinoIcons.question_circle,
        label: '帮助',
      ),
    ],
  );
}

Future<DictRuleSelectionMenuAction?> showDictRuleSelectionMoreMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  return showAppPopoverMenu<DictRuleSelectionMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: const [
      AppPopoverMenuItem(
        value: DictRuleSelectionMenuAction.enableSelection,
        icon: CupertinoIcons.check_mark,
        label: '启用所选',
      ),
      AppPopoverMenuItem(
        value: DictRuleSelectionMenuAction.disableSelection,
        icon: CupertinoIcons.xmark,
        label: '禁用所选',
      ),
      AppPopoverMenuItem(
        value: DictRuleSelectionMenuAction.exportSelection,
        icon: CupertinoIcons.square_arrow_up,
        label: '导出所选',
      ),
    ],
  );
}
