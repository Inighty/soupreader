import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';

class ReadingOtherSettingsView extends StatefulWidget {
  const ReadingOtherSettingsView({super.key});

  @override
  State<ReadingOtherSettingsView> createState() =>
      _ReadingOtherSettingsViewState();
}

class _ReadingOtherSettingsViewState extends State<ReadingOtherSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _settings;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent => ReaderSettingsTokens.accent(isDark: _isDark);

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings;
  }

  void _update(ReadingSettings next) {
    setState(() => _settings = next);
    unawaited(_settingsService.saveReadingSettings(next));
  }

  Text _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: ReaderSettingsTokens.titleColor(isDark: _isDark),
        fontSize: ReaderSettingsTokens.sectionTitleSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Text _tileTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: ReaderSettingsTokens.rowTitleColor(isDark: _isDark),
        fontSize: ReaderSettingsTokens.rowTitleSize,
      ),
    );
  }

  Text _tileMeta(String text) {
    return Text(
      text,
      style: TextStyle(
        color: ReaderSettingsTokens.rowMetaColor(isDark: _isDark),
        fontSize: ReaderSettingsTokens.rowMetaSize,
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CupertinoListTile.notched(
      title: _tileTitle(title),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: _accent,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildOptionItem({
    required String title,
    required String info,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile.notched(
      title: _tileTitle(title),
      additionalInfo: _tileMeta(info),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '其他',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: _sectionHeader('阅读行为'),
            children: [
              _buildSwitchItem(
                title: '屏幕常亮',
                value: _settings.keepScreenOn,
                onChanged: (v) => _update(_settings.copyWith(keepScreenOn: v)),
              ),
              _buildOptionItem(
                title: '屏幕方向',
                info:
                    ReaderScreenOrientation.label(_settings.screenOrientation),
                onTap: _pickScreenOrientation,
              ),
              _buildSwitchItem(
                title: '禁用返回键',
                value: _settings.disableReturnKey,
                onChanged: (v) =>
                    _update(_settings.copyWith(disableReturnKey: v)),
              ),
              _buildSwitchItem(
                title: '展开文本菜单',
                value: _settings.expandTextMenu,
                onChanged: (v) =>
                    _update(_settings.copyWith(expandTextMenu: v)),
              ),
              _buildOptionItem(
                title: '自动阅读速度',
                info: '${_settings.autoReadSpeed}s',
                onTap: _pickAutoReadSpeed,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: _sectionHeader('文本处理'),
            children: [
              _buildOptionItem(
                title: '简繁转换',
                info:
                    ChineseConverterType.label(_settings.chineseConverterType),
                onTap: _pickChineseConverterType,
              ),
              _buildSwitchItem(
                title: '净化章节标题',
                value: _settings.cleanChapterTitle,
                onChanged: (v) =>
                    _update(_settings.copyWith(cleanChapterTitle: v)),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickAutoReadSpeed() async {
    final controller =
        TextEditingController(text: _settings.autoReadSpeed.toString());
    final result = await showCupertinoBottomDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('自动阅读速度'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '1 - 120（秒/页）',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('确定'),
            onPressed: () {
              final raw = int.tryParse(controller.text.trim());
              Navigator.pop(context, raw);
            },
          ),
        ],
      ),
    );
    if (result == null) return;
    _update(_settings.copyWith(autoReadSpeed: result.clamp(1, 120)));
  }

  Future<void> _pickChineseConverterType() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '简繁转换',
      currentValue: _settings.chineseConverterType,
      items: [
        for (final mode in ChineseConverterType.values)
          OptionPickerItem<int>(
            value: mode,
            label: ChineseConverterType.label(mode),
          ),
      ],
    );
    if (selected == null) return;
    _update(_settings.copyWith(chineseConverterType: selected));
  }

  Future<void> _pickScreenOrientation() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '屏幕方向',
      currentValue: _settings.screenOrientation,
      items: [
        for (final mode in ReaderScreenOrientation.values)
          OptionPickerItem<int>(
            value: mode,
            label: ReaderScreenOrientation.label(mode),
          ),
      ],
    );
    if (selected == null) return;
    _update(_settings.copyWith(screenOrientation: selected));
  }
}
