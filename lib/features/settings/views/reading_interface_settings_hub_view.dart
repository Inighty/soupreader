import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/typography_settings_dialog.dart';
import 'reading_preferences_view.dart';
import 'reading_tip_settings_view.dart';

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

  Future<void> _openTipSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingTipSettingsView(),
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
    return AppCupertinoPageScaffold(
      title: '阅读界面样式',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('阅读样式与排版'),
            children: [
              _buildItem(
                title: '样式与排版',
                description: '字体 / 排版',
                onTap: _openPreferences,
              ),
              _buildItem(
                title: '页眉页脚与标题',
                description: '标题间距 / 内容位 / 分割线',
                onTap: _openTipSettings,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('排版细项'),
            children: [
              _buildItem(
                title: '排版与边距（高级）',
                description: '标题/正文/边距滑杆',
                onTap: _openTypographyDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile.notched(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        description.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}
