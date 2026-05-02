import 'package:flutter/widgets.dart';

/// 取色器对话框默认预设色板。
const List<int> kReaderColorPickerPresets = <int>[
  0xFF000000,
  0xFF333333,
  0xFF666666,
  0xFF999999,
  0xFFCCCCCC,
  0xFFFFFFFF,
  0xFF7F0000,
  0xFFD32F2F,
  0xFFFF6F00,
  0xFFFFA000,
  0xFFFDD835,
  0xFF1B5E20,
  0xFF2E7D32,
  0xFF00897B,
  0xFF015A86,
  0xFF1565C0,
  0xFF3949AB,
  0xFF5E35B1,
  0xFF6D4C41,
  0xFF8D6E63,
  0xFFA1887F,
  0xFFFDF6E3,
  0xFFFAF3DD,
  0xFFEAE0C8,
];

/// 已使用色板（进程内缓存）的全局上限。
const int kReaderColorPickerMaxRecent = 16;
const double kReaderColorPickerPanelWidth = 252;
const double kReaderColorPickerSvPanelHeight = 152;
const double kReaderColorPickerHueTrackHeight = 24;

/// 解析 6 位/3 位/8 位十六进制 RGB 输入，返回 0xFFRRGGBB；非法返回 null。
int? readerColorPickerParseRgb(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (text.startsWith('#')) {
    text = text.substring(1);
  }
  if (text.startsWith('0x') || text.startsWith('0X')) {
    text = text.substring(2);
  }
  if (text.length == 3) {
    final r = text[0];
    final g = text[1];
    final b = text[2];
    text = '$r$r$g$g$b$b';
  }
  if (text.length == 8) {
    text = text.substring(2);
  }
  if (text.length != 6) return null;
  final rgb = int.tryParse(text, radix: 16);
  if (rgb == null) return null;
  return 0xFF000000 | (rgb & 0x00FFFFFF);
}

/// 将颜色值的 RGB 部分格式化为 6 位大写十六进制字符串。
String readerColorPickerHexRgb(int colorValue) {
  final rgb = colorValue & 0x00FFFFFF;
  return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
}

/// 将颜色加入"最近使用"缓存（去重并保留最近 N 个）。
void readerColorPickerRememberRecent(List<int> recent, int color) {
  final normalized = 0xFF000000 | (color & 0x00FFFFFF);
  recent.removeWhere(
    (item) => (item & 0x00FFFFFF) == (normalized & 0x00FFFFFF),
  );
  recent.insert(0, normalized);
  if (recent.length > kReaderColorPickerMaxRecent) {
    recent.removeRange(kReaderColorPickerMaxRecent, recent.length);
  }
}

/// 用于跟踪对话框内的 HSV 颜色状态包。
class HsvCallbackPayload {
  final double hue;
  final double saturation;
  final double value;

  const HsvCallbackPayload({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  HSVColor toHsvColor() => HSVColor.fromAHSV(1, hue, saturation, value);
}
