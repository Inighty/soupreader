// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderSelectionWords on _PagedReaderWidgetState {
  String _stripImageMarkersFromContent(String content) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final buffer = StringBuffer();
    var first = true;
    for (final line in lines) {
      if (ReaderImageMarkerCodec.decodeLine(line) != null) {
        continue;
      }
      if (!first) {
        buffer.writeln();
      }
      buffer.write(line);
      first = false;
    }
    return buffer.toString();
  }

  int _resolveCharacterIndexInLine({
    required LegacyComposedLine line,
    required double x,
    required TextStyle style,
    required double maxWidth,
  }) {
    final text = line.plainText;
    if (text.isEmpty) return -1;

    if (!line.justified || line.segments.length <= 1) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxWidth);
      return painter
          .getPositionForOffset(Offset(x, 0))
          .offset
          .clamp(0, text.length - 1)
          .toInt();
    }

    var cursor = 0;
    var drawX = 0.0;
    for (final segment in line.segments) {
      final segmentText = segment.text;
      for (var i = 0; i < segmentText.length; i++) {
        final char = segmentText.substring(i, i + 1);
        final width = _measureSingleCharWidth(char, style);
        final center = drawX + width / 2;
        if (x <= center) {
          return cursor.clamp(0, text.length - 1).toInt();
        }
        drawX += width;
        cursor += 1;
      }
      if (segment.extraAfter > 0) {
        final center = drawX + segment.extraAfter / 2;
        if (x <= center) {
          return (cursor - 1).clamp(0, text.length - 1).toInt();
        }
        drawX += segment.extraAfter;
      }
    }
    return text.length - 1;
  }

  double _measureSingleCharWidth(String char, TextStyle style) {
    if (char.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: char, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return painter.width;
  }

  String _extractWordAtIndex(String text, int index) {
    final normalized = text.trimRight();
    if (normalized.isEmpty) return '';
    var safeIndex = index.clamp(0, normalized.length - 1).toInt();
    if (_isWhitespace(normalized[safeIndex])) {
      final left = _findNearestNonWhitespace(
        text: normalized,
        start: safeIndex,
        step: -1,
      );
      final right = _findNearestNonWhitespace(
        text: normalized,
        start: safeIndex,
        step: 1,
      );
      if (left == null && right == null) return '';
      if (left == null) {
        safeIndex = right!;
      } else if (right == null) {
        safeIndex = left;
      } else {
        final leftDistance = (safeIndex - left).abs();
        final rightDistance = (right - safeIndex).abs();
        safeIndex = leftDistance <= rightDistance ? left : right;
      }
    }

    final current = normalized[safeIndex];
    if (!_isWordLike(current)) {
      return current.trim();
    }
    final currentIsCjk = _isCjk(current);

    var start = safeIndex;
    while (start > 0) {
      final previous = normalized[start - 1];
      if (!_isWordLike(previous)) break;
      if (currentIsCjk != _isCjk(previous)) break;
      start -= 1;
    }

    var end = safeIndex + 1;
    while (end < normalized.length) {
      final next = normalized[end];
      if (!_isWordLike(next)) break;
      if (currentIsCjk != _isCjk(next)) break;
      end += 1;
    }

    return normalized.substring(start, end).trim();
  }

  bool _isWhitespace(String value) => value.trim().isEmpty;

  bool _isWordLike(String value) {
    if (value.trim().isEmpty) return false;
    return RegExp(r'[A-Za-z0-9_\u3400-\u9FFF]').hasMatch(value);
  }

  bool _isCjk(String value) => RegExp(r'[\u3400-\u9FFF]').hasMatch(value);

  int? _findNearestNonWhitespace({
    required String text,
    required int start,
    required int step,
  }) {
    var index = start;
    while (true) {
      index += step;
      if (index < 0 || index >= text.length) return null;
      if (!_isWhitespace(text[index])) {
        return index;
      }
    }
  }

  int _resolveClickAction(Offset position) {
    final size = (context.findRenderObject() as RenderBox?)?.size ??
        MediaQuery.sizeOf(context);
    final col = (position.dx / size.width * 3).floor().clamp(0, 2);
    final row = (position.dy / size.height * 3).floor().clamp(0, 2);
    const zones = [
      ['tl', 'tc', 'tr'],
      ['ml', 'mc', 'mr'],
      ['bl', 'bc', 'br'],
    ];
    final zone = zones[row][col];
    final config = ClickAction.normalizeConfig(widget.clickActions);
    return config[zone] ?? ClickAction.showMenu;
  }
}
