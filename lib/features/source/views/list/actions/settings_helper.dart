import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/features/settings/views/app_help_dialog.dart';
import 'package:soupreader/features/source/views/list/widgets/dialogs.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';

class SourceListSettingsHelper {
  const SourceListSettingsHelper({
    required this.context,
    required this.db,
  });

  static const String prefCheckKeyword = 'source_check_keyword';
  static const String prefCheckTimeoutMs = 'source_check_timeout_ms';
  static const String prefCheckSearch = 'source_check_search';
  static const String prefCheckDiscovery = 'source_check_discovery';
  static const String prefCheckInfo = 'source_check_info';
  static const String prefCheckCategory = 'source_check_category';
  static const String prefCheckContent = 'source_check_content';
  static const String prefImportKeepName = 'source_import_keep_name';
  static const String prefImportKeepGroup = 'source_import_keep_group';
  static const String prefImportKeepEnable = 'source_import_keep_enable';
  static const String prefSourceManageHelpShown = 'source_manage_help_shown_v1';

  final BuildContext context;
  final DatabaseService db;

  bool ensureSettingsReady({required String actionName}) {
    try {
      db.driftDb;
      return true;
    } catch (error, stackTrace) {
      debugPrint('[source-settings] $actionName 前检查失败: $error');
      ExceptionLogService().record(
        node: 'source.settings.ready',
        message: '$actionName 前检查失败',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrintStack(stackTrace: stackTrace);
      unawaited(
        SourceListDialogs.showMessage(
          context,
          '应用初始化未完成，暂时无法$actionName。请稍后重试。',
        ),
      );
      return false;
    }
  }

  dynamic settingsGet(
    String key, {
    dynamic defaultValue,
  }) {
    try {
      return db.getSetting(key, defaultValue: defaultValue);
    } catch (error, stackTrace) {
      debugPrint('[source-settings] 读取 $key 失败: $error');
      ExceptionLogService().record(
        node: 'source.settings.read',
        message: '读取设置失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'key': key},
      );
      debugPrintStack(stackTrace: stackTrace);
      return defaultValue;
    }
  }

  bool settingsGetBool(
    String key, {
    required bool defaultValue,
  }) {
    final value = settingsGet(key, defaultValue: defaultValue);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return defaultValue;
  }

  int settingsGetInt(
    String key, {
    required int defaultValue,
  }) {
    final value = settingsGet(key, defaultValue: defaultValue);
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<bool> settingsPut(
    String key,
    dynamic value,
  ) async {
    try {
      await db.putSetting(key, value);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[source-settings] 写入 $key 失败: $error');
      ExceptionLogService().record(
        node: 'source.settings.write',
        message: '写入设置失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'key': key},
      );
      debugPrintStack(stackTrace: stackTrace);
      await SourceListDialogs.showMessage(context, '设置保存失败：$error');
      return false;
    }
  }

  SourceCheckSettings loadCheckSettings() {
    final timeout = settingsGetInt(
      prefCheckTimeoutMs,
      defaultValue: 180000,
    );
    final normalizedTimeout = timeout > 0 ? timeout : 180000;
    final checkInfo = settingsGetBool(prefCheckInfo, defaultValue: true);
    final checkCategory =
        checkInfo && settingsGetBool(prefCheckCategory, defaultValue: true);
    final checkContent =
        checkCategory && settingsGetBool(prefCheckContent, defaultValue: true);
    return SourceCheckSettings(
      timeoutMs: normalizedTimeout,
      checkSearch: settingsGetBool(prefCheckSearch, defaultValue: true),
      checkDiscovery: settingsGetBool(prefCheckDiscovery, defaultValue: true),
      checkInfo: checkInfo,
      checkCategory: checkCategory,
      checkContent: checkContent,
    );
  }

  Future<bool> showCheckSettingsDialog() async {
    if (!ensureSettingsReady(actionName: '保存校验设置')) return false;
    final current = loadCheckSettings();
    var checkSearch = current.checkSearch;
    var checkDiscovery = current.checkDiscovery;
    var checkInfo = current.checkInfo;
    var checkCategory = current.checkCategory;
    var checkContent = current.checkContent;
    final timeoutController = TextEditingController(
      text: (current.timeoutMs ~/ 1000).toString(),
    );

    try {
      final saved = await showCupertinoBottomSheetDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => CupertinoAlertDialog(
            title: const Text('校验设置'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  CupertinoTextField(
                    controller: timeoutController,
                    keyboardType: TextInputType.number,
                    placeholder: '超时时间（秒）',
                  ),
                  const SizedBox(height: 10),
                  _buildCheckSwitchRow(
                    title: '校验搜索',
                    value: checkSearch,
                    onChanged: (value) {
                      setDialogState(() {
                        checkSearch = value;
                        if (!checkSearch && !checkDiscovery) {
                          checkDiscovery = true;
                        }
                      });
                    },
                  ),
                  _buildCheckSwitchRow(
                    title: '校验发现',
                    value: checkDiscovery,
                    onChanged: (value) {
                      setDialogState(() {
                        checkDiscovery = value;
                        if (!checkSearch && !checkDiscovery) {
                          checkSearch = true;
                        }
                      });
                    },
                  ),
                  _buildCheckSwitchRow(
                    title: '校验详情',
                    value: checkInfo,
                    onChanged: (value) {
                      setDialogState(() {
                        checkInfo = value;
                        if (!checkInfo) {
                          checkCategory = false;
                          checkContent = false;
                        }
                      });
                    },
                  ),
                  _buildCheckSwitchRow(
                    title: '校验目录',
                    value: checkCategory,
                    onChanged: !checkInfo
                        ? null
                        : (value) {
                            setDialogState(() {
                              checkCategory = value;
                              if (!checkCategory) {
                                checkContent = false;
                              }
                            });
                          },
                  ),
                  _buildCheckSwitchRow(
                    title: '校验正文',
                    value: checkContent,
                    onChanged: !checkCategory
                        ? null
                        : (value) {
                            setDialogState(() => checkContent = value);
                          },
                  ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () async {
                  final timeoutSeconds =
                      int.tryParse(timeoutController.text.trim()) ?? 0;
                  if (timeoutSeconds <= 0) {
                    await SourceListDialogs.showMessage(context, '超时时间需大于0秒');
                    return;
                  }
                  if (!checkSearch && !checkDiscovery) {
                    await SourceListDialogs.showMessage(context, '至少启用一种校验方式');
                    return;
                  }
                  final timeoutSaved =
                      await settingsPut(prefCheckTimeoutMs, timeoutSeconds * 1000);
                  if (!timeoutSaved) return;
                  if (!await settingsPut(prefCheckSearch, checkSearch)) return;
                  if (!await settingsPut(prefCheckDiscovery, checkDiscovery)) {
                    return;
                  }
                  if (!await settingsPut(prefCheckInfo, checkInfo)) return;
                  if (!await settingsPut(prefCheckCategory, checkInfo && checkCategory)) {
                    return;
                  }
                  if (!await settingsPut(
                    prefCheckContent,
                    checkInfo && checkCategory && checkContent,
                  )) {
                    return;
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      );
      return saved == true;
    } finally {
      timeoutController.dispose();
    }
  }

  Future<String?> askCheckKeyword() async {
    if (!ensureSettingsReady(actionName: '保存校验关键词')) return null;
    final cached =
        (settingsGet(prefCheckKeyword, defaultValue: '我的') ?? '我的').toString();
    final keywordInput = await showCheckKeywordDialog(cached);
    if (keywordInput == null) return null;
    final normalized = keywordInput.trim();
    final keyword =
        normalized.isNotEmpty ? normalized : (cached.trim().isNotEmpty ? cached.trim() : '我的');
    await settingsPut(prefCheckKeyword, keyword);
    return keyword;
  }

  Future<String?> showCheckKeywordDialog(String initialKeyword) async {
    final controller = TextEditingController(text: initialKeyword);
    try {
      return await showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('搜索关键词'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'search word',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                await showCheckSettingsDialog();
              },
              child: const Text('校验设置'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('开始校验'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> showSourceManageHelp() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/SourceMBookHelp.md');
      if (!context.mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!context.mounted) return;
      await SourceListDialogs.showMessage(context, '帮助文档加载失败：$error', title: '帮助');
    }
  }

  Future<void> maybeShowSourceManageHelpOnce() async {
    final shown = settingsGetBool(prefSourceManageHelpShown, defaultValue: false);
    if (shown) return;
    await settingsPut(prefSourceManageHelpShown, true);
    if (!context.mounted) return;
    await showSourceManageHelp();
  }

  Widget _buildCheckSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
