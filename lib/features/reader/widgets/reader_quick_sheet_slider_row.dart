import 'package:flutter/cupertino.dart';

/// 快速面板里的"行距/字距/段距/字号"等通用滑杆行：标签 + 滑杆 + 数值。
class ReaderQuickSheetSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color labelColor;
  final Color metaColor;
  final Color accent;
  final ValueChanged<double> onChanged;
  final String Function(double value) formatValue;
  final double valueWidth;

  const ReaderQuickSheetSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.labelColor,
    required this.metaColor,
    required this.accent,
    required this.onChanged,
    required this.formatValue,
    this.valueWidth = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoSlider(
                value: value,
                min: min,
                max: max,
                activeColor: accent,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: valueWidth,
              child: Text(
                formatValue(value),
                textAlign: TextAlign.end,
                style: TextStyle(color: metaColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
