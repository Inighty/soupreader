import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import 'backup_settings_helpers.dart';

/// WebDav 同步 section 的 6 个 tile（地址 / 账号 / 密码 / 目录 / 设备名称 / 开关 + 测试）。
List<Widget> buildBackupWebDavTiles({
  required AppSettings settings,
  required SettingsService settingsService,
  required Future<void> Function({
    required String title,
    required String placeholder,
    required String initialValue,
    required Future<void> Function(String value) onSave,
    bool obscureText,
  }) onEditField,
  required VoidCallback onTestConnection,
}) {
  return [
    AppListTile(
      title: const Text('服务器地址'),
      additionalInfo: Text(briefBackupValue(settings.webDavUrl)),
      onTap: () => onEditField(
        title: '服务器地址',
        placeholder: 'https://dav.example.com/dav/',
        initialValue: settings.webDavUrl,
        onSave: (value) async {
          await settingsService.saveAppSettings(
            settingsService.appSettings.copyWith(webDavUrl: value),
          );
        },
      ),
    ),
    AppListTile(
      title: const Text('账号'),
      additionalInfo: Text(briefBackupValue(settings.webDavAccount)),
      onTap: () => onEditField(
        title: 'WebDav 账号',
        placeholder: '请输入账号',
        initialValue: settings.webDavAccount,
        onSave: (value) async {
          await settingsService.saveAppSettings(
            settingsService.appSettings.copyWith(webDavAccount: value),
          );
        },
      ),
    ),
    AppListTile(
      title: const Text('密码'),
      additionalInfo: Text(maskBackupSecret(settings.webDavPassword)),
      onTap: () => onEditField(
        title: 'WebDav 密码',
        placeholder: '请输入密码',
        initialValue: settings.webDavPassword,
        obscureText: true,
        onSave: (value) async {
          await settingsService.saveAppSettings(
            settingsService.appSettings.copyWith(webDavPassword: value),
          );
        },
      ),
    ),
    AppListTile(
      title: const Text('同步目录'),
      additionalInfo: Text(
        briefBackupValue(settings.webDavDir, fallback: 'legado'),
      ),
      onTap: () => onEditField(
        title: '同步目录',
        placeholder: '可留空，例如 booksync',
        initialValue: settings.webDavDir,
        onSave: (value) async {
          await settingsService.saveAppSettings(
            settingsService.appSettings.copyWith(webDavDir: value),
          );
        },
      ),
    ),
    AppListTile(
      title: const Text('设备名称'),
      additionalInfo: Text(briefBackupValue(settings.webDavDeviceName)),
      onTap: () => onEditField(
        title: '设备名称',
        placeholder: '可留空，用于区分备份来源设备',
        initialValue: settings.webDavDeviceName,
        onSave: settingsService.saveWebDavDeviceName,
      ),
    ),
    AppListTile(
      title: const Text('同步阅读进度'),
      trailing: CupertinoSwitch(
        value: settings.syncBookProgress,
        onChanged: settingsService.saveSyncBookProgress,
      ),
    ),
    AppListTile(
      title: const Text('同步增强'),
      trailing: CupertinoSwitch(
        value: settings.syncBookProgressPlus,
        onChanged: settings.syncBookProgress
            ? settingsService.saveSyncBookProgressPlus
            : null,
      ),
    ),
    AppListTile(
      title: const Text('测试连接'),
      onTap: onTestConnection,
    ),
  ];
}
