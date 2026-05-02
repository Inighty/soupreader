import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';

/// 提示项选项数据。
class TipOption {
  final int value;
  final String label;

  const TipOption(this.value, this.label);
}

/// 阅读提示设置中的滑杆+数值显示行。
class ReadingTipSliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String display;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const ReadingTipSliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.activeColor,
    required this.onChanged,
  });

  double _safeMin() => min.isFinite ? min : 0.0;

  double _safeMax() {
    final safeMin = _safeMin();
    return max.isFinite && max > safeMin ? max : safeMin + 1.0;
  }

  double _safeSliderValue() {
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
    final safeValue = _safeSliderValue();
    final canSlide = min.isFinite && max.isFinite && max > min;

    return CupertinoListTile(
      title: Text(
        title,
        style: TextStyle(
          color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
          fontSize: ReaderSettingsTokens.rowTitleSize,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoSlider(
          value: safeValue,
          min: safeMin,
          max: safeMax,
          activeColor: activeColor,
          onChanged: canSlide ? onChanged : null,
        ),
      ),
      additionalInfo: Text(
        display,
        style: TextStyle(
          color: ReaderSettingsTokens.rowMetaColor(isDark: isDark),
          fontSize: ReaderSettingsTokens.rowMetaSize,
        ),
      ),
    );
  }
}
