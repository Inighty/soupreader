import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/book_source.dart';
import '../../source/views/list/source_list_view.dart';
import '../../settings/views/app_log_dialog.dart';
import '../models/search_scope.dart';
import 'search_scope_picker_view.dart';

/// 「搜索设置」菜单项。
enum SearchSettingAction {
  precisionSearch,
  sourceManage,
  scope,
  logs,
}

/// 弹出「搜索设置」action sheet 并返回选中项。
Future<SearchSettingAction?> showSearchSettingsSheet({
  required BuildContext context,
  required bool precisionSearchEnabled,
}) {
  return showAppActionListSheet<SearchSettingAction>(
    context: context,
    title: '搜索设置',
    message: '以下设置会自动保存',
    showCancel: true,
    items: [
      AppActionListItem<SearchSettingAction>(
        value: SearchSettingAction.precisionSearch,
        icon: precisionSearchEnabled
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.search,
        label: precisionSearchEnabled ? '✓ 精准搜索' : '精准搜索',
      ),
      const AppActionListItem<SearchSettingAction>(
        value: SearchSettingAction.sourceManage,
        icon: CupertinoIcons.book,
        label: '书源管理',
      ),
      const AppActionListItem<SearchSettingAction>(
        value: SearchSettingAction.scope,
        icon: CupertinoIcons.square_grid_2x2,
        label: '多分组/书源',
      ),
      const AppActionListItem<SearchSettingAction>(
        value: SearchSettingAction.logs,
        icon: CupertinoIcons.doc_text,
        label: '日志',
      ),
    ],
  );
}

/// 打开「搜索范围」选择页，返回归一化后的 scope 文本。
Future<String?> openSearchScopePicker({
  required BuildContext context,
  required List<BookSource> allSources,
  required List<BookSource> allEnabledSources,
}) async {
  final picked = await Navigator.of(context, rootNavigator: true).push<String>(
    CupertinoPageRoute(
      builder: (_) => SearchScopePickerView(
        sources: allSources,
        enabledSources: allEnabledSources,
      ),
    ),
  );
  if (picked == null) return null;
  return SearchScope.normalizeScopeText(picked);
}

/// 跳转到书源管理页面。
Future<void> openSourceManageView(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(builder: (_) => const SourceListView()),
  );
}

/// 打开应用日志查看对话框。
Future<void> openSearchAppLogDialog(BuildContext context) =>
    showAppLogDialog(context);

/// 通用「确认/取消」对话框。
Future<bool> confirmSearchAction({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmText,
  bool isDestructive = false,
}) async {
  final result = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(content),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: isDestructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 简单提示框（仅“好”按钮关闭）。
void showSearchMessage(BuildContext context, String message) {
  showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提示'),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

/// 把当次搜索失败的书源汇总成提示文本（截断至 12 条，余量提示省略）。
String formatSearchIssueDigest(List<({String sourceName, String reason})>
    issues) {
  if (issues.isEmpty) return '';
  final lines = <String>['失败书源：${issues.length} 条'];
  final preview = issues.take(12).toList(growable: false);
  for (final issue in preview) {
    lines.add('• ${issue.sourceName}：${issue.reason}');
  }
  final remain = issues.length - preview.length;
  if (remain > 0) lines.add('…其余 $remain 条省略');
  lines.add('可在“书源可用性检测”或“调试”继续定位。');
  return lines.join('\n');
}

/// 兼容旧 setting 字段范围切换（avoid unused import warning hint）。
SearchFilterMode togglePrecisionSearchMode(AppSettings settings) {
  final current = normalizeSearchFilterMode(settings.searchFilterMode);
  return current == SearchFilterMode.precise
      ? SearchFilterMode.normal
      : SearchFilterMode.precise;
}
