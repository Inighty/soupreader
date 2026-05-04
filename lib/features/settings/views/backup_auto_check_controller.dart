import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import 'backup_settings_helpers.dart';

/// 「自动检查 WebDav 新备份」状态机。
///
/// 接管 WebDavService.listBackupFiles 的拉取节奏：
/// - 进入备份页时（postFrame）触发首次检查
/// - 「自动检查新备份」开关切回开启时触发一次
/// - 同一远端备份在「已提示时间」内不会重复弹出
class BackupAutoCheckController extends ChangeNotifier {
  BackupAutoCheckController({
    required this.settingsService,
    required this.webDavService,
    required this.exceptionLogService,
    required this.isStillMounted,
  }) {
    _lastEnabled = settingsService.appSettings.autoCheckNewBackup;
    settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
  }

  static const int _autoCheckPromptGapMs = 60 * 1000;

  final SettingsService settingsService;
  final WebDavService webDavService;
  final ExceptionLogService exceptionLogService;
  final bool Function() isStillMounted;

  bool _checking = false;
  bool _triggered = false;
  bool _lastEnabled = false;
  String? _errorMessage;
  WebDavRemoteEntry? _detectedBackup;

  bool get isChecking => _checking;
  String? get errorMessage => _errorMessage;
  WebDavRemoteEntry? get detectedBackup => _detectedBackup;

  @override
  void dispose() {
    settingsService.appSettingsListenable.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!isStillMounted()) return;
    final enabled = settingsService.appSettings.autoCheckNewBackup;
    if (!enabled) {
      _triggered = false;
      _detectedBackup = null;
      _errorMessage = null;
      _checking = false;
      _lastEnabled = enabled;
      notifyListeners();
      return;
    }
    if (enabled && !_lastEnabled) {
      unawaited(triggerOnPageEnter(force: true));
    } else if (!_triggered && !_checking) {
      unawaited(triggerOnPageEnter());
    }
    _lastEnabled = enabled;
    notifyListeners();
  }

  Future<void> handleSwitchChanged(bool enabled) async {
    await settingsService.saveAutoCheckNewBackup(enabled);
    if (!isStillMounted()) return;
    if (!enabled) {
      _detectedBackup = null;
      _errorMessage = null;
      _checking = false;
      notifyListeners();
      return;
    }
    await triggerOnPageEnter(force: true);
  }

  /// 进入备份页时自动检查“是否存在比本地记录更新的 WebDav 备份”。
  Future<void> triggerOnPageEnter({bool force = false}) async {
    final settings = settingsService.appSettings;
    if (!settings.autoCheckNewBackup) return;
    if (_checking) return;
    if (_triggered && !force) return;
    if (!_hasWebDavCredential(settings)) {
      _detectedBackup = null;
      _errorMessage = null;
      _checking = false;
      if (isStillMounted()) notifyListeners();
      return;
    }

    _checking = true;
    _errorMessage = null;
    if (isStillMounted()) notifyListeners();

    try {
      final backups = await webDavService.listBackupFiles(settings: settings);
      if (!isStillMounted()) return;
      _triggered = true;

      if (backups.isEmpty) {
        _detectedBackup = null;
        return;
      }

      final latestBackup = backups.first;
      final remoteLastModify = latestBackup.lastModify;
      if (remoteLastModify <= 0) {
        _detectedBackup = null;
        return;
      }

      final lastSeenMillis = settingsService.getLastSeenWebDavBackupMillis();
      final hasNewerBackup =
          remoteLastModify - lastSeenMillis > _autoCheckPromptGapMs;
      if (!hasNewerBackup) {
        _detectedBackup = null;
        return;
      }

      // 与 legado 一致：提示前先更新本地“已提示时间”，避免同一远端备份重复提示。
      await settingsService.saveLastSeenWebDavBackupMillis(remoteLastModify);
      if (!isStillMounted()) return;
      _detectedBackup = latestBackup;
    } catch (error, stackTrace) {
      _triggered = true;
      exceptionLogService.record(
        node: 'backup_settings.auto_check_new_backup',
        message: '进入备份页自动检查远端新备份失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'webDavUrl': settings.webDavUrl,
          'hasAccount': settings.webDavAccount.trim().isNotEmpty,
          'hasPassword': settings.webDavPassword.trim().isNotEmpty,
        },
      );
      if (!isStillMounted()) return;
      _detectedBackup = null;
      _errorMessage = normalizeBackupErrorMessage(error);
    } finally {
      if (isStillMounted()) {
        _checking = false;
        notifyListeners();
      }
    }
  }

  /// 把「检测到较新备份」清掉（外部确认或忽略后调用）。
  void clearDetectedBackup() {
    _detectedBackup = null;
    _errorMessage = null;
    if (isStillMounted()) notifyListeners();
  }

  /// 恢复失败时把上次检测到的条目恢复回来。
  void restoreDetectedBackup(WebDavRemoteEntry entry) {
    _detectedBackup = entry;
    if (isStillMounted()) notifyListeners();
  }

  bool _hasWebDavCredential(AppSettings settings) {
    return settings.webDavAccount.trim().isNotEmpty &&
        settings.webDavPassword.trim().isNotEmpty;
  }
}
