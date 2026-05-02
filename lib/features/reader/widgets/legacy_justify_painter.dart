import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'legacy_justified_text.dart';

class LegacyJustifyPainter {
  static double paintContentOnCanvas({
    required Canvas canvas,
    required Offset origin,
    required String content,
    required TextStyle style,
    TextStyle? titleStyle,
    required double maxWidth,
    required bool justify,
    required String paragraphIndent,
    required bool applyParagraphIndent,
    required bool preserveEmptyLines,
    required double maxHeight,
    bool bottomJustify = false,
    String? highlightQuery,
    Color? highlightBackgroundColor,
    Color? highlightTextColor,
    List<LegacyComposedLine>? precomposedLines,
    double? emptyLineHeight,
  }) {
    final renderLines = precomposedLines ??
        LegacyJustifyComposer.composeContentLines(
          content: content,
          style: style,
          maxWidth: maxWidth,
          justify: justify,
          paragraphIndent: paragraphIndent,
          applyParagraphIndent: applyParagraphIndent,
          preserveEmptyLines: preserveEmptyLines,
          emptyLineHeight: emptyLineHeight,
        );
    if (renderLines.isEmpty) {
      return 0;
    }
    final extraGap = LegacyJustifyComposer.computeBottomJustifyGap(
      bottomJustify: bottomJustify,
      lines: renderLines,
      maxHeight: maxHeight,
    );
    var y = origin.dy;
    final normalizedQuery = highlightQuery?.trim() ?? '';
    final hasHighlight = normalizedQuery.isNotEmpty;

    for (var lineIndex = 0; lineIndex < renderLines.length; lineIndex++) {
      final line = renderLines[lineIndex];
      final lineExtraGap = (lineIndex > 0 && extraGap > 0.01) ? extraGap : 0.0;
      if (y - origin.dy + lineExtraGap + line.renderHeight > maxHeight) break;
      if (lineExtraGap > 0.01) {
        y += lineExtraGap;
      }
      if (line.segments.isEmpty || line.isVisualEmpty) {
        y += line.height;
        continue;
      }

      final effectiveStyle =
          (line.isTitle && titleStyle != null) ? titleStyle : style;
      final lineRanges = hasHighlight
          ? _resolveMatchRanges(line.plainText, normalizedQuery)
          : const <TextRange>[];
      var x = origin.dx;
      var cursor = 0;
      for (final segment in line.segments) {
        if (segment.text.isNotEmpty) {
          final segmentStart = cursor;
          final segmentEnd = segmentStart + segment.text.length;
          final overlaps = hasHighlight
              ? _resolveSegmentRanges(
                  lineRanges,
                  segmentStart: segmentStart,
                  segmentEnd: segmentEnd,
                )
              : const <TextRange>[];
          if (overlaps.isEmpty) {
            x += _paintTextPiece(
              canvas: canvas,
              text: segment.text,
              style: effectiveStyle,
              x: x,
              y: y,
              lineHeight: line.height,
            );
          } else {
            var localCursor = 0;
            for (final range in overlaps) {
              final localStart = range.start - segmentStart;
              final localEnd = range.end - segmentStart;
              if (localStart > localCursor) {
                final before = segment.text.substring(localCursor, localStart);
                x += _paintTextPiece(
                  canvas: canvas,
                  text: before,
                  style: effectiveStyle,
                  x: x,
                  y: y,
                  lineHeight: line.height,
                );
              }
              final hitText = segment.text.substring(localStart, localEnd);
              x += _paintTextPiece(
                canvas: canvas,
                text: hitText,
                style: effectiveStyle.copyWith(
                  color: highlightTextColor ?? effectiveStyle.color,
                ),
                x: x,
                y: y,
                lineHeight: line.height,
                highlighted: true,
                highlightBackgroundColor: highlightBackgroundColor,
              );
              localCursor = localEnd;
            }
            if (localCursor < segment.text.length) {
              final tail = segment.text.substring(localCursor);
              x += _paintTextPiece(
                canvas: canvas,
                text: tail,
                style: effectiveStyle,
                x: x,
                y: y,
                lineHeight: line.height,
              );
            }
          }
          cursor = segmentEnd;
        }
        if (segment.extraAfter > 0) {
          x += segment.extraAfter;
        }
      }
      y += line.height;
    }

    return y - origin.dy;
  }

  static List<TextRange> _resolveMatchRanges(String text, String query) {
    if (text.isEmpty || query.isEmpty) return const <TextRange>[];
    final ranges = <TextRange>[];
    var from = 0;
    while (from < text.length) {
      final found = text.indexOf(query, from);
      if (found == -1) break;
      final end = found + query.length;
      ranges.add(TextRange(start: found, end: end));
      from = end;
    }
    return ranges;
  }

  static List<TextRange> _resolveSegmentRanges(
    List<TextRange> ranges, {
    required int segmentStart,
    required int segmentEnd,
  }) {
    if (ranges.isEmpty || segmentEnd <= segmentStart) {
      return const <TextRange>[];
    }
    final result = <TextRange>[];
    for (final range in ranges) {
      if (range.end <= segmentStart) continue;
      if (range.start >= segmentEnd) break;
      final start = range.start.clamp(segmentStart, segmentEnd).toInt();
      final end = range.end.clamp(segmentStart, segmentEnd).toInt();
      if (end > start) {
        result.add(TextRange(start: start, end: end));
      }
    }
    return result;
  }

  static double _paintTextPiece({
    required Canvas canvas,
    required String text,
    required TextStyle style,
    required double x,
    required double y,
    required double lineHeight,
    bool highlighted = false,
    Color? highlightBackgroundColor,
  }) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    if (highlighted) {
      final highlightColor =
          highlightBackgroundColor ?? const Color(0x66FFD54F);
      final rectHeight = (painter.height + 3).clamp(0.0, lineHeight);
      final rectTop = y + (lineHeight - rectHeight) / 2;
      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, rectTop, painter.width, rectHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rRect,
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.fill,
      );
    }
    painter.paint(canvas, Offset(x, y));
    return painter.width;
  }

  /// 计算选区内每行的高亮矩形（相对于 [origin] 的绝对坐标）。
  ///
  /// [startLineIndex]/[startCharIndex] 为选区起点，[endLineIndex]/[endCharIndex] 为终点。
  /// 返回的 [Rect] 列表可直接用于 Canvas 绘制高亮。
  static List<Rect> resolveSelectionRects({
    required List<LegacyComposedLine> lines,
    required int startLineIndex,
    required int startCharIndex,
    required int endLineIndex,
    required int endCharIndex,
    required TextStyle style,
    required double maxWidth,
    required Offset origin,
    bool bottomJustify = false,
    double? maxHeight,
  }) {
    if (lines.isEmpty) return const <Rect>[];
    final safeStart = startLineIndex.clamp(0, lines.length - 1);
    final safeEnd = endLineIndex.clamp(0, lines.length - 1);
    if (safeStart > safeEnd) return const <Rect>[];

    // 对标 paintContentOnCanvas：底部对齐时行间加 extraGap
    final extraGap = LegacyJustifyComposer.computeBottomJustifyGap(
      bottomJustify: bottomJustify,
      lines: lines,
      maxHeight: maxHeight,
    );

    final rects = <Rect>[];
    for (var i = safeStart; i <= safeEnd; i++) {
      final line = lines[i];
      if (line.isVisualEmpty) continue;
      final text = line.plainText;
      if (text.isEmpty) continue;

      final charStart = (i == safeStart) ? startCharIndex.clamp(0, text.length) : 0;
      final charEnd = (i == safeEnd) ? endCharIndex.clamp(0, text.length) : text.length;
      if (charStart >= charEnd) continue;

      final x0 = _resolveCharX(line: line, charIndex: charStart, style: style, maxWidth: maxWidth);
      final x1 = _resolveCharX(line: line, charIndex: charEnd, style: style, maxWidth: maxWidth);
      if (x1 <= x0) continue;

      // lineStartY 不含 extraGap，需补加（第 i 行前累计 i 个 extraGap，从 index=1 开始）
      final gapOffset = i > 0 ? extraGap * i : 0.0;
      final top = origin.dy + line.lineStartY + gapOffset;
      rects.add(Rect.fromLTWH(origin.dx + x0, top, x1 - x0, line.height));
    }
    return rects;
  }

  /// 计算某行中第 [charIndex] 个字符的左边 x 坐标（相对于行起点 x=0）。
  static double _resolveCharX({
    required LegacyComposedLine line,
    required int charIndex,
    required TextStyle style,
    required double maxWidth,
  }) {
    if (charIndex <= 0) return 0.0;
    final text = line.plainText;
    if (charIndex >= text.length) {
      // 返回行尾 x
      if (!line.justified || line.segments.length <= 1) {
        final p = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: maxWidth);
        return p.width;
      }
      // justify 行：累加所有 segment 宽度（不含最后 extraAfter）
      var x = 0.0;
      for (final segment in line.segments) {
        for (var i = 0; i < segment.text.length; i++) {
          final char = segment.text.substring(i, i + 1);
          final p = TextPainter(
            text: TextSpan(text: char, style: style),
            textDirection: ui.TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: double.infinity);
          x += p.width;
        }
        x += segment.extraAfter;
      }
      return x;
    }
    if (!line.justified || line.segments.length <= 1) {
      final prefix = text.substring(0, charIndex.clamp(0, text.length));
      final p = TextPainter(
        text: TextSpan(text: prefix, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: double.infinity);
      return p.width;
    }
    // justify 行：逐 segment 逐字符累加
    var x = 0.0;
    var cursor = 0;
    for (final segment in line.segments) {
      for (var i = 0; i < segment.text.length; i++) {
        if (cursor >= charIndex) return x;
        final char = segment.text.substring(i, i + 1);
        final p = TextPainter(
          text: TextSpan(text: char, style: style),
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: double.infinity);
        x += p.width;
        cursor++;
      }
      if (cursor < charIndex) x += segment.extraAfter;
    }
    return x;
  }
}
