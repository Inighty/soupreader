import 'package:flutter/cupertino.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../models/reading_settings.dart';
import 'reader_quick_settings_shared.dart';

class ReaderInterfaceTab extends StatelessWidget {
  final ReadingSettings settings;
  final List<ReadingThemeColors> themes;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const ReaderInterfaceTab({
    super.key,
    required this.settings,
    required this.themes,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        ReaderQuickSettingsSection(
          title: '亮度',
          child: Column(
            children: [
              ReaderQuickSettingsSwitchGroup(
                rows: [
                  ReaderQuickSettingsSwitchRowData(
                    label: '跟随系统',
                    value: settings.useSystemBrightness,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(useSystemBrightness: v),
                    ),
                  ),
                ],
              ),
              const _BrightnessDivider(),
              const SizedBox(height: 4),
              IgnorePointer(
                ignoring: settings.useSystemBrightness,
                child: Opacity(
                  opacity: settings.useSystemBrightness ? 0.4 : 1.0,
                  child: ReaderQuickSettingsSliderRow(
                    label: '亮度',
                    value: settings.brightness,
                    min: 0.05,
                    max: 1.0,
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(brightness: v),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ReaderQuickSettingsSection(
          title: '主题',
          child: _ThemeGrid(
            themes: themes,
            selectedIndex: settings.themeIndex,
            onSelected: (index) => onSettingsChanged(
              settings.copyWith(themeIndex: index),
            ),
          ),
        ),
        ReaderQuickSettingsSection(
          title: '内容边距',
          child: ReaderQuickSettingsSliderGroup(
            rows: [
              _paddingRow(
                label: '上边',
                value: settings.paddingTop,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(paddingTop: v, marginVertical: v),
                ),
              ),
              _paddingRow(
                label: '下边',
                value: settings.paddingBottom,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(paddingBottom: v, marginVertical: v),
                ),
              ),
              _paddingRow(
                label: '左边',
                value: settings.paddingLeft,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(paddingLeft: v, marginHorizontal: v),
                ),
              ),
              _paddingRow(
                label: '右边',
                value: settings.paddingRight,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(paddingRight: v, marginHorizontal: v),
                ),
              ),
            ],
          ),
        ),
        ReaderQuickSettingsSection(
          title: '页眉页脚',
          child: ReaderQuickSettingsSwitchGroup(
            rows: [
              ReaderQuickSettingsSwitchRowData(
                label: '隐藏页眉',
                value: settings.hideHeader,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(hideHeader: v),
                ),
              ),
              ReaderQuickSettingsSwitchRowData(
                label: '隐藏页脚',
                value: settings.hideFooter,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(hideFooter: v),
                ),
              ),
              ReaderQuickSettingsSwitchRowData(
                label: '页眉分割线',
                value: settings.showHeaderLine,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(showHeaderLine: v),
                ),
              ),
              ReaderQuickSettingsSwitchRowData(
                label: '页脚分割线',
                value: settings.showFooterLine,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(showFooterLine: v),
                ),
              ),
            ],
          ),
        ),
        ReaderQuickSettingsSection(
          title: '状态栏',
          child: ReaderQuickSettingsSwitchGroup(
            rows: [
              ReaderQuickSettingsSwitchRowData(
                label: '显示状态栏',
                value: settings.showStatusBar,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(showStatusBar: v),
                ),
              ),
              ReaderQuickSettingsSwitchRowData(
                label: '显示时间',
                value: settings.showTime,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(showTime: v),
                ),
              ),
              ReaderQuickSettingsSwitchRowData(
                label: '显示进度',
                value: settings.showProgress,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(showProgress: v),
                ),
              ),
              ReaderQuickSettingsSwitchRowData(
                label: '显示电量',
                value: settings.showBattery,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(showBattery: v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  ReaderQuickSettingsSliderRowData _paddingRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return ReaderQuickSettingsSliderRowData(
      label: label,
      value: value,
      min: 0,
      max: 80,
      format: (v) => v.round().toString(),
      onChanged: onChanged,
    );
  }
}

class _BrightnessDivider extends StatelessWidget {
  const _BrightnessDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Container(
      height: 0.5,
      color: isDark
          ? CupertinoColors.separator.resolveFrom(context).darkColor
          : CupertinoColors.separator.resolveFrom(context).color,
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  final List<ReadingThemeColors> themes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ThemeGrid({
    required this.themes,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final safeSelected =
        selectedIndex >= 0 && selectedIndex < themes.length ? selectedIndex : 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 360 ? 4 : 3;
        final itemWidth = (width - (crossAxisCount - 1) * 10) / crossAxisCount;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < themes.length; i++)
              SizedBox(
                width: itemWidth,
                height: 54,
                child: _ThemeCell(
                  theme: themes[i],
                  label: themes[i].name,
                  selected: i == safeSelected,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeCell extends StatelessWidget {
  final ReadingThemeColors theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCell({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final accent = ReaderSettingsTokens.accent(isDark: isDark);
    final borderColor =
        selected ? accent : ReaderSettingsTokens.sectionBorder(isDark: isDark);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: AppDesignTokens.motionQuick,
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: borderColor, width: selected ? 2.0 : 0.5),
          boxShadow: selected ? [_selectionShadow(accent)] : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.text.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) _SelectedThemeCheck(accent: accent),
          ],
        ),
      ),
    );
  }

  BoxShadow _selectionShadow(Color accent) {
    return BoxShadow(
      color: accent.withValues(alpha: 0.25),
      blurRadius: 6,
      offset: const Offset(0, 2),
    );
  }
}

class _SelectedThemeCheck extends StatelessWidget {
  final Color accent;

  const _SelectedThemeCheck({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: const Icon(
          CupertinoIcons.checkmark,
          color: CupertinoColors.white,
          size: 10,
        ),
      ),
    );
  }
}
