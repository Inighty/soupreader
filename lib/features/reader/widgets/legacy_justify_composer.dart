import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'legacy_justified_text.dart';

class LegacyJustifyComposer {
  static List<LegacyComposedLine> composeContentLines({
    required String content,
    required TextStyle style,
    required double maxWidth,
    required bool justify,
    required String paragraphIndent,
    required bool applyParagraphIndent,
    required bool preserveEmptyLines,
    double? emptyLineHeight,
  }) {
    final paragraphs = content.split('\n');
    final fontSize = style.fontSize ?? 16.0;
    final defaultLineHeight =
        fontSize * (style.height ?? 1.2).clamp(1.0, 2.5);
    final lines = <LegacyComposedLine>[];
    var currentY = 0.0;
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        if (preserveEmptyLines) {
          final h = emptyLineHeight ?? defaultLineHeight;
          lines.add(LegacyComposedLine.empty(
            height: h,
            renderHeight: h,
            lineStartY: currentY,
          ));
          currentY += h;
        }
        continue;
      }
      final composed = composeParagraph(
        paragraph: paragraph,
        style: style,
        maxWidth: maxWidth,
        justify: justify,
        paragraphIndent: paragraphIndent,
        applyParagraphIndent: applyParagraphIndent,
      );
      for (final line in composed.lines) {
        lines.add(LegacyComposedLine(
          plainText: line.plainText,
          segments: line.segments,
          justified: line.justified,
          height: line.height,
          renderHeight: fontSize,
          lineStartY: currentY,
        ));
        currentY += line.height;
      }
    }
    return lines;
  }

  static double computeBottomJustifyGap({
    required bool bottomJustify,
    required List<LegacyComposedLine> lines,
    required double? maxHeight,
  }) {
    if (!bottomJustify) return 0;
    if (maxHeight == null || !maxHeight.isFinite || maxHeight <= 0) return 0;
    if (lines.length <= 1) return 0;
    final lastLine = lines.last;
    if (lastLine.isVisualEmpty) return 0;
    final contentHeight =
        lines.fold<double>(0, (sum, line) => sum + line.height);
    final surplus = maxHeight - contentHeight;
    if (surplus <= 0.01) return 0;
    if (surplus >= lastLine.height) return 0;
    final gapCount = lines.length - 1;
    if (gapCount <= 0) return 0;
    return surplus / gapCount;
  }

  static LegacyComposedParagraph composeParagraph({
    required String paragraph,
    required TextStyle style,
    required double maxWidth,
    required bool justify,
    required String paragraphIndent,
    required bool applyParagraphIndent,
  }) {
    final normalized = paragraph.trimRight();
    if (normalized.isEmpty) {
      return const LegacyComposedParagraph(<LegacyComposedLine>[]);
    }

    final source = (applyParagraphIndent && paragraphIndent.isNotEmpty)
        ? '$paragraphIndent${normalized.trimLeft()}'
        : normalized;

    final painter = TextPainter(
      text: TextSpan(text: source, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final lineMetrics = painter.computeLineMetrics();
    if (lineMetrics.isEmpty) {
      return const LegacyComposedParagraph(<LegacyComposedLine>[]);
    }

    final lines = <LegacyComposedLine>[];
    var offset = 0;
    final indentLen = paragraphIndent.length;
    // 字体基准高度（不含行距间隙），对标 legado textHeight
    final fontSizeForRender = style.fontSize ?? 16.0;

    for (var i = 0; i < lineMetrics.length; i++) {
      final metric = lineMetrics[i];
      var range = painter.getLineBoundary(
        TextPosition(offset: offset.clamp(0, source.length)),
      );
      if (range.end <= offset && offset < source.length) {
        final next = (offset + 1).clamp(0, source.length);
        range = TextRange(start: offset, end: next);
      }

      var lineText = source.substring(range.start, range.end);
      offset = range.end;
      if (lineText.endsWith('\n')) {
        lineText = lineText.substring(0, lineText.length - 1);
      }

      final isLastLine = i == lineMetrics.length - 1;
      final canJustify = justify &&
          !isLastLine &&
          lineText.trim().isNotEmpty &&
          lineText.runes.length > 1;

      if (!canJustify) {
        lines.add(
          LegacyComposedLine(
            plainText: lineText,
            segments: <LegacyComposedSegment>[
              LegacyComposedSegment(text: lineText, extraAfter: 0),
            ],
            justified: false,
            height: metric.height,
            renderHeight: fontSizeForRender,
          ),
        );
        continue;
      }

      var prefix = '';
      var body = lineText;
      if (indentLen > 0 && i == 0 && body.startsWith(paragraphIndent)) {
        prefix = paragraphIndent;
        body = body.substring(paragraphIndent.length);
      }

      // 直接用 lineMetrics 的实际行宽，避免重新 layout 时尾部 letterSpacing 导致偏差
      final lineNaturalWidth = metric.width;
      final residualWidth = maxWidth - lineNaturalWidth;
      if (residualWidth <= 0.01) {
        lines.add(
          LegacyComposedLine(
            plainText: lineText,
            segments: <LegacyComposedSegment>[
              LegacyComposedSegment(text: lineText, extraAfter: 0),
            ],
            justified: false,
            height: metric.height,
            renderHeight: fontSizeForRender,
          ),
        );
        continue;
      }

      final chars = body.runes.map(String.fromCharCode).toList(growable: false);
      if (chars.length <= 1) {
        lines.add(
          LegacyComposedLine(
            plainText: lineText,
            segments: <LegacyComposedSegment>[
              LegacyComposedSegment(text: lineText, extraAfter: 0),
            ],
            justified: false,
            height: metric.height,
            renderHeight: fontSizeForRender,
          ),
        );
        continue;
      }

      final spaceCount = chars.where((c) => c == ' ').length;
      final segments = <LegacyComposedSegment>[];
      if (prefix.isNotEmpty) {
        segments.add(LegacyComposedSegment(text: prefix, extraAfter: 0));
      }

      if (spaceCount > 1) {
        final gap = residualWidth / spaceCount;
        for (var idx = 0; idx < chars.length; idx++) {
          final isLastChar = idx == chars.length - 1;
          final extra = (chars[idx] == ' ' && !isLastChar) ? gap : 0.0;
          segments
              .add(LegacyComposedSegment(text: chars[idx], extraAfter: extra));
        }
      } else {
        final gapCount = chars.length - 1;
        if (gapCount <= 0) {
          segments.add(LegacyComposedSegment(text: body, extraAfter: 0));
        } else {
          final gap = residualWidth / gapCount;
          for (var idx = 0; idx < chars.length; idx++) {
            final extra = idx < chars.length - 1 ? gap : 0.0;
            segments.add(
                LegacyComposedSegment(text: chars[idx], extraAfter: extra));
          }
        }
      }

      lines.add(
        LegacyComposedLine(
          plainText: lineText,
          segments: segments,
          justified: true,
          height: metric.height,
          renderHeight: fontSizeForRender,
        ),
      );
    }

    return LegacyComposedParagraph(lines);
  }

}
