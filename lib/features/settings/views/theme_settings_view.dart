import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import 'appearance_settings_view.dart';
import 'cover_config_view.dart';
import 'reading_interface_settings_hub_view.dart';
import 'reading_theme_settings_view.dart';
import 'theme_config_list_view.dart';
import 'welcome_style_settings_view.dart';

class ThemeSettingsView extends StatefulWidget {
  const ThemeSettingsView({super.key});

  @override
  State<ThemeSettingsView> createState() => _ThemeSettingsViewState();
}

class _ThemeSettingsViewState extends State<ThemeSettingsView> {
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable
        .removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleLegacyThemeMode() async {
    final current = _settingsService.appSettings.appearanceMode;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = current == AppAppearanceMode.dark ||
        (current == AppAppearanceMode.followSystem &&
            systemBrightness == Brightness.dark);
    final next = isDark ? AppAppearanceMode.light : AppAppearanceMode.dark;
    await _settingsService.saveAppSettings(
      _settingsService.appSettings.copyWith(appearanceMode: next),
    );
  }

  String _themeModeSummary(BuildContext context) {
    final mode = _settingsService.appSettings.appearanceMode;
    switch (mode) {
      case AppAppearanceMode.followSystem:
        final systemBrightness = MediaQuery.platformBrightnessOf(context);
        return systemBrightness == Brightness.dark
            ? '跟随系统（当前夜间）'
            : '跟随系统（当前白天）';
      case AppAppearanceMode.light:
        return '白天';
      case AppAppearanceMode.dark:
        return '夜间';
    }
  }

  Future<void> _openThemeList() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ThemeConfigListView(),
      ),
    );
  }

  Future<void> _openCoverConfig() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const CoverConfigView(),
      ),
    );
  }

  Future<void> _openWelcomeStyle() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const WelcomeStyleSettingsView(),
      ),
    );
  }

  String _appearanceSummary() {
    switch (_settingsService.appSettings.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return '跟随系统';
      case AppAppearanceMode.light:
        return '浅色';
      case AppAppearanceMode.dark:
        return '深色';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '主题设置',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 30,
        onPressed: _toggleLegacyThemeMode,
        child: const Text('主题模式'),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: Text('主题模式：${_themeModeSummary(context)}'),
            children: [
              CupertinoListTile.notched(
                title: const Text('启动界面样式'),
                additionalInfo: const Text('启动界面图片和是否显示文字等'),
                trailing: const CupertinoListTileChevron(),
                onTap: _openWelcomeStyle,
              ),
              CupertinoListTile.notched(
                title: const Text('封面设置'),
                additionalInfo: const Text('通用封面规则及默认封面样式'),
                trailing: const CupertinoListTileChevron(),
                onTap: _openCoverConfig,
              ),
              CupertinoListTile.notched(
                title: const Text('主题列表'),
                additionalInfo: const Text('使用、保存、导入或分享主题'),
                trailing: const CupertinoListTileChevron(),
                onTap: _openThemeList,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('界面与阅读'),
            children: [
              CupertinoListTile.notched(
                title: const Text('应用外观'),
                additionalInfo: Text(_appearanceSummary()),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const AppearanceSettingsView(),
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读主题'),
                additionalInfo: const Text('主题 / 字体 / 排版'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const ReadingThemeSettingsView(),
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读界面样式'),
                additionalInfo: const Text('页眉页脚 / 排版 / 标题'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) =>
                        const ReadingInterfaceSettingsHubView(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
