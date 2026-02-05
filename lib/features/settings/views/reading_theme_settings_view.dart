import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';

class ReadingThemeSettingsView extends StatefulWidget {
  const ReadingThemeSettingsView({super.key});

  @override
  State<ReadingThemeSettingsView> createState() =>
      _ReadingThemeSettingsViewState();
}

class _ReadingThemeSettingsViewState extends State<ReadingThemeSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings;
  }

  void _updateThemeIndex(int index) {
    final next = _settings.copyWith(themeIndex: index);
    setState(() => _settings = next);
    unawaited(_settingsService.saveReadingSettings(next));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('阅读主题'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('选择主题'),
              children: AppColors.readingThemes.asMap().entries.map((entry) {
                final index = entry.key;
                final theme = entry.value;
                final selected = index == _settings.themeIndex;
                return CupertinoListTile.notched(
                  title: Text(theme.name),
                  trailing: selected
                      ? const Icon(
                          CupertinoIcons.checkmark,
                          color: CupertinoColors.activeBlue,
                          size: 18,
                        )
                      : null,
                  onTap: () => _updateThemeIndex(index),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

