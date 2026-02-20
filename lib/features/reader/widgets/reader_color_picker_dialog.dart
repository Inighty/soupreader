import 'package:flutter/cupertino.dart';

Future<int?> showReaderColorPickerDialog({
  required BuildContext context,
  required String title,
  required int initialColor,
  String hexPlaceholder = '输入 6 位十六进制，如 FF6600',
  String invalidHexMessage = '请输入 6 位十六进制颜色（如 FF6600）',
}) {
  final safeInitialColor = 0xFF000000 | (initialColor & 0x00FFFFFF);
  return showCupertinoDialog<int>(
    context: context,
    builder: (dialogContext) => _ReaderColorPickerDialog(
      title: title,
      initialColor: safeInitialColor,
      hexPlaceholder: hexPlaceholder,
      invalidHexMessage: invalidHexMessage,
    ),
  );
}

class _ReaderColorPickerDialog extends StatefulWidget {
  final String title;
  final int initialColor;
  final String hexPlaceholder;
  final String invalidHexMessage;

  const _ReaderColorPickerDialog({
    required this.title,
    required this.initialColor,
    required this.hexPlaceholder,
    required this.invalidHexMessage,
  });

  @override
  State<_ReaderColorPickerDialog> createState() =>
      _ReaderColorPickerDialogState();
}

class _ReaderColorPickerDialogState extends State<_ReaderColorPickerDialog> {
  static const int _maxRecentColors = 16;
  static final List<int> _recentColors = <int>[];

  static const List<_ColorPaletteGroup> _paletteGroups = <_ColorPaletteGroup>[
    _ColorPaletteGroup('中性色', <int>[
      0xFF000000,
      0xFF1F1F1F,
      0xFF333333,
      0xFF4D4D4D,
      0xFF666666,
      0xFF808080,
      0xFF999999,
      0xFFB3B3B3,
      0xFFCCCCCC,
      0xFFE6E6E6,
      0xFFF2F2F2,
      0xFFFFFFFF,
    ]),
    _ColorPaletteGroup('暖色', <int>[
      0xFF7F0000,
      0xFFB71C1C,
      0xFFD32F2F,
      0xFFE53935,
      0xFFF4511E,
      0xFFFF6F00,
      0xFFFF8F00,
      0xFFFFA000,
      0xFFFFB300,
      0xFFFFC107,
      0xFFFDD835,
      0xFFFFE082,
    ]),
    _ColorPaletteGroup('冷色', <int>[
      0xFF0D47A1,
      0xFF1565C0,
      0xFF1E88E5,
      0xFF42A5F5,
      0xFF00ACC1,
      0xFF00897B,
      0xFF00796B,
      0xFF00695C,
      0xFF3949AB,
      0xFF5E35B1,
      0xFF7E57C2,
      0xFF9575CD,
    ]),
    _ColorPaletteGroup('自然色', <int>[
      0xFF1B5E20,
      0xFF2E7D32,
      0xFF388E3C,
      0xFF43A047,
      0xFF558B2F,
      0xFF689F38,
      0xFF827717,
      0xFF9E9D24,
      0xFFAFB42B,
      0xFFC0CA33,
      0xFFD4E157,
      0xFFE6EE9C,
    ]),
    _ColorPaletteGroup('阅读常用', <int>[
      0xFF015A86,
      0xFF1A3A4A,
      0xFF2F4F4F,
      0xFF5D4037,
      0xFF6D4C41,
      0xFF8D6E63,
      0xFFA1887F,
      0xFFBCAAA4,
      0xFFFDF6E3,
      0xFFFAF3DD,
      0xFFF5ECD7,
      0xFFEAE0C8,
    ]),
  ];

  late HSVColor _hsvColor;
  late TextEditingController _hexController;
  String? _errorText;
  bool _suppressHexListener = false;

  @override
  void initState() {
    super.initState();
    final initial = Color(widget.initialColor);
    _hsvColor = HSVColor.fromColor(initial);
    _hexController = TextEditingController(text: _hexRgb(initial.value));
    _hexController.addListener(_onHexChanged);
  }

  @override
  void dispose() {
    _hexController
      ..removeListener(_onHexChanged)
      ..dispose();
    super.dispose();
  }

  Color get _currentColor => _hsvColor.toColor();

  void _setColor(Color color) {
    final next = HSVColor.fromColor(color);
    final hex = _hexRgb(color.value);
    setState(() {
      _hsvColor = HSVColor.fromAHSV(
        1,
        next.hue,
        next.saturation.clamp(0, 1),
        next.value.clamp(0, 1),
      );
      _errorText = null;
    });
    _setHexText(hex);
  }

  void _setHexText(String hex) {
    _suppressHexListener = true;
    _hexController.value = _hexController.value.copyWith(
      text: hex,
      selection: TextSelection.collapsed(offset: hex.length),
      composing: TextRange.empty,
    );
    _suppressHexListener = false;
  }

  void _onHexChanged() {
    if (_suppressHexListener) return;
    final parsed = _parseRgb(_hexController.text);
    if (parsed == null) {
      if (_errorText != null) {
        setState(() => _errorText = null);
      }
      return;
    }
    final next = HSVColor.fromColor(Color(parsed));
    setState(() {
      _hsvColor = next;
      _errorText = null;
    });
  }

  void _updateHsv({
    double? hue,
    double? saturation,
    double? value,
  }) {
    final next = HSVColor.fromAHSV(
      1,
      (hue ?? _hsvColor.hue).clamp(0, 360),
      (saturation ?? _hsvColor.saturation).clamp(0, 1),
      (value ?? _hsvColor.value).clamp(0, 1),
    );
    final color = next.toColor();
    setState(() {
      _hsvColor = next;
      _errorText = null;
    });
    _setHexText(_hexRgb(color.value));
  }

  void _confirm() {
    final parsed = _parseRgb(_hexController.text);
    if (parsed == null) {
      setState(() => _errorText = widget.invalidHexMessage);
      return;
    }
    _rememberRecentColor(parsed);
    Navigator.pop(context, parsed);
  }

  void _rememberRecentColor(int color) {
    final normalized = 0xFF000000 | (color & 0x00FFFFFF);
    _recentColors.removeWhere((item) => (item & 0x00FFFFFF) == normalized);
    _recentColors.insert(0, normalized);
    if (_recentColors.length > _maxRecentColors) {
      _recentColors.removeRange(_maxRecentColors, _recentColors.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;
    final rgb = color.value & 0x00FFFFFF;
    final red = (rgb >> 16) & 0xFF;
    final green = (rgb >> 8) & 0xFF;
    final blue = rgb & 0xFF;
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: 260,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreview(color),
                const SizedBox(height: 12),
                if (_recentColors.isNotEmpty) ...[
                  _buildColorSection('最近使用', _recentColors, color),
                  const SizedBox(height: 8),
                ],
                for (final group in _paletteGroups) ...[
                  _buildColorSection(group.label, group.colors, color),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),
                _buildSliderRow(
                  label: 'R',
                  value: red.toDouble(),
                  min: 0,
                  max: 255,
                  text: red.toString(),
                  onChanged: (v) => _setColor(
                    Color.fromARGB(
                      255,
                      v.round().clamp(0, 255),
                      green,
                      blue,
                    ),
                  ),
                ),
                _buildSliderRow(
                  label: 'G',
                  value: green.toDouble(),
                  min: 0,
                  max: 255,
                  text: green.toString(),
                  onChanged: (v) => _setColor(
                    Color.fromARGB(
                      255,
                      red,
                      v.round().clamp(0, 255),
                      blue,
                    ),
                  ),
                ),
                _buildSliderRow(
                  label: 'B',
                  value: blue.toDouble(),
                  min: 0,
                  max: 255,
                  text: blue.toString(),
                  onChanged: (v) => _setColor(
                    Color.fromARGB(
                      255,
                      red,
                      green,
                      v.round().clamp(0, 255),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSliderRow(
                  label: '色相',
                  value: _hsvColor.hue,
                  min: 0,
                  max: 360,
                  text: _hsvColor.hue.round().toString(),
                  onChanged: (v) => _updateHsv(hue: v),
                ),
                _buildSliderRow(
                  label: '饱和',
                  value: _hsvColor.saturation,
                  min: 0,
                  max: 1,
                  text: '${(_hsvColor.saturation * 100).round()}%',
                  onChanged: (v) => _updateHsv(saturation: v),
                ),
                _buildSliderRow(
                  label: '明度',
                  value: _hsvColor.value,
                  min: 0,
                  max: 1,
                  text: '${(_hsvColor.value * 100).round()}%',
                  onChanged: (v) => _updateHsv(value: v),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: _hexController,
                  textCapitalization: TextCapitalization.characters,
                  placeholder: widget.hexPlaceholder,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('#'),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _confirm,
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildPreview(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: CupertinoColors.separator,
                width: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('#${_hexRgb(color.value)}'),
        ],
      ),
    );
  }

  Widget _buildColorSection(
    String label,
    List<int> colors,
    Color currentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: colors.map((value) {
            final color = Color(value);
            final selected =
                (currentColor.value & 0x00FFFFFF) == (color.value & 0x00FFFFFF);
            return GestureDetector(
              key: Key('reader_color_${_hexRgb(color.value)}'),
              onTap: () => _setColor(color),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.separator,
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

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String text,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  int? _parseRgb(String raw) {
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
      // 支持 AARRGGBB 输入，但对齐 legado 语义只保留 RGB。
      text = text.substring(2);
    }
    if (text.length != 6) return null;
    final rgb = int.tryParse(text, radix: 16);
    if (rgb == null) return null;
    return 0xFF000000 | (rgb & 0x00FFFFFF);
  }

  String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }
}

class _ColorPaletteGroup {
  final String label;
  final List<int> colors;

  const _ColorPaletteGroup(this.label, this.colors);
}
