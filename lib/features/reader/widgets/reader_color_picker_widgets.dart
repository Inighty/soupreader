import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'reader_color_picker_helpers.dart';

/// HSV 取色板：上下控制 V，左右控制 S；点击/拖拽都更新。
class ReaderColorSvPanel extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<({double saturation, double value})> onChanged;

  const ReaderColorSvPanel({
    super.key,
    required this.hsv,
    required this.onChanged,
  });

  void _update(Offset localPosition, Size panelSize) {
    final width = panelSize.width <= 0 ? 1.0 : panelSize.width;
    final height = panelSize.height <= 0 ? 1.0 : panelSize.height;
    final saturation = (localPosition.dx / width).clamp(0.0, 1.0);
    final value = 1 - (localPosition.dy / height).clamp(0.0, 1.0);
    onChanged((saturation: saturation, value: value));
  }

  @override
  Widget build(BuildContext context) {
    const panelSize = Size(
      kReaderColorPickerPanelWidth,
      kReaderColorPickerSvPanelHeight,
    );
    final saturation = hsv.saturation.clamp(0.0, 1.0);
    final value = hsv.value.clamp(0.0, 1.0);
    final dotX =
        (saturation * panelSize.width).clamp(0.0, panelSize.width).toDouble();
    final dotY = ((1 - value) * panelSize.height)
        .clamp(0.0, panelSize.height)
        .toDouble();
    const markerRadius = 8.0;
    final markerLeft = (dotX - markerRadius)
        .clamp(0.0, math.max(0.0, panelSize.width - 16))
        .toDouble();
    final markerTop = (dotY - markerRadius)
        .clamp(0.0, math.max(0.0, panelSize.height - 16))
        .toDouble();

    return GestureDetector(
      key: const Key('reader_color_sv_board'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _update(details.localPosition, panelSize),
      onPanDown: (details) => _update(details.localPosition, panelSize),
      onPanUpdate: (details) => _update(details.localPosition, panelSize),
      child: SizedBox(
        width: panelSize.width,
        height: panelSize.height,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.8,
                ),
                color: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xFF000000)],
                ),
              ),
            ),
            Positioned(
              left: markerLeft,
              top: markerTop,
              child: Container(
                width: markerRadius * 2,
                height: markerRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: CupertinoColors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 色相条：水平拖动调整 hue。
class ReaderColorHueSlider extends StatelessWidget {
  final HSVColor hsv;
  final Color currentColor;
  final ValueChanged<double> onHueChanged;

  const ReaderColorHueSlider({
    super.key,
    required this.hsv,
    required this.currentColor,
    required this.onHueChanged,
  });

  void _update(Offset localPosition, double width) {
    final safeWidth = width <= 0 ? 1.0 : width;
    final hue = (localPosition.dx / safeWidth).clamp(0.0, 1.0) * 360;
    onHueChanged(hue);
  }

  @override
  Widget build(BuildContext context) {
    const sliderWidth = kReaderColorPickerPanelWidth;
    final normalizedHue = (hsv.hue / 360).clamp(0.0, 1.0);
    final dotX = normalizedHue * sliderWidth;
    final markerLeft =
        (dotX - 9).clamp(0.0, math.max(0.0, sliderWidth - 18)).toDouble();

    return GestureDetector(
      key: const Key('reader_color_hue_slider'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _update(details.localPosition, sliderWidth),
      onHorizontalDragStart: (details) =>
          _update(details.localPosition, sliderWidth),
      onHorizontalDragUpdate: (details) =>
          _update(details.localPosition, sliderWidth),
      child: SizedBox(
        width: sliderWidth,
        height: kReaderColorPickerHueTrackHeight + 12,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: kReaderColorPickerHueTrackHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.8,
                ),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
            ),
            Positioned(
              left: markerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentColor,
                  border: Border.all(color: CupertinoColors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HSV 信息小芯片（H/S/V 三个 chip）。
class ReaderColorHsvSummary extends StatelessWidget {
  final HSVColor hsv;

  const ReaderColorHsvSummary({super.key, required this.hsv});

  Widget _chip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.6,
        ),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = hsv.hue.round();
    final s = (hsv.saturation * 100).round();
    final v = (hsv.value * 100).round();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip(context, 'H', '$h°'),
        _chip(context, 'S', '$s%'),
        _chip(context, 'V', '$v%'),
      ],
    );
  }
}

/// 色板分组（"最近使用"/"常用预设"），点击设置当前颜色。
class ReaderColorSection extends StatelessWidget {
  final String label;
  final List<int> colors;
  final Color currentColor;
  final String keyPrefix;
  final ValueChanged<Color> onSelected;

  const ReaderColorSection({
    super.key,
    required this.label,
    required this.colors,
    required this.currentColor,
    required this.keyPrefix,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: colors.map((value) {
            final color = Color(0xFF000000 | (value & 0x00FFFFFF));
            final selected = (currentColor.toARGB32() & 0x00FFFFFF) ==
                (color.toARGB32() & 0x00FFFFFF);
            final keyHex = readerColorPickerHexRgb(color.toARGB32());
            return GestureDetector(
              key: Key('${keyPrefix}_$keyHex'),
              onTap: () => onSelected(color),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? CupertinoColors.activeBlue.resolveFrom(context)
                        : CupertinoColors.separator.resolveFrom(context),
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
