import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/backup_restore_ignore_config.dart';
import '../../../core/services/backup_restore_ignore_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import 'app_help_dialog.dart';
import 'app_log_dialog.dart';
import 'backup_auto_check_controller.dart';
import 'backup_settings_actions.dart';
import 'backup_settings_dialogs.dart';
import 'backup_settings_helpers.dart';
import 'backup_settings_webdav_tiles.dart';

class BackupSettingsView extends StatefulWidget {
  const BackupSettingsView({super.key});

  @override
  State<BackupSettingsView> createState() => _BackupSettingsViewState();
}

class _BackupSettingsViewState extends State<BackupSettingsView> {
  final GlobalKey _moreMenuKey = GlobalKey();
  final BackupService _backupService = BackupService();
  final BackupRestoreIgnoreService _backupRestoreIgnoreService =
      BackupRestoreIgnoreService();
  final ExceptionLogService _exceptionLogService = ExceptionLogService();
  final SettingsService _settingsService = SettingsService();
  final WebDavService _webDavService = WebDavService();

  late final BackupAutoCheckController _autoCheck;
  bool _loadingHelp = false;
  bool _restoringDetectedBackup = false;
  BackupRestoreIgnoreConfig _restoreIgnoreConfig =
      const BackupRestoreIgnoreConfig();

  @override
  void initState() {
    super.initState();
    _restoreIgnoreConfig = _backupRestoreIgnoreService.load();
    _autoCheck = BackupAutoCheckController(
      settingsService: _settingsService,
      webDavService: _webDavService,
      exceptionLogService: _exceptionLogService,
      isStillMounted: () => mounted,
    );
    _autoCheck.addListener(_onAutoCheckChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCheck.triggerOnPageEnter();
    });
  }

  @override
  void dispose() {
    _autoCheck
      ..removeListener(_onAutoCheckChanged)
      ..dispose();
    super.dispose();
  }

  void _onAutoCheckChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settingsService.appSettings;
    return AppCupertinoPageScaffold(
      title: '备份与恢复',
      trailing: _buildTrailingActions(),
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('导出'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('导出备份（推荐）'),
                onTap: () => _export(includeOnlineCache: false),
              ),
              AppListTile(
                title: const Text('导出（含在线缓存）'),
                onTap: () => _export(includeOnlineCache: true),
              ),
            ],
          ),
          AppListSection(
            header: const Text('导入'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('从文件导入（合并）'),
                onTap: () => _import(overwrite: false),
              ),
              AppListTile(
                title: const Text('从文件导入（覆盖）'),
                onTap: () => _import(overwrite: true),
              ),
            ],
          ),
          AppListSection(
            header: const Text('WebDav 同步'),
            hasLeading: false,
            children: _buildWebDavTiles(settings),
          ),
          AppListSection(
            header: const Text('备份恢复'),
            hasLeading: false,
            children: _buildRestoreTiles(settings),
          ),
          const AppListSection(
            header: Text('说明'),
            hasLeading: false,
            children: [
              AppListTile(
                title: Text('备份包含：设置、书源、书架、本地书籍章节内容，以及“本书独立阅读设置”。'),
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildWebDavTiles(AppSettings settings) {
    return buildBackupWebDavTiles(
      settings: settings,
      settingsService: _settingsService,
      onEditField: _editField,
      onTestConnection: () => testWebDavConnection(
        context: context,
        webDavService: _webDavService,
        settingsService: _settingsService,
        exceptionLogService: _exceptionLogService,
        showMessage: _showMessage,
      ),
    );
  }

  List<Widget> _buildRestoreTiles(AppSettings settings) {
    return [
      AppListTile(
        title: const Text('备份路径'),
        additionalInfo: Text(
          briefBackupValue(settings.backupPath, fallback: '请选择备份路径'),
        ),
        onTap: _editBackupPath,
      ),
      AppListTile(
        title: const Text('备份到 WebDav'),
        onTap: () => backupToWebDav(
          context: context,
          backupService: _backupService,
          webDavService: _webDavService,
          settingsService: _settingsService,
          exceptionLogService: _exceptionLogService,
          showMessage: _showMessage,
        ),
      ),
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: _restoreFromLocal,
        child: AppListTile(
          title: const Text('从 WebDav 恢复'),
          onTap: () => restoreFromWebDav(
            context: context,
            backupService: _backupService,
            webDavService: _webDavService,
            settingsService: _settingsService,
            exceptionLogService: _exceptionLogService,
            onFallbackToLocal: _restoreFromLocal,
            showMessage: _showMessage,
          ),
        ),
      ),
      ..._buildAutoCheckPromptTiles(),
      AppListTile(
        title: const Text('恢复时忽略'),
        additionalInfo: Text(briefBackupValue(_restoreIgnoreConfig.summary())),
        onTap: _editRestoreIgnore,
      ),
      AppListTile(
        key: const Key('import_old'),
        title: const Text('导入旧数据'),
        onTap: () => importOldBackupData(
          context: context,
          backupService: _backupService,
          settingsService: _settingsService,
          exceptionLogService: _exceptionLogService,
          showMessage: _showMessage,
        ),
      ),
      AppListTile(
        title: const Text('仅保留最新备份'),
        trailing: CupertinoSwitch(
          value: settings.onlyLatestBackup,
          onChanged: _settingsService.saveOnlyLatestBackup,
        ),
      ),
      AppListTile(
        title: const Text('自动检查新备份'),
        trailing: CupertinoSwitch(
          value: settings.autoCheckNewBackup,
          onChanged: _autoCheck.handleSwitchChanged,
        ),
      ),
    ];
  }

  List<Widget> _buildAutoCheckPromptTiles() {
    final enabled = _settingsService.appSettings.autoCheckNewBackup;
    if (!enabled) return const <Widget>[];

    if (_autoCheck.isChecking) {
      return <Widget>[
        const AppListTile(
          title: Text('自动检查新备份'),
          additionalInfo: Text('正在检查 WebDav 远端备份'),
          trailing: CupertinoActivityIndicator(),
          showChevron: false,
        ),
      ];
    }

    final detected = _autoCheck.detectedBackup;
    if (detected != null) {
      return <Widget>[
        AppListTile(
          title: const Text('检测到较新的 WebDav 备份'),
          additionalInfo: Text(backupEntrySummary(detected)),
          trailing: _restoringDetectedBackup
              ? const CupertinoActivityIndicator()
              : null,
          onTap: _restoringDetectedBackup
              ? null
              : () => _confirmRestoreDetectedBackup(detected),
        ),
      ];
    }

    final error = _autoCheck.errorMessage;
    if (error != null && error.trim().isNotEmpty) {
      return <Widget>[
        AppListTile(
          title: const Text('自动检查失败'),
          additionalInfo: Text(briefBackupValue(error)),
          onTap: () => _autoCheck.triggerOnPageEnter(force: true),
        ),
      ];
    }
    return const <Widget>[];
  }

  Future<void> _confirmRestoreDetectedBackup(WebDavRemoteEntry entry) async {
    final confirmed = await confirmRestoreDetectedBackup(
      context: context,
      entry: entry,
    );
    if (!confirmed || !mounted) return;

    setState(() => _restoringDetectedBackup = true);
    _autoCheck.clearDetectedBackup();

    final restored = await restoreSelectedWebDavBackup(
      context: context,
      backupService: _backupService,
      webDavService: _webDavService,
      settingsService: _settingsService,
      exceptionLogService: _exceptionLogService,
      entry: entry,
      onFallbackToLocal: _restoreFromLocal,
      showMessage: _showMessage,
    );
    if (!mounted) return;
    setState(() => _restoringDetectedBackup = false);
    if (!restored) {
      _autoCheck.restoreDetectedBackup(entry);
    }
  }

  Widget _buildTrailingActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_loadingHelp)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: CupertinoActivityIndicator(radius: 9),
          )
        else
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _openWebDavHelp,
            child: const Icon(CupertinoIcons.question_circle, size: 22),
          ),
        CupertinoButton(
          key: _moreMenuKey,
          padding: EdgeInsets.zero,
          minimumSize: const Size(30, 30),
          onPressed: _showMoreActions,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
        ),
      ],
    );
  }

  Future<void> _openWebDavHelp() async {
    if (_loadingHelp) return;
    setState(() => _loadingHelp = true);
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/webDavBookHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!mounted) return;
      await showCupertinoBottomSheetDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingHelp = false);
    }
  }

  Future<void> _showMoreActions() async {
    final selected = await showAppPopoverMenu<_BackupMoreAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _BackupMoreAction.logs,
          icon: CupertinoIcons.doc_text,
          label: '日志',
        ),
      ],
    );
    if (selected == _BackupMoreAction.logs && mounted) {
      await showAppLogDialog(context);
    }
  }

  Future<void> _export({required bool includeOnlineCache}) {
    return exportBackupToFile(
      context: context,
      backupService: _backupService,
      settingsService: _settingsService,
      exceptionLogService: _exceptionLogService,
      includeOnlineCache: includeOnlineCache,
      showMessage: _showMessage,
    );
  }

  Future<void> _import({required bool overwrite}) async {
    final ignoreConfig = _backupRestoreIgnoreService.load();
    if (mounted) {
      setState(() => _restoreIgnoreConfig = ignoreConfig);
    }
    await importBackupFromFile(
      context: context,
      backupService: _backupService,
      settingsService: _settingsService,
      exceptionLogService: _exceptionLogService,
      ignoreConfig: ignoreConfig,
      overwrite: overwrite,
      showMessage: _showMessage,
    );
  }

  Future<void> _restoreFromLocal() => _import(overwrite: false);

  Future<void> _editRestoreIgnore() async {
    final current = _backupRestoreIgnoreService.load();
    final result = await showRestoreIgnoreDialog(
      context: context,
      current: current,
    );
    if (result == null) return;
    await _backupRestoreIgnoreService.saveSelectedKeys(result);
    final next = _backupRestoreIgnoreService.load();
    if (!mounted) return;
    setState(() => _restoreIgnoreConfig = next);
    unawaited(showAppToast(
      context,
      message: '已保存：${next.summary(maxItems: 3)}',
    ));
  }

  Future<void> _editBackupPath() {
    return _editField(
      title: '备份路径',
      placeholder: '请输入备份目录路径',
      initialValue: _settingsService.appSettings.backupPath,
      onSave: _settingsService.saveBackupPath,
    );
  }

  Future<void> _editField({
    required String title,
    required String placeholder,
    required String initialValue,
    required Future<void> Function(String value) onSave,
    bool obscureText = false,
  }) {
    return showBackupFieldEditDialog(
      context: context,
      title: title,
      placeholder: placeholder,
      initialValue: initialValue,
      onSave: onSave,
      obscureText: obscureText,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showBackupMessageDialog(context, message);
  }
}

enum _BackupMoreAction {
  logs,
}
