import 'package:flutter/cupertino.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../app/theme/typography.dart';
import '../../models/reading_settings.dart';
import 'reader_quick_settings_shared.dart';

class ReaderTypographyTab extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const ReaderTypographyTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        ReaderQuickSettingsSection(
          title: '字体',
          child: _FontFamilyRow(
            fontFamilyIndex: settings.fontFamilyIndex,
            onChanged: (index) => onSettingsChanged(
              settings.copyWith(fontFamilyIndex: index),
            ),
          ),
        ),
        ReaderQuickSettingsSection(
          title: '字号与间距',
          child: ReaderQuickSettingsSliderGroup(
            rows: [
              ReaderQuickSettingsSliderRowData(
                label: '字号',
                value: settings.fontSize,
                min: 12,
                max: 30,
                format: (v) => v.toStringAsFixed(0),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(fontSize: v),
                ),
              ),
              ReaderQuickSettingsSliderRowData(
                label: '行距',
                value: settings.lineHeight,
                min: 1.0,
                max: 2.2,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(lineHeight: v),
                ),
              ),
              ReaderQuickSettingsSliderRowData(
                label: '字距',
                value: settings.letterSpacing,
                min: -2.0,
                max: 5.0,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(letterSpacing: v),
                ),
              ),
              ReaderQuickSettingsSliderRowData(
                label: '段距',
                value: settings.paragraphSpacing,
                min: 0,
                max: 18,
                format: (v) => v.toStringAsFixed(0),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(paragraphSpacing: v),
                ),
              ),
            ],
          ),
        ),
        ReaderQuickSettingsSection(
          title: '文字排版',
          child: Column(
            children: [
              ReaderQuickSettingsSwitchGroup(
                rows: [
                  ReaderQuickSettingsSwitchRowData(
                    label: '两端对齐',
                    value: settings.textFullJustify,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(textFullJustify: v),
                    ),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '段首缩进',
                    value: settings.paragraphIndent.isNotEmpty,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(paragraphIndent: v ? '　　' : ''),
                    ),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '底部对齐',
                    value: settings.textBottomJustify,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(textBottomJustify: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TextBoldRow(
                value: settings.textBold,
                onChanged: (v) {
                  onSettingsChanged(settings.copyWith(textBold: v));
                },
              ),
            ],
          ),
        ),
        ReaderQuickSettingsSection(
          title: '边距',
          child: _MarginPresetRow(
            settings: settings,
            onSettingsChanged: onSettingsChanged,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

enum _MarginPreset { narrow, normal, wide }

class _MarginPresetRow extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const _MarginPresetRow({
    required this.settings,
    required this.onSettingsChanged,
  });

  _MarginPreset? _inferPreset() {
    final lr = ((settings.paddingLeft + settings.paddingRight) / 2).round();
    if (lr <= 14) return _MarginPreset.narrow;
    if (lr >= 26) return _MarginPreset.wide;
    return _MarginPreset.normal;
  }

  ReadingSettings _apply(_MarginPreset preset) {
    switch (preset) {
      case _MarginPreset.narrow:
        return settings.copyWith(
          paddingLeft: 12,
          paddingRight: 12,
          paddingTop: 12,
          paddingBottom: 12,
        );
      case _MarginPreset.normal:
        return settings.copyWith(
          paddingLeft: 20,
          paddingRight: 20,
          paddingTop: 16,
          paddingBottom: 16,
        );
      case _MarginPreset.wide:
        return settings.copyWith(
          paddingLeft: 28,
          paddingRight: 28,
          paddingTop: 20,
          paddingBottom: 20,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = _inferPreset() ?? _MarginPreset.normal;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _chip(context, '窄', _MarginPreset.narrow, preset, isDark),
        _chip(context, '标准', _MarginPreset.normal, preset, isDark),
        _chip(context, '宽', _MarginPreset.wide, preset, isDark),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    _MarginPreset value,
    _MarginPreset preset,
    bool isDark,
  ) {
    final selected = preset == value;
    final accent =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
    final chipBg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final textNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => onSettingsChanged(_apply(value)),
      child: AnimatedContainer(
        duration: AppDesignTokens.motionQuick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
              : chipBg,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
          border: selected
              ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : textNormal,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TextBoldRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _TextBoldRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final safeValue = (value == -1 || value == 0 || value == 1) ? value : 0;
    return Row(
      children: [
        Text(
          '字重',
          style: TextStyle(
            color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
            fontSize: ReaderSettingsTokens.rowTitleSize,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: safeValue,
            onValueChanged: (v) {
              if (v == null) return;
              onChanged(v);
            },
            children: const <int, Widget>{
              -1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('细体'),
              ),
              0: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('正常'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('粗体'),
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _FontFamilyRow extends StatelessWidget {
  final int fontFamilyIndex;
  final ValueChanged<int> onChanged;

  const _FontFamilyRow({
    required this.fontFamilyIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = (fontFamilyIndex >= 0 &&
            fontFamilyIndex < ReadingFontFamily.presets.length)
        ? fontFamilyIndex
        : 0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < ReadingFontFamily.presets.length; i++)
          ReaderQuickSettingsModeChip(
            label: ReadingFontFamily.presets[i].name,
            selected: safeIndex == i,
            disabled: false,
            onTap: () => onChanged(i),
          ),
      ],
    );
  }
}
