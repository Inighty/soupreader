import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/models/backup_restore_ignore_config.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import 'backup_settings_dialogs.dart';

/// 「同步备份对照时间」基线推进。
///
/// 与 legado `LocalConfig.lastBackup` 语义对齐：
/// 本地备份/恢复成功后也要推进对照时间，避免旧远端备份被重复判定为「新备份」。
Future<void> syncBackupCompareBaselineNow({
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required String reason,
}) async {
  try {
    await settingsService.saveLastSeenWebDavBackupMillis(
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'backup_settings.sync_compare_baseline',
      message: '更新自动检查新备份对照时间失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{'reason': reason},
    );
  }
}

void _showLoadingOverlay(BuildContext context) {
  showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CupertinoActivityIndicator()),
  );
}

/// 把「导入完成」的统计信息合成成一段提示文案。
String formatBackupImportSummary(
  BackupImportResult result, {
  required String prefix,
}) {
  final lines = <String>[prefix];
  if (result.ignoredOptions.isNotEmpty) {
    lines.add('恢复时忽略：${result.ignoredOptions.join('、')}');
  }
  if (result.ignoredLocalBooks > 0) {
    lines.add('已跳过本地书籍 ${result.ignoredLocalBooks} 本');
  }
  return lines.join('\n');
}

/// 导出备份到本地文件（带 loading + toast）。
Future<void> exportBackupToFile({
  required BuildContext context,
  required BackupService backupService,
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required bool includeOnlineCache,
  required void Function(String message) showMessage,
}) async {
  _showLoadingOverlay(context);
  final result = await backupService.exportToFile(
    includeOnlineCache: includeOnlineCache,
  );
  if (!context.mounted) return;
  Navigator.pop(context);
  if (result.cancelled) return;
  if (result.success) {
    await syncBackupCompareBaselineNow(
      settingsService: settingsService,
      exceptionLogService: exceptionLogService,
      reason: 'export_to_file',
    );
    if (!context.mounted) return;
    unawaited(showAppToast(context, message: '导出成功'));
    return;
  }
  exceptionLogService.record(
    node: 'backup_settings.export_file',
    message: '导出备份失败',
    context: <String, dynamic>{
      'includeOnlineCache': includeOnlineCache,
      'errorMessage': result.errorMessage,
    },
  );
  showMessage(result.errorMessage ?? '导出失败');
}

/// 从本地备份文件导入。
///
/// [overwrite] 为 true 时会先弹出二次确认对话框。
Future<void> importBackupFromFile({
  required BuildContext context,
  required BackupService backupService,
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required BackupRestoreIgnoreConfig ignoreConfig,
  required bool overwrite,
  required void Function(String message) showMessage,
}) async {
  if (overwrite) {
    final confirmed = await confirmBackupOverwriteImport(context);
    if (!confirmed) return;
  }

  if (!context.mounted) return;
  _showLoadingOverlay(context);
  final result = await backupService.importFromFile(
    overwrite: overwrite,
    ignoreConfig: ignoreConfig,
  );
  if (!context.mounted) return;
  Navigator.pop(context);
  if (result.cancelled) return;
  if (!result.success) {
    exceptionLogService.record(
      node: 'backup_settings.import_file',
      message: '从文件导入备份失败',
      context: <String, dynamic>{
        'overwrite': overwrite,
        'errorMessage': result.errorMessage,
      },
    );
    showMessage(result.errorMessage ?? '导入失败');
    return;
  }
  await syncBackupCompareBaselineNow(
    settingsService: settingsService,
    exceptionLogService: exceptionLogService,
    reason: overwrite ? 'import_file_overwrite' : 'import_file_merge',
  );
  showMessage(formatBackupImportSummary(
    result,
    prefix:
        '导入完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，章节 ${result.chaptersImported} 章',
  ));
}

/// 备份当前应用数据到 WebDav。
Future<void> backupToWebDav({
  required BuildContext context,
  required BackupService backupService,
  required WebDavService webDavService,
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required void Function(String message) showMessage,
}) async {
  final settings = settingsService.appSettings;
  _showLoadingOverlay(context);
  String message;
  try {
    final payload = backupService.buildUploadPayload(
      onlyLatestBackup: settings.onlyLatestBackup,
      deviceName: settings.webDavDeviceName,
    );
    final remoteUrl = await webDavService.uploadBackupBytes(
      settings: settings,
      fileName: payload.fileName,
      bytes: payload.bytes,
    );
    await syncBackupCompareBaselineNow(
      settingsService: settingsService,
      exceptionLogService: exceptionLogService,
      reason: 'backup_to_webdav',
    );
    message = 'WebDav 备份成功\n文件：${payload.fileName}\n远端：$remoteUrl';
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'backup_settings.backup_to_webdav',
      message: '备份到 WebDav 失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'webDavUrl': settings.webDavUrl,
        'onlyLatestBackup': settings.onlyLatestBackup,
      },
    );
    message = 'WebDav 备份失败\n$error';
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  showMessage(message);
}

/// 选中某个 WebDav 备份后，下载并覆盖恢复到本地。
///
/// 返回是否成功；失败时已经向用户展示了「回退本地恢复」对话框。
Future<bool> restoreSelectedWebDavBackup({
  required BuildContext context,
  required BackupService backupService,
  required WebDavService webDavService,
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required WebDavRemoteEntry entry,
  required Future<void> Function() onFallbackToLocal,
  required void Function(String message) showMessage,
}) async {
  _showLoadingOverlay(context);

  try {
    final bytes = await webDavService.downloadFileBytes(
      settings: settingsService.appSettings,
      remoteUrl: entry.path,
    );
    final result =
        await backupService.importFromBytesWithStoredIgnore(bytes);
    if (!context.mounted) return false;
    Navigator.pop(context);
    if (!result.success) {
      exceptionLogService.record(
        node: 'backup_settings.restore_webdav_backup',
        message: '恢复 WebDav 备份失败',
        context: <String, dynamic>{
          'remotePath': entry.path,
          'displayName': entry.displayName,
          'errorMessage': result.errorMessage,
        },
      );
      await _showWebDavRestoreFallback(
        context: context,
        errorMessage: result.errorMessage ?? 'WebDav 恢复失败',
        onFallbackToLocal: onFallbackToLocal,
      );
      return false;
    }
    if (entry.lastModify > 0) {
      await settingsService.saveLastSeenWebDavBackupMillis(entry.lastModify);
    } else {
      await syncBackupCompareBaselineNow(
        settingsService: settingsService,
        exceptionLogService: exceptionLogService,
        reason: 'restore_webdav_backup',
      );
    }
    showMessage(formatBackupImportSummary(
      result,
      prefix:
          'WebDav 恢复完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，章节 ${result.chaptersImported} 章',
    ));
    return true;
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'backup_settings.restore_webdav_backup',
      message: '恢复 WebDav 备份发生异常',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'remotePath': entry.path,
        'displayName': entry.displayName,
      },
    );
    if (!context.mounted) return false;
    Navigator.pop(context);
    await _showWebDavRestoreFallback(
      context: context,
      errorMessage: error.toString(),
      onFallbackToLocal: onFallbackToLocal,
    );
    return false;
  }
}

/// 从 WebDav 恢复（含拉取列表 / 选择 / 下载 / 还原）。
Future<void> restoreFromWebDav({
  required BuildContext context,
  required BackupService backupService,
  required WebDavService webDavService,
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required Future<void> Function() onFallbackToLocal,
  required void Function(String message) showMessage,
}) async {
  final settings = settingsService.appSettings;
  _showLoadingOverlay(context);

  List<WebDavRemoteEntry> backups = const <WebDavRemoteEntry>[];
  try {
    backups = await webDavService.listBackupFiles(settings: settings);
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'backup_settings.list_webdav_backups',
      message: '拉取 WebDav 备份列表失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'webDavUrl': settings.webDavUrl,
        'hasAccount': settings.webDavAccount.trim().isNotEmpty,
        'hasPassword': settings.webDavPassword.trim().isNotEmpty,
      },
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    await _showWebDavRestoreFallback(
      context: context,
      errorMessage: error.toString(),
      onFallbackToLocal: onFallbackToLocal,
    );
    return;
  }
  if (!context.mounted) return;
  Navigator.pop(context);

  if (backups.isEmpty) {
    await _showWebDavRestoreFallback(
      context: context,
      errorMessage: 'WebDav 无可用备份文件',
      onFallbackToLocal: onFallbackToLocal,
    );
    return;
  }

  final selected = await showBackupFilePicker(
    context: context,
    backups: backups,
  );
  if (selected == null || !context.mounted) return;
  await restoreSelectedWebDavBackup(
    context: context,
    backupService: backupService,
    webDavService: webDavService,
    settingsService: settingsService,
    exceptionLogService: exceptionLogService,
    entry: selected,
    onFallbackToLocal: onFallbackToLocal,
    showMessage: showMessage,
  );
}

/// 选择旧版备份文件夹并执行迁移。
Future<void> importOldBackupData({
  required BuildContext context,
  required BackupService backupService,
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required void Function(String message) showMessage,
}) async {
  String? selectedDirectory;
  try {
    selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择旧版备份文件夹',
    );
  } catch (error) {
    showMessage('选择旧版备份文件夹失败：$error');
    return;
  }
  if (selectedDirectory == null || selectedDirectory.trim().isEmpty) return;

  if (!context.mounted) return;
  _showLoadingOverlay(context);

  final result = await backupService.importOldVersionDirectory(
    selectedDirectory,
  );
  if (!context.mounted) return;
  Navigator.pop(context);

  if (!result.success) {
    exceptionLogService.record(
      node: 'backup_settings.import_legacy_directory',
      message: '导入旧版数据失败',
      context: <String, dynamic>{
        'selectedDirectory': selectedDirectory,
        'errorMessage': result.errorMessage,
      },
    );
    showMessage(result.errorMessage ?? '导入旧数据失败');
    return;
  }
  await syncBackupCompareBaselineNow(
    settingsService: settingsService,
    exceptionLogService: exceptionLogService,
    reason: 'import_legacy_directory',
  );
  showMessage(
    '导入旧数据完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，替换规则 ${result.replaceRulesImported} 条',
  );
}

/// 测试 WebDav 连接（只检查能否创建 books 子目录）。
Future<void> testWebDavConnection({
  required BuildContext context,
  required WebDavService webDavService,
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required void Function(String message) showMessage,
}) async {
  _showLoadingOverlay(context);

  var message = '连接成功，已准备 WebDav books 目录';
  try {
    await webDavService.ensureUploadDirectories(settingsService.appSettings);
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'backup_settings.test_webdav_connection',
      message: '测试 WebDav 连接失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'webDavUrl': settingsService.appSettings.webDavUrl,
        'hasAccount':
            settingsService.appSettings.webDavAccount.trim().isNotEmpty,
        'hasPassword':
            settingsService.appSettings.webDavPassword.trim().isNotEmpty,
      },
    );
    message = error.toString();
  } finally {
    if (context.mounted) Navigator.pop(context);
  }

  if (!context.mounted) return;
  showMessage(message);
}

Future<void> _showWebDavRestoreFallback({
  required BuildContext context,
  required String errorMessage,
  required Future<void> Function() onFallbackToLocal,
}) async {
  if (!context.mounted) return;
  final shouldFallback = await confirmWebDavRestoreFallback(
    context: context,
    errorMessage: errorMessage,
  );
  if (shouldFallback) {
    await onFallbackToLocal();
  }
}
