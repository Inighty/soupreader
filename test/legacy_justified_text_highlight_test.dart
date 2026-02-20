import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/widgets/legacy_justified_text.dart';

void main() {
  test('LegacyJustifyComposer paintContentOnCanvas supports highlight query',
      () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final height = LegacyJustifyComposer.paintContentOnCanvas(
      canvas: canvas,
      origin: const Offset(0, 0),
      content: '这是第一行测试文本\n这是第二行测试文本',
      style: const TextStyle(
        fontSize: 18,
        height: 1.6,
        color: Color(0xFF111111),
      ),
      maxWidth: 300,
      justify: true,
      paragraphIndent: '　　',
      applyParagraphIndent: true,
      preserveEmptyLines: true,
      maxHeight: 600,
      highlightQuery: '测试',
      highlightBackgroundColor: Color(0x44FFCC00),
      highlightTextColor: Color(0xFF111111),
    );

    expect(height, greaterThan(0));

    final picture = recorder.endRecording();
    picture.dispose();
  });
}
