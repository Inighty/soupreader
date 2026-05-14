import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/rss_source.dart';
import '../services/rss_source_import_export_service.dart';
import '../services/rss_source_manage_helper.dart';
import 'rss_source_manage_types.dart';

Future<RssSourceSelectionAction?> showRssSelectionMoreActions(
  BuildContext context,
) {
  return showAppActionListSheet<RssSourceSelectionAction>(
    context: context,
    title: '批量操作',
    showCancel: true,
    items: const [
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.enableSelection,
        icon: CupertinoIcons.check_mark_circled_solid,
        label: '启用所选',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.disableSelection,
        icon: CupertinoIcons.clear_circled_solid,
        label: '禁用所选',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.addGroup,
        icon: CupertinoIcons.add_circled_solid,
        label: '添加分组',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.removeGroup,
        icon: CupertinoIcons.minus_circle,
        label: '移除分组',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.moveToTop,
        icon: CupertinoIcons.arrow_up_circle,
        label: '置顶所选',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.moveToBottom,
        icon: CupertinoIcons.arrow_down_circle,
        label: '置底所选',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.exportSelection,
        icon: CupertinoIcons.square_arrow_up,
        label: '导出所选',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.shareSelection,
        icon: CupertinoIcons.share,
        label: '分享选中源',
      ),
      AppActionListItem<RssSourceSelectionAction>(
        value: RssSourceSelectionAction.checkSelectedInterval,
        icon: CupertinoIcons.scope,
        label: '选中所选区间',
      ),
    ],
  );
}

Future<RssSourceItemAction?> showRssSourceItemActions({
  required BuildContext context,
  required RssSource source,
}) {
  return showAppActionListSheet<RssSourceItemAction>(
    context: context,
    title: source.sourceName,
    showCancel: true,
    items: const [
      AppActionListItem<RssSourceItemAction>(
        value: RssSourceItemAction.moveToTop,
        icon: CupertinoIcons.arrow_up_circle,
        label: '置顶',
      ),
      AppActionListItem<RssSourceItemAction>(
        value: RssSourceItemAction.moveToBottom,
        icon: CupertinoIcons.arrow_down_circle,
        label: '置底',
      ),
      AppActionListItem<RssSourceItemAction>(
        value: RssSourceItemAction.delete,
        icon: CupertinoIcons.delete,
        label: '删除',
        isDestructiveAction: true,
      ),
    ],
  );
}

/// 弹出「分组输入」对话框，含已有分组的 quick chips。
Future<String?> showRssSelectionGroupInputDialog({
  required BuildContext context,
  required String title,
  required List<String> allGroups,
}) async {
  final controller = TextEditingController();
  try {
    return await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final query = controller.text.trim().toLowerCase();
          final quickGroups = allGroups
              .where((group) =>
                  query.isEmpty || group.toLowerCase().contains(query))
              .take(12)
              .toList(growable: false);
          return CupertinoAlertDialog(
            title: Text(title),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoTextField(
                    controller: controller,
                    placeholder: '分组名称',
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (quickGroups.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: math.min(quickGroups.length * 34.0, 118),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: quickGroups
                                .map((group) => CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 26),
                                      onPressed: () {
                                        controller.value = TextEditingValue(
                                          text: group,
                                          selection: TextSelection.collapsed(
                                            offset: group.length,
                                          ),
                                        );
                                        setDialogState(() {});
                                      },
                                      child: Text(
                                        group,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ))
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// 简单提示框（仅“好”按钮）。
Future<void> showRssMessage(BuildContext context, String message) async {
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('提示'),
      content: Text('\n$message'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

/// 删除确认。
Future<bool> confirmRssSourceDelete({
  required BuildContext context,
  required RssSource source,
}) async {
  final confirmed = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('提醒'),
      content: Text('确定删除\n${source.sourceName}'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 导出路径展示对话框（路径 + 复制按钮）。
Future<void> showRssExportPathDialog({
  required BuildContext context,
  required String outputPath,
}) async {
  final path = outputPath.trim();
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
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
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

/// 导入失败原因合并展示。
String formatRssImportError(RssSourceImportResult result) {
  final lines = <String>[result.errorMessage ?? '导入失败'];
  if (result.totalInputCount > 0) {
    lines.add('输入条数：${result.totalInputCount}');
    if (result.invalidCount > 0) lines.add('无效条数：${result.invalidCount}');
    if (result.duplicateCount > 0) {
      lines.add('重复URL：${result.duplicateCount}（后项覆盖）');
    }
  }
  if (result.warnings.isNotEmpty) {
    lines.add('详情：');
    lines.addAll(result.warnings.take(5));
    final more = result.warnings.length - 5;
    if (more > 0) lines.add('…其余 $more 条省略');
  }
  return lines.join('\n');
}

/// 「网络导入」输入面板：URL 输入 + 历史记录列表。

/// 顶部「分组」popover 菜单。
Future<RssGroupMenuDecision?> showRssGroupMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<String> groups,
}) {
  return showAppPopoverMenu<RssGroupMenuDecision>(
    context: context,
    anchorKey: anchorKey,
    items: [
      const AppPopoverMenuItem(
        value: (openManage: true, query: null),
        icon: CupertinoIcons.gear,
        label: '分组管理',
      ),
      const AppPopoverMenuItem(
        value: (openManage: false, query: '已启用'),
        icon: CupertinoIcons.check_mark,
        label: '已启用',
      ),
      const AppPopoverMenuItem(
        value: (openManage: false, query: '已禁用'),
        icon: CupertinoIcons.xmark,
        label: '已禁用',
      ),
      const AppPopoverMenuItem(
        value: (openManage: false, query: '需要登录'),
        icon: CupertinoIcons.lock,
        label: '需要登录',
      ),
      const AppPopoverMenuItem(
        value: (openManage: false, query: '未分组'),
        icon: CupertinoIcons.tray,
        label: '未分组',
      ),
      for (final group in groups)
        AppPopoverMenuItem(
          value: (
            openManage: false,
            query: '${RssSourceManageHelper.groupPrefix}$group',
          ),
          icon: CupertinoIcons.folder,
          label: group,
        ),
    ],
  );
}

/// 顶部「主菜单」popover 菜单（新建 / 各种导入）。
Future<RssSourceMainMenuAction?> showRssMainMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
}) {
  return showAppPopoverMenu<RssSourceMainMenuAction>(
    context: context,
    anchorKey: anchorKey,
    items: const [
      AppPopoverMenuItem(
        value: RssSourceMainMenuAction.create,
        icon: CupertinoIcons.add_circled,
        label: '新建订阅源',
      ),
      AppPopoverMenuItem(
        value: RssSourceMainMenuAction.importFile,
        icon: CupertinoIcons.doc,
        label: '本地导入',
      ),
      AppPopoverMenuItem(
        value: RssSourceMainMenuAction.importUrl,
        icon: CupertinoIcons.globe,
        label: '网络导入',
      ),
      AppPopoverMenuItem(
        value: RssSourceMainMenuAction.importQr,
        icon: CupertinoIcons.qrcode,
        label: '二维码导入',
      ),
      AppPopoverMenuItem(
        value: RssSourceMainMenuAction.importDefault,
        icon: CupertinoIcons.wand_rays,
        label: '导入默认规则',
      ),
    ],
  );
}

/// 显示「分组输入」对话框，归一化空 / null 输入为 null（取消）。
Future<String?> promptRssGroupInput({
  required BuildContext context,
  required String title,
  required List<String> allGroups,
}) async {
  final raw = await showRssSelectionGroupInputDialog(
    context: context,
    title: title,
    allGroups: allGroups,
  );
  if (raw == null) return null;
  return raw.isEmpty ? null : raw;
}
