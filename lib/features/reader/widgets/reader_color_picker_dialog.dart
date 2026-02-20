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
  static const List<int> _presetColors = <int>[
    0xFF000000,
    0xFF333333,
    0xFF666666,
    0xFF999999,
    0xFFCCCCCC,
    0xFFFFFFFF,
    0xFFE53935,
    0xFFF4511E,
    0xFFFFB300,
    0xFFFDD835,
    0xFF43A047,
    0xFF00897B,
    0xFF00ACC1,
    0xFF1E88E5,
    0xFF3949AB,
    0xFF8E24AA,
    0xFFD81B60,
    0xFF6D4C41,
    0xFF546E7A,
    0xFF015A86,
    0xFFFDF6E3,
    0xFFADADAD,
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
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;
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
                _buildPresetGrid(color),
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

  Widget _buildPresetGrid(Color currentColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetColors.map((value) {
        final color = Color(value);
        final selected =
            (currentColor.value & 0x00FFFFFF) == (color.value & 0x00FFFFFF);
        return GestureDetector(
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
    if (text.length != 6) return null;
    final rgb = int.tryParse(text, radix: 16);
    if (rgb == null) return null;
    return 0xFF000000 | rgb;
  }

  String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }
}
