import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../models/replace_rule.dart';
import 'replace_rule_import_types.dart';
import 'replace_rule_list_view.dart' show ReplaceRuleTopMenuAction;

Future<ReplaceRuleTopMenuAction?> showReplaceRuleTopMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  return showAppPopoverMenu<ReplaceRuleTopMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: const [
      AppPopoverMenuItem(
        value: ReplaceRuleTopMenuAction.create,
        icon: CupertinoIcons.add_circled,
        label: '新建替换',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleTopMenuAction.importFile,
        icon: CupertinoIcons.doc,
        label: '本地导入',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleTopMenuAction.importUrl,
        icon: CupertinoIcons.globe,
        label: '网络导入',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleTopMenuAction.importQr,
        icon: CupertinoIcons.qrcode,
        label: '二维码导入',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleTopMenuAction.help,
        icon: CupertinoIcons.question_circle,
        label: '帮助',
      ),
    ],
  );
}

Future<ReplaceRuleItemMenuAction?> showReplaceRuleItemMenu({
  required BuildContext context,
  required ReplaceRule rule,
}) {
  return showAppActionListSheet<ReplaceRuleItemMenuAction>(
    context: context,
    title: rule.name.isEmpty ? '未命名规则' : rule.name,
    showCancel: true,
    items: const [
      AppActionListItem<ReplaceRuleItemMenuAction>(
        value: ReplaceRuleItemMenuAction.top,
        icon: CupertinoIcons.arrow_up_circle,
        label: '置顶',
      ),
      AppActionListItem<ReplaceRuleItemMenuAction>(
        value: ReplaceRuleItemMenuAction.bottom,
        icon: CupertinoIcons.arrow_down_circle,
        label: '置底',
      ),
      AppActionListItem<ReplaceRuleItemMenuAction>(
        value: ReplaceRuleItemMenuAction.delete,
        icon: CupertinoIcons.delete,
        label: '删除',
        isDestructiveAction: true,
      ),
    ],
  );
}

Future<ReplaceRuleSelectionMenuAction?> showReplaceRuleSelectionPopoverMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  return showAppPopoverMenu<ReplaceRuleSelectionMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: const [
      AppPopoverMenuItem(
        value: ReplaceRuleSelectionMenuAction.enableSelection,
        icon: CupertinoIcons.check_mark,
        label: '启用所选',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleSelectionMenuAction.disableSelection,
        icon: CupertinoIcons.xmark,
        label: '禁用所选',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleSelectionMenuAction.topSelection,
        icon: CupertinoIcons.arrow_up_to_line,
        label: '置顶所选',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleSelectionMenuAction.bottomSelection,
        icon: CupertinoIcons.arrow_down_to_line,
        label: '置底所选',
      ),
      AppPopoverMenuItem(
        value: ReplaceRuleSelectionMenuAction.exportSelection,
        icon: CupertinoIcons.square_arrow_up,
        label: '导出所选',
      ),
    ],
  );
}
