import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';

class AppearanceSettingsView extends StatefulWidget {
  const AppearanceSettingsView({super.key});

  @override
  State<AppearanceSettingsView> createState() => _AppearanceSettingsViewState();
}

class _AppearanceSettingsViewState extends State<AppearanceSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.appSettings;
    _settingsService.appSettingsListenable.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _settings = _settingsService.appSettings);
  }

  Future<void> _showThemeModeManagedHint() async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('外观开关'),
        content: const Text('请在“我的-主题模式”中切换主题模式。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final followSystem =
        _settings.appearanceMode == AppAppearanceMode.followSystem;
    final effectiveIsDark = followSystem
        ? systemBrightness == Brightness.dark
        : _settings.appearanceMode == AppAppearanceMode.dark;

    return AppCupertinoPageScaffold(
      title: '外观与通用',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('外观'),
            children: [
              CupertinoListTile.notched(
                title: const Text('跟随系统外观'),
                trailing: CupertinoSwitch(
                  value: followSystem,
                  onChanged: (_) => _showThemeModeManagedHint(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('深色模式'),
                trailing: CupertinoSwitch(
                  value: effectiveIsDark,
                  onChanged: (_) => _showThemeModeManagedHint(),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('说明'),
            children: const [
              CupertinoListTile(
                title: Text('本页只影响应用整体外观，不影响阅读主题。'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
