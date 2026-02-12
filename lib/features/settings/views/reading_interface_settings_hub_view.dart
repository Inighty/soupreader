import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/typography_settings_dialog.dart';
import 'reading_preferences_view.dart';
import 'reading_theme_settings_view.dart';

class ReadingInterfaceSettingsHubView extends StatefulWidget {
  const ReadingInterfaceSettingsHubView({super.key});

  @override
  State<ReadingInterfaceSettingsHubView> createState() =>
      _ReadingInterfaceSettingsHubViewState();
}

class _ReadingInterfaceSettingsHubViewState
    extends State<ReadingInterfaceSettingsHubView> {
  final SettingsService _settingsService = SettingsService();

  ReadingSettings get _settings => _settingsService.readingSettings;

  Future<void> _openPreferences() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingPreferencesView(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openTheme() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingThemeSettingsView(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _openTypographyDialog() {
    showTypographySettingsDialog(
      context,
      settings: _settings,
      onSettingsChanged: (newSettings) {
        unawaited(_settingsService.saveReadingSettings(newSettings));
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '界面（样式）',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text(
            '阅读视觉与排版',
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildItem(
                  title: '常用样式与亮度',
                  info: '主题 / 字号 / 亮度',
                  onTap: _openPreferences,
                ),
                const ShadSeparator.horizontal(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                ),
                _buildItem(
                  title: '排版与边距',
                  info: '字距 / 段距 / 四边边距',
                  onTap: _openTypographyDialog,
                ),
                const ShadSeparator.horizontal(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                ),
                _buildItem(
                  title: '阅读主题',
                  info: '主题色卡与预览',
                  onTap: _openTheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String title,
    required String info,
    required VoidCallback onTap,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return ShadButton.ghost(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      mainAxisAlignment: MainAxisAlignment.start,
      onPressed: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info,
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: scheme.mutedForeground,
          ),
        ],
      ),
      child: Text(
        title,
        style: theme.textTheme.p.copyWith(
          color: scheme.foreground,
        ),
      ),
    );
  }
}
