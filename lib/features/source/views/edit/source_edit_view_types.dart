import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/theme/ui_tokens.dart';

class SourceEditValueFieldTile extends StatelessWidget {
  const SourceEditValueFieldTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.maxLines = 1,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final background = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return CupertinoListTile.notched(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(ui.radii.control),
          ),
          child: SourceEditValueField(
            value: value,
            onChanged: onChanged,
            placeholder: placeholder,
            maxLines: maxLines,
            baseStyle: baseStyle,
            labelColor: ui.colors.label,
            placeholderColor: ui.colors.tertiaryLabel,
          ),
        ),
      ),
    );
  }
}

class SourceEditValueField extends StatefulWidget {
  const SourceEditValueField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.baseStyle,
    required this.labelColor,
    required this.placeholderColor,
    this.placeholder,
    this.maxLines = 1,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final TextStyle baseStyle;
  final Color labelColor;
  final Color placeholderColor;
  final String? placeholder;
  final int maxLines;

  @override
  State<SourceEditValueField> createState() => _SourceEditValueFieldState();
}

class _SourceEditValueFieldState extends State<SourceEditValueField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant SourceEditValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.value = _controller.value.copyWith(text: widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: _controller,
      onChanged: widget.onChanged,
      placeholder: widget.placeholder,
      maxLines: widget.maxLines,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: widget.maxLines > 1
          ? TextInputType.multiline
          : TextInputType.url,
      decoration: null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      style: widget.baseStyle.copyWith(
        fontSize: 13,
        color: widget.labelColor,
        letterSpacing: -0.2,
      ),
      placeholderStyle: widget.baseStyle.copyWith(
        fontSize: 13,
        color: widget.placeholderColor,
        letterSpacing: -0.2,
      ),
    );
  }
}
