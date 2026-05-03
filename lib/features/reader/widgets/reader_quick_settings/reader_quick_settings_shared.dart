import 'package:flutter/cupertino.dart';

import '../../../../app/theme/design_tokens.dart';

class ReaderQuickSettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const ReaderQuickSettingsSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 5),
          child: Text(
            title,
            style: TextStyle(
              color: ReaderSettingsTokens.titleColor(isDark: isDark),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ReaderSettingsTokens.sectionBackground(isDark: isDark),
            borderRadius: BorderRadius.circular(
              ReaderSettingsTokens.sectionRadius,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

class ReaderQuickSettingsSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const ReaderQuickSettingsSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  double _safeMin() => min.isFinite ? min : 0.0;

  double _safeMax() {
    final safeMin = _safeMin();
    return max.isFinite && max > safeMin ? max : safeMin + 1.0;
  }

  double _safeValue() {
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeRaw = value.isFinite ? value : safeMin;
    return safeRaw.clamp(safeMin, safeMax).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeValue = _safeValue();
    final canSlide = min.isFinite && max.isFinite && max > min;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(
                color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
                fontSize: ReaderSettingsTokens.rowMetaSize,
              ),
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: safeValue,
              min: safeMin,
              max: safeMax,
              activeColor: ReaderSettingsTokens.accent(isDark: isDark),
              onChanged: canSlide ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              format(safeValue),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: ReaderSettingsTokens.rowMetaColor(isDark: isDark),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderQuickSettingsSwitchRowData {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ReaderQuickSettingsSwitchRowData({
    required this.label,
    required this.value,
    required this.onChanged,
  });
}

class ReaderQuickSettingsSwitchGroup extends StatelessWidget {
  final List<ReaderQuickSettingsSwitchRowData> rows;

  const ReaderQuickSettingsSwitchGroup({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? CupertinoColors.separator.resolveFrom(context).darkColor
        : CupertinoColors.separator.resolveFrom(context).color;
    final activeTrackColor = ReaderSettingsTokens.accent(isDark: isDark);
    final labelColor = ReaderSettingsTokens.rowTitleColor(isDark: isDark);

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rows[i].label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: ReaderSettingsTokens.rowTitleSize,
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: CupertinoSwitch(
                    value: rows[i].value,
                    onChanged: rows[i].onChanged,
                    activeTrackColor: activeTrackColor,
                  ),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1) Container(height: 0.5, color: dividerColor),
        ],
      ],
    );
  }
}

class ReaderQuickSettingsSliderRowData {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const ReaderQuickSettingsSliderRowData({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });
}

class ReaderQuickSettingsSliderGroup extends StatelessWidget {
  final List<ReaderQuickSettingsSliderRowData> rows;

  const ReaderQuickSettingsSliderGroup({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? CupertinoColors.separator.resolveFrom(context).darkColor
        : CupertinoColors.separator.resolveFrom(context).color;

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          ReaderQuickSettingsSliderRow(
            label: rows[i].label,
            value: rows[i].value,
            min: rows[i].min,
            max: rows[i].max,
            format: rows[i].format,
            onChanged: rows[i].onChanged,
          ),
          if (i < rows.length - 1) Container(height: 0.5, color: dividerColor),
        ],
      ],
    );
  }
}

class ReaderQuickSettingsModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const ReaderQuickSettingsModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final accent = ReaderSettingsTokens.accent(isDark: isDark);
    final bgNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final baseColor =
        selected ? accent.withValues(alpha: isDark ? 0.18 : 0.12) : bgNormal;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: AppDesignTokens.motionQuick,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
            border: selected
                ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? accent
                  : ReaderSettingsTokens.rowMetaColor(isDark: isDark),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderQuickSettingsLinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const ReaderQuickSettingsLinkRow({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final chevronColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.25)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
                  fontSize: ReaderSettingsTokens.rowTitleSize,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: chevronColor,
            ),
          ],
        ),
      ),
    );
  }
}
