import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'scroll_text_layout_engine.dart';

class ScrollSegmentPaintView extends StatelessWidget {
  final ScrollTextLayout layout;
  final TextStyle style;
  final String? highlightQuery;
  final Color? highlightColor;
  final Color? highlightTextColor;

  const ScrollSegmentPaintView({
    super.key,
    required this.layout,
    required this.style,
    this.highlightQuery,
    this.highlightColor,
    this.highlightTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeHeight = layout.bodyHeight <= 0 ? 1.0 : layout.bodyHeight;
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: safeHeight,
        child: CustomPaint(
          isComplex: true,
          willChange: false,
          painter: _ScrollTextLayoutPainter(
            layout: layout,
            style: style,
            highlightQuery: highlightQuery,
            highlightColor: highlightColor,
            highlightTextColor: highlightTextColor,
          ),
        ),
      ),
    );
  }
}

class _ScrollTextLayoutPainter extends CustomPainter {
  final ScrollTextLayout layout;
  final TextStyle style;
  final String? highlightQuery;
  final Color? highlightColor;
  final Color? highlightTextColor;

  _ScrollTextLayoutPainter({
    required this.layout,
    required this.style,
    this.highlightQuery,
    this.highlightColor,
    this.highlightTextColor,
  });

  static const int _maxPainterCacheEntries = 4096;
  static final LinkedHashMap<String, TextPainter> _textPainterCache =
      LinkedHashMap<String, TextPainter>();

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.lines.isEmpty) {
      return;
    }

    var clipBounds = canvas.getLocalClipBounds();
    if (!clipBounds.isFinite) {
      clipBounds = Offset.zero & size;
    }
    final visibleTop =
        (clipBounds.top - 2.0).clamp(0.0, size.height).toDouble();
    final visibleBottom =
        (clipBounds.bottom + 2.0).clamp(0.0, size.height).toDouble();
    if (visibleBottom <= visibleTop) {
      return;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    var lineIndex = _findFirstVisibleLineIndex(visibleTop);
    while (lineIndex < layout.lines.length) {
      final line = layout.lines[lineIndex];
      var x = 0.0;
      final y = line.y;
      if (y > visibleBottom) {
        break;
      }
      if (y + line.height >= visibleTop) {
        final query = highlightQuery?.trim() ?? '';
        final hasHighlight = query.isNotEmpty;
        final ranges = hasHighlight
            ? _resolveMatchRanges(_lineText(line), query)
            : const <TextRange>[];
        var cursor = 0;
        for (final run in line.runs) {
          if (run.text.isNotEmpty) {
            final runStart = cursor;
            final runEnd = runStart + run.text.length;
            final overlaps = hasHighlight
                ? _resolveRunRanges(
                    ranges,
                    runStart: runStart,
                    runEnd: runEnd,
                  )
                : const <TextRange>[];
            if (overlaps.isEmpty) {
              x += _paintTextPiece(
                canvas: canvas,
                text: run.text,
                style: style,
                x: x,
                y: y,
                lineHeight: line.height,
              );
            } else {
              var localCursor = 0;
              for (final range in overlaps) {
                final localStart = range.start - runStart;
                final localEnd = range.end - runStart;
                if (localStart > localCursor) {
                  final before = run.text.substring(localCursor, localStart);
                  x += _paintTextPiece(
                    canvas: canvas,
                    text: before,
                    style: style,
                    x: x,
                    y: y,
                    lineHeight: line.height,
                  );
                }
                final hitText = run.text.substring(localStart, localEnd);
                x += _paintTextPiece(
                  canvas: canvas,
                  text: hitText,
                  style: style.copyWith(
                    color: highlightTextColor ?? style.color,
                  ),
                  x: x,
                  y: y,
                  lineHeight: line.height,
                  highlighted: true,
                  highlightBackgroundColor: highlightColor,
                );
                localCursor = localEnd;
              }
              if (localCursor < run.text.length) {
                final tail = run.text.substring(localCursor);
                x += _paintTextPiece(
                  canvas: canvas,
                  text: tail,
                  style: style,
                  x: x,
                  y: y,
                  lineHeight: line.height,
                );
              }
            }
            cursor = runEnd;
          }
          if (run.extraAfter > 0) {
            x += run.extraAfter;
          }
        }
      }
      lineIndex++;
    }

    canvas.restore();
  }

  int _findFirstVisibleLineIndex(double visibleTop) {
    var low = 0;
    var high = layout.lines.length - 1;
    var answer = layout.lines.length;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final line = layout.lines[mid];
      final lineBottom = line.y + line.height;
      if (lineBottom >= visibleTop) {
        answer = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    if (answer >= layout.lines.length) {
      return layout.lines.length;
    }
    return answer;
  }

  TextPainter _painterFor(String text, TextStyle textStyle) {
    final key = '${textStyle.hashCode}|$text';
    final cached = _textPainterCache[key];
    if (cached != null) {
      _textPainterCache.remove(key);
      _textPainterCache[key] = cached;
      return cached;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    _textPainterCache[key] = painter;
    while (_textPainterCache.length > _maxPainterCacheEntries) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }
    return painter;
  }

  String _lineText(ScrollTextLine line) {
    if (line.runs.isEmpty) return '';
    final buffer = StringBuffer();
    for (final run in line.runs) {
      buffer.write(run.text);
    }
    return buffer.toString();
  }

  List<TextRange> _resolveMatchRanges(String text, String query) {
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

  List<TextRange> _resolveRunRanges(
    List<TextRange> ranges, {
    required int runStart,
    required int runEnd,
  }) {
    if (ranges.isEmpty || runEnd <= runStart) {
      return const <TextRange>[];
    }
    final result = <TextRange>[];
    for (final range in ranges) {
      if (range.end <= runStart) continue;
      if (range.start >= runEnd) break;
      final start = range.start.clamp(runStart, runEnd).toInt();
      final end = range.end.clamp(runStart, runEnd).toInt();
      if (end > start) {
        result.add(TextRange(start: start, end: end));
      }
    }
    return result;
  }

  double _paintTextPiece({
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
    final painter = _painterFor(text, style);
    if (highlighted) {
      final color = highlightBackgroundColor ?? const Color(0x66FFD54F);
      final rectHeight = (painter.height + 3).clamp(0.0, lineHeight);
      final rectTop = y + (lineHeight - rectHeight) / 2;
      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, rectTop, painter.width, rectHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color,
      );
    }
    painter.paint(canvas, Offset(x, y));
    return painter.width;
  }

  @override
  bool shouldRepaint(covariant _ScrollTextLayoutPainter oldDelegate) {
    return oldDelegate.layout.key != layout.key ||
        oldDelegate.style != style ||
        oldDelegate.highlightQuery != highlightQuery ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.highlightTextColor != highlightTextColor;
  }
}
