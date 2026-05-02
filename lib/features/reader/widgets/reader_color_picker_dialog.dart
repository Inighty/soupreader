import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'reader_color_picker_helpers.dart';
import 'reader_color_picker_widgets.dart';

Future<int?> showReaderColorPickerDialog({
  required BuildContext context,
  required String title,
  required int initialColor,
  String hexPlaceholder = '输入 6 位十六进制，如 FF6600',
  String invalidHexMessage = '请输入 6 位十六进制颜色（如 FF6600）',
}) {
  final safeInitialColor = 0xFF000000 | (initialColor & 0x00FFFFFF);
  return showCupertinoBottomSheetDialog<int>(
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
  static final List<int> _recentColors = <int>[];

  late HSVColor _hsvColor;
  late final int _originalColor;
  late TextEditingController _hexController;
  String? _errorText;
  bool _suppressHexListener = false;

  @override
  void initState() {
    super.initState();
    final initial = Color(widget.initialColor);
    _originalColor = initial.toARGB32();
    _hsvColor = HSVColor.fromColor(initial);
    _hexController = TextEditingController(
      text: readerColorPickerHexRgb(initial.toARGB32()),
    );
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
    final hex = readerColorPickerHexRgb(color.toARGB32());
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
    final parsed = readerColorPickerParseRgb(_hexController.text);
    if (parsed == null) {
      if (_errorText != null) {
        setState(() => _errorText = null);
      }
      return;
    }
    final next = HSVColor.fromColor(Color(parsed));
    setState(() {
      _hsvColor = HSVColor.fromAHSV(
        1,
        next.hue,
        next.saturation.clamp(0, 1),
        next.value.clamp(0, 1),
      );
      _errorText = null;
    });
  }

  void _updateHsv({double? hue, double? saturation, double? value}) {
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
    _setHexText(readerColorPickerHexRgb(color.toARGB32()));
  }

  void _confirm() {
    final parsed = readerColorPickerParseRgb(_hexController.text);
    if (parsed == null) {
      setState(() => _errorText = widget.invalidHexMessage);
      return;
    }
    readerColorPickerRememberRecent(_recentColors, parsed);
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreview(currentColor),
                const SizedBox(height: 10),
                ReaderColorSvPanel(
                  hsv: _hsvColor,
                  onChanged: (e) =>
                      _updateHsv(saturation: e.saturation, value: e.value),
                ),
                const SizedBox(height: 10),
                ReaderColorHueSlider(
                  hsv: _hsvColor,
                  currentColor: currentColor,
                  onHueChanged: (h) => _updateHsv(hue: h),
                ),
                const SizedBox(height: 8),
                ReaderColorHsvSummary(hsv: _hsvColor),
                const SizedBox(height: 10),
                CupertinoTextField(
                  key: const Key('reader_color_hex_input'),
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
                    style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_recentColors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ReaderColorSection(
                    label: '最近使用',
                    colors: _recentColors,
                    currentColor: currentColor,
                    keyPrefix: 'reader_recent_color',
                    onSelected: _setColor,
                  ),
                ],
                const SizedBox(height: 10),
                ReaderColorSection(
                  label: '常用预设',
                  colors: kReaderColorPickerPresets,
                  currentColor: currentColor,
                  keyPrefix: 'reader_color',
                  onSelected: _setColor,
                ),
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

  Widget _buildPreview(Color currentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildPreviewChip(
            label: '当前',
            color: Color(_originalColor),
            keyName: 'reader_color_original_preview',
          ),
          const SizedBox(width: 8),
          _buildPreviewChip(
            label: '选择',
            color: currentColor,
            keyName: 'reader_color_selected_preview',
          ),
          const Spacer(),
          Text('#${readerColorPickerHexRgb(currentColor.toARGB32())}'),
        ],
      ),
    );
  }

  Widget _buildPreviewChip({
    required String label,
    required Color color,
    required String keyName,
  }) {
    return Row(
      key: Key(keyName),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}
