import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import 'about_app_update.dart';
import 'about_hero_card.dart';
import 'about_log_exporter.dart';
import 'app_help_dialog.dart';
import 'exception_logs_view.dart';

class AboutSettingsView extends StatefulWidget {
  const AboutSettingsView({super.key});

  @override
  State<AboutSettingsView> createState() => _AboutSettingsViewState();
}

class _AboutSettingsViewState extends State<AboutSettingsView> {
  static const String _fallbackAppName = 'SoupReader';
  static const String _appShareDescription =
      'SoupReader 下载链接：\nhttps://github.com/Inighty/soupreader/releases';
  static const String _contributorsUrl =
      'https://github.com/gedoor/legado/graphs/contributors';

  final SettingsService _settingsService = SettingsService();
  final ExceptionLogService _exceptionLogService = ExceptionLogService();

  String _version = '—';
  String _versionSummary = '版本 —';
  String _appName = _fallbackAppName;
  String _packageName = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final appName = info.appName.trim();
      final version = info.version.trim();
      setState(() {
        _appName = appName.isEmpty ? _fallbackAppName : appName;
        _version = version.isEmpty ? '—' : version;
        _versionSummary = '版本 $_version';
        _packageName = info.packageName.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appName = _fallbackAppName;
        _version = '—';
        _versionSummary = '版本 —';
        _packageName = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '关于',
      trailing: _buildTrailingActions(),
      child: ValueListenableBuilder<List<ExceptionLogEntry>>(
        valueListenable: _exceptionLogService.listenable,
        builder: (context, logs, _) {
          return AppListView(
            children: [
              AboutHeroCard(
                appName: _appName,
                version: _version,
                versionSummary: _versionSummary,
                packageName: _packageName,
              ),
              AppListSection(
                hasLeading: false,
                children: [
                  AppListTile(
                    title: const Text('开发人员'),
                    onTap: _openContributors,
                  ),
                  AppListTile(
                    title: const Text('更新日志'),
                    additionalInfo: Text(_versionSummary),
                    onTap: _openUpdateLog,
                  ),
                  AppListTile(
                    title: const Text('检查更新'),
                    onTap: _checkUpdate,
                  ),
                ],
              ),
              AppListSection(
                header: const Text('其它'),
                hasLeading: false,
                children: [
                  AppListTile(
                    title: const Text('崩溃日志'),
                    additionalInfo: Text('${logs.length} 条'),
                    onTap: _openCrashLogs,
                  ),
                  AppListTile(
                    title: const Text('保存日志'),
                    onTap: _saveLog,
                  ),
                  AppListTile(
                    title: const Text('创建堆转储'),
                    onTap: _createHeapDump,
                  ),
                  AppListTile(
                    title: const Text('用户隐私与协议'),
                    onTap: _openPrivacyPolicy,
                  ),
                  AppListTile(
                    title: const Text('开源许可'),
                    onTap: _openLicense,
                  ),
                  AppListTile(
                    title: const Text('免责声明'),
                    onTap: _openDisclaimer,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrailingActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppNavBarButton(
          onPressed: _handleShare,
          child: const Icon(CupertinoIcons.share, size: 22),
        ),
        AppNavBarButton(
          onPressed: _openScoring,
          child: const Icon(CupertinoIcons.hand_thumbsup, size: 22),
        ),
      ],
    );
  }

  Future<void> _handleShare() async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: _appShareDescription, subject: _appName),
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.menu_share_it',
        message: '分享动作触发失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessage('分享失败：${summarizeError(error)}');
    }
  }

  Future<void> _openScoring() async {
    final packageName = _packageName.trim();
    if (packageName.isEmpty) {
      await _showMessage('未获取到应用包名，无法打开评分入口');
      return;
    }

    final marketUri = Uri.parse('market://details?id=$packageName');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );

    try {
      if (await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
        return;
      }
      if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        return;
      }
      await _showMessage('未找到可用的评分入口');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.menu_scoring',
        message: '评分入口打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'packageName': packageName},
      );
      if (!mounted) return;
      await _showMessage('评分入口打开失败：${summarizeError(error)}');
    }
  }

  Future<void> _openContributors() async {
    await _openExternalUrl(
      _contributorsUrl,
      node: 'about.contributors',
      failureMessage: '打开开发人员页面失败',
    );
  }

  Future<void> _openCrashLogs() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ExceptionLogsView(
          title: '崩溃日志',
          emptyHint: '暂无崩溃日志',
        ),
      ),
    );
  }

  Future<void> _openUpdateLog() => _openDoc(
        title: '更新日志',
        assetPath: 'assets/docs/update_log.md',
        node: 'about.update_log',
      );

  Future<void> _openPrivacyPolicy() => _openDoc(
        title: '用户隐私与协议',
        assetPath: 'assets/docs/privacy_policy.md',
        node: 'about.privacy_policy',
      );

  Future<void> _openLicense() => _openDoc(
        title: '开源许可',
        assetPath: 'assets/docs/LICENSE.md',
        node: 'about.license',
      );

  Future<void> _openDisclaimer() => _openDoc(
        title: '免责声明',
        assetPath: 'assets/docs/disclaimer.md',
        node: 'about.disclaimer',
      );

  Future<void> _openDoc({
    required String title,
    required String assetPath,
    required String node,
  }) async {
    try {
      final markdownText = await rootBundle.loadString(assetPath);
      if (!mounted) return;
      await showAppHelpDialog(
        context,
        title: title,
        markdownText: markdownText,
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: node,
        message: '文档加载失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'assetPath': assetPath},
      );
      if (!mounted) return;
      await _showMessage('文档加载失败：${summarizeError(error)}');
    }
  }

  Future<void> _saveLog() async {
    final settings = _settingsService.appSettings;
    final backupPath = settings.backupPath.trim();
    if (backupPath.isEmpty) {
      await _showMessage('未设置备份目录');
      return;
    }

    if (!settings.recordLog) {
      final shouldContinue = await _confirmAction(
        title: '记录日志未开启',
        message: '当前“记录日志”未开启，仍将导出当前已采集日志。',
        confirmText: '继续',
      );
      if (!shouldContinue) return;
    }

    final exporter = _buildExporter(backupPath);
    try {
      final filePath = await exporter.writeLogs();
      _exceptionLogService.record(
        node: 'about.save_log',
        message: '日志保存成功',
        context: <String, dynamic>{
          'filePath': filePath,
          'entries': _exceptionLogService.count,
        },
      );
      await _showMessage('已保存至备份目录\n$filePath');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.save_log',
        message: '日志保存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'backupPath': backupPath},
      );
      if (!mounted) return;
      await _showMessage('保存日志失败：${summarizeError(error)}');
    }
  }

  Future<void> _createHeapDump() async {
    final settings = _settingsService.appSettings;
    final backupPath = settings.backupPath.trim();
    if (backupPath.isEmpty) {
      await _showMessage('未设置备份目录');
      return;
    }

    if (!settings.recordHeapDump) {
      final shouldContinue = await _confirmAction(
        title: '堆转储未开启',
        message: '当前“记录堆转储”未开启，仍将尝试创建诊断堆快照。',
        confirmText: '继续',
      );
      if (!shouldContinue) return;
    }

    final exporter = _buildExporter(backupPath);
    try {
      final filePath = await exporter.writeHeapDump();
      _exceptionLogService.record(
        node: 'about.create_heap_dump',
        message: '堆转储保存成功',
        context: <String, dynamic>{'filePath': filePath},
      );
      await _showMessage('已保存至备份目录\n$filePath');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'about.create_heap_dump',
        message: '创建堆转储失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'backupPath': backupPath},
      );
      if (!mounted) return;
      await _showMessage('创建堆转储失败：${summarizeError(error)}');
    }
  }

  AboutLogExporter _buildExporter(String backupPath) => AboutLogExporter(
        backupPath: backupPath,
        appName: _appName,
        packageName: _packageName,
        version: _version,
        exceptionLogService: _exceptionLogService,
      );

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    if (!mounted) return false;
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openExternalUrl(
    String url, {
    required String node,
    required String failureMessage,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      await _showMessage('$failureMessage：链接无效');
      return;
    }

    try {
      final started =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (started) return;
      await _showMessage('$failureMessage：未找到可处理的应用');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: node,
        message: failureMessage,
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'url': url},
      );
      if (!mounted) return;
      await _showMessage('$failureMessage：${summarizeError(error)}');
    }
  }

  Future<void> _checkUpdate() async {
    if (!mounted) return;
    await checkAppUpdateAndPrompt(
      context: context,
      exceptionLogService: _exceptionLogService,
      version: _version,
      showMessage: _showMessage,
      dismissLoading: () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}
