import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

Future<void> showAppHelpDialog(
  BuildContext context, {
  required String markdownText,
  String title = '帮助',
}) {
  return showCupertinoBottomDialog<void>(
    context: context,
    builder: (_) => _AppHelpDialog(
      title: title,
      markdownText: markdownText,
    ),
  );
}

class _AppHelpDialog extends StatefulWidget {
  final String title;
  final String markdownText;

  const _AppHelpDialog({
    required this.title,
    required this.markdownText,
  });

  @override
  State<_AppHelpDialog> createState() => _AppHelpDialogState();
}

class _AppHelpDialogState extends State<_AppHelpDialog> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 680.0);
    final height = math.min(screenSize.height * 0.82, 760.0);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final bodyColor = CupertinoColors.label.resolveFrom(context);

    return Center(
      child: CupertinoPopupSurface(
        child: SizedBox(
          width: width,
          height: height,
          child: CupertinoPageScaffold(
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('关闭'),
                          minimumSize: Size(30, 30),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.5, color: separator),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      child: SelectableRegion(
                        focusNode: _focusNode,
                        selectionControls: cupertinoTextSelectionControls,
                        child: Text(
                          widget.markdownText.trim().isEmpty
                              ? '暂无内容'
                              : widget.markdownText,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.48,
                            color: bodyColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
