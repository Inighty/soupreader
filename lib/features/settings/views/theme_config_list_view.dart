import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../models/theme_config_entry.dart';
import '../services/theme_config_service.dart';

/// 主题列表（对齐 legado ThemeListDialog 的承载与菜单入口）。
class ThemeConfigListView extends StatefulWidget {
  const ThemeConfigListView({super.key});

  @override
  State<ThemeConfigListView> createState() => _ThemeConfigListViewState();
}

class _ThemeConfigListViewState extends State<ThemeConfigListView> {
  final ThemeConfigService _themeConfigService = ThemeConfigService();
  final SettingsService _settingsService = SettingsService();

  List<ThemeConfigEntry> _configs = const <ThemeConfigEntry>[];
  bool _loading = true;
  late AppAppearanceMode _appearanceMode;

  @override
  void initState() {
    super.initState();
    _appearanceMode = _settingsService.appSettings.appearanceMode;
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    unawaited(_reloadConfigs());
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable
        .removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _appearanceMode = _settingsService.appSettings.appearanceMode;
    });
  }

  Future<void> _reloadConfigs() async {
    final configs = _themeConfigService.loadConfigs();
    if (!mounted) return;
    setState(() {
      _configs = configs;
      _loading = false;
    });
  }

  Future<void> _importFromClipboard() async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipData == null) {
      return;
    }
    final clipText = clipData.text ?? '';
    final success = await _themeConfigService.importFromClipboardText(clipText);
    if (!mounted) return;
    if (!success) {
      await _showMessage('格式不对,添加失败');
      return;
    }
    await _reloadConfigs();
  }

  Future<void> _applyConfig(ThemeConfigEntry config) async {
    final targetMode =
        config.isNightTheme ? AppAppearanceMode.dark : AppAppearanceMode.light;
    if (_settingsService.appSettings.appearanceMode == targetMode) {
      return;
    }
    await _settingsService.saveAppSettings(
      _settingsService.appSettings.copyWith(appearanceMode: targetMode),
    );
  }

  bool _isSelectedConfig(ThemeConfigEntry config) {
    if (_appearanceMode == AppAppearanceMode.followSystem) {
      return false;
    }
    final targetMode =
        config.isNightTheme ? AppAppearanceMode.dark : AppAppearanceMode.light;
    return _appearanceMode == targetMode;
  }

  String _modeText(ThemeConfigEntry config) {
    final modeText = config.isNightTheme ? '夜间' : '白天';
    if (_isSelectedConfig(config)) {
      return '$modeText（当前）';
    }
    return modeText;
  }

  String _titleText(ThemeConfigEntry config) {
    final normalized = config.themeName.trim();
    if (normalized.isEmpty) {
      return '未命名主题';
    }
    return normalized;
  }

  Future<void> _showMessage(String message) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '主题列表',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 30,
        onPressed: _importFromClipboard,
        child: const Text('剪贴板导入'),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('已保存主题'),
                  children: _configs.isEmpty
                      ? const [
                          CupertinoListTile(
                            title: Text('暂无主题配置'),
                          ),
                        ]
                      : _configs.map((config) {
                          return CupertinoListTile.notched(
                            title: Text(_titleText(config)),
                            additionalInfo: Text(_modeText(config)),
                            onTap: () => _applyConfig(config),
                          );
                        }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
