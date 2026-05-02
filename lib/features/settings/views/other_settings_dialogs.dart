import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../services/other_source_settings_service.dart';

/// 通用：弹出"输入限定区间整数"的弹框；解析失败/越界时弹错误提示。
Future<void> showOtherSettingsBoundedIntDialog({
  required BuildContext context,
  required String title,
  required int currentValue,
  required int min,
  required int max,
  required String placeholder,
  required Future<void> Function(int value) save,
  required void Function(String message) onValidationFail,
}) async {
  final controller = TextEditingController(text: currentValue.toString());
  final value = await showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          placeholder: placeholder,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value == null) return;

  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < min || parsed > max) {
    onValidationFail('$title 需要在 $min 到 $max 之间');
    return;
  }
  await save(parsed);
}

/// 编辑用户代理（多行）。
Future<void> showOtherSettingsUserAgentDialog({
  required BuildContext context,
  required OtherSourceSettingsService service,
  required Future<void> Function() onSaved,
}) async {
  final controller = TextEditingController(text: service.getUserAgent());
  final value = await showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('用户代理'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          placeholder: '用户代理',
          maxLines: 5,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value == null) return;
  await service.saveUserAgent(value);
  await onSaved();
}

/// 编辑源编辑框最大行数。
Future<void> showOtherSettingsSourceEditMaxLineDialog({
  required BuildContext context,
  required OtherSourceSettingsService service,
  required void Function(String message) onValidationFail,
  required Future<void> Function() onSaved,
}) async {
  final controller = TextEditingController(
    text: service.getSourceEditMaxLine().toString(),
  );
  final value = await showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('源编辑框最大行数'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          placeholder: '请输入大于等于 10 的整数',
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value == null) return;
  final parsed = int.tryParse(value.trim()) ?? 0;
  if (parsed < OtherSourceSettingsService.minSourceEditMaxLine) {
    onValidationFail('源编辑框最大行数不能小于 10');
    return;
  }
  await service.saveSourceEditMaxLine(parsed);
  await onSaved();
}

/// 选择默认书籍保存目录。
Future<void> pickOtherSettingsDefaultBookTreeUri({
  required OtherSourceSettingsService service,
  required void Function(String message) onError,
  required Future<void> Function() onSaved,
}) async {
  try {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择保存书籍的文件夹',
    );
    if (selected == null || selected.trim().isEmpty) return;
    await service.saveDefaultBookTreeUri(selected);
    await onSaved();
  } catch (error) {
    onError('选择保存书籍的文件夹失败：$error');
  }
}

/// 选择默认主页（同步迁移排除策略：RSS 不可见时跳过该项）。
Future<void> pickOtherSettingsDefaultHomePage({
  required BuildContext context,
  required AppSettings appSettings,
  required SettingsService settingsService,
}) async {
  final excludeRss = MigrationExclusions.excludeRss;
  final pickerItems = <OptionPickerItem<MainDefaultHomePage>>[
    const OptionPickerItem<MainDefaultHomePage>(
      value: MainDefaultHomePage.bookshelf,
      label: '书架',
    ),
    const OptionPickerItem<MainDefaultHomePage>(
      value: MainDefaultHomePage.explore,
      label: '发现',
    ),
    if (!excludeRss)
      const OptionPickerItem<MainDefaultHomePage>(
        value: MainDefaultHomePage.rss,
        label: '订阅',
      ),
    const OptionPickerItem<MainDefaultHomePage>(
      value: MainDefaultHomePage.my,
      label: '我的',
    ),
  ];
  final selected = await showOptionPickerSheet<MainDefaultHomePage>(
    context: context,
    title: '默认主页',
    currentValue: effectiveDefaultHomePageForUi(appSettings.defaultHomePage),
    accentColor: AppDesignTokens.brandPrimary,
    items: pickerItems,
  );
  if (selected == null) return;
  await settingsService.saveDefaultHomePage(selected);
}

/// 选择检查更新查找版本。
Future<void> pickOtherSettingsUpdateToVariant({
  required BuildContext context,
  required AppSettings appSettings,
  required SettingsService settingsService,
}) async {
  final current = appSettings.updateToVariant;
  final variants = <String>[
    AppSettings.defaultUpdateToVariant,
    AppSettings.officialUpdateToVariant,
    AppSettings.betaReleaseUpdateToVariant,
    AppSettings.betaReleaseAUpdateToVariant,
  ];
  final selected = await showOptionPickerSheet<String>(
    context: context,
    title: '检查更新查找版本',
    currentValue: current,
    accentColor: AppDesignTokens.brandPrimary,
    items: variants
        .map(
          (variant) => OptionPickerItem<String>(
            value: variant,
            label: AppSettings.updateToVariantLabel(variant),
          ),
        )
        .toList(growable: false),
  );
  if (selected == null || selected == current) return;
  await settingsService.saveUpdateToVariant(selected);
}

/// 迁移排除策略：RSS 入口隐藏时，默认主页不应继续显示为"订阅"。
MainDefaultHomePage effectiveDefaultHomePageForUi(MainDefaultHomePage page) {
  if (MigrationExclusions.excludeRss && page == MainDefaultHomePage.rss) {
    return MainDefaultHomePage.bookshelf;
  }
  return page;
}

/// 取默认主页中文标签（已应用迁移排除策略）。
String defaultHomePageLabel(MainDefaultHomePage page) {
  switch (effectiveDefaultHomePageForUi(page)) {
    case MainDefaultHomePage.bookshelf:
      return '书架';
    case MainDefaultHomePage.explore:
      return '发现';
    case MainDefaultHomePage.rss:
      return '订阅';
    case MainDefaultHomePage.my:
      return '我的';
  }
}

/// 把多行/超长摘要压成一行短摘要，便于侧栏显示。
String briefSettingsSummary(String value, {String fallback = '未设置'}) {
  final normalized = value.trim();
  if (normalized.isEmpty) return fallback;
  final singleLine = normalized.replaceAll('\n', ' ').replaceAll('\r', ' ');
  if (singleLine.length <= 24) return singleLine;
  return '${singleLine.substring(0, 24)}…';
}

/// 弹出"提示"信息对话框（单按钮"好"）。
void showOtherSettingsMessage(BuildContext context, String message) {
  showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('好'),
        ),
      ],
    ),
  );
}
