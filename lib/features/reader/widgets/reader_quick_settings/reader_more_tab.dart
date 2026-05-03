import 'package:flutter/cupertino.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../models/reading_settings.dart';
import 'reader_quick_settings_shared.dart';

class ReaderMoreTab extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onOpenFullSettings;

  const ReaderMoreTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onOpenFullSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        ReaderQuickSettingsSection(
          title: '其他',
          child: Column(
            children: [
              ReaderQuickSettingsSwitchGroup(
                rows: [
                  ReaderQuickSettingsSwitchRowData(
                    label: '屏幕常亮',
                    value: settings.keepLightSeconds ==
                        ReadingSettings.keepLightAlways,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(
                        keepLightSeconds: v
                            ? ReadingSettings.keepLightAlways
                            : ReadingSettings.keepLightFollowSystem,
                      ),
                    ),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '净化章节标题',
                    value: settings.cleanChapterTitle,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(cleanChapterTitle: v),
                    ),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '章节跳转确认',
                    value: settings.confirmSkipChapter,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(confirmSkipChapter: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ChineseConverterTypeRow(
                currentType: settings.chineseConverterType,
                onChanged: (value) => onSettingsChanged(
                  settings.copyWith(chineseConverterType: value),
                ),
              ),
            ],
          ),
        ),
        ReaderQuickSettingsSection(
          title: '屏幕方向',
          child: _ScreenOrientationRow(
            value: settings.screenOrientation,
            onChanged: (v) => onSettingsChanged(
              settings.copyWith(screenOrientation: v),
            ),
          ),
        ),
        ReaderQuickSettingsSection(
          title: '高级',
          child: ReaderQuickSettingsLinkRow(
            label: '完整阅读设置',
            onTap: onOpenFullSettings,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _ChineseConverterTypeRow extends StatelessWidget {
  final int currentType;
  final ValueChanged<int> onChanged;

  const _ChineseConverterTypeRow({
    required this.currentType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final safeType = ChineseConverterType.values.contains(currentType)
        ? currentType
        : ChineseConverterType.off;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '简繁转换',
          style: TextStyle(
            color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
            fontSize: ReaderSettingsTokens.rowTitleSize,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: safeType,
          backgroundColor: isDark
              ? CupertinoColors.white.withValues(alpha: 0.08)
              : CupertinoColors.systemGroupedBackground.resolveFrom(context),
          thumbColor: ReaderSettingsTokens.accent(isDark: isDark),
          onValueChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
          children: {
            for (final mode in ChineseConverterType.values)
              mode: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  ChineseConverterType.label(mode),
                  style: TextStyle(
                    color: isDark
                        ? CupertinoColors.white.withValues(alpha: 0.84)
                        : ReaderSettingsTokens.rowTitleColor(isDark: isDark),
                    fontSize: 12,
                  ),
                ),
              ),
          },
        ),
      ],
    );
  }
}

class _ScreenOrientationRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ScreenOrientationRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = _supportedValues.contains(value)
        ? value
        : ReadingSettings.screenOrientationUnspecified;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: safeValue,
        padding: const EdgeInsets.all(3),
        onValueChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
        children: const <int, Widget>{
          ReadingSettings.screenOrientationUnspecified: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('跟随', textAlign: TextAlign.center),
          ),
          ReadingSettings.screenOrientationPortrait: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('竖屏', textAlign: TextAlign.center),
          ),
          ReadingSettings.screenOrientationLandscape: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('横屏', textAlign: TextAlign.center),
          ),
          ReadingSettings.screenOrientationSensor: Padding(
            padding: EdgeInsets.symmetric(vertical: 7),
            child: Text('传感器', textAlign: TextAlign.center),
          ),
        },
      ),
    );
  }

  static const List<int> _supportedValues = <int>[
    ReadingSettings.screenOrientationUnspecified,
    ReadingSettings.screenOrientationPortrait,
    ReadingSettings.screenOrientationLandscape,
    ReadingSettings.screenOrientationSensor,
  ];
}
