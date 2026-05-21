// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderTipPainting on _PagedReaderWidgetState {
  void _paintHeaderFooter(
    Canvas canvas,
    Size size,
    double topSafe,
    double bottomSafe, {
    required PageRenderPosition renderPosition,
  }) {
    final statusColor = _tipTextColor;
    final dividerColor = _tipDividerColor;
    final headerStyle = widget.textStyle
        .copyWith(fontSize: 12, height: 1.0, color: statusColor);
    final footerStyle = widget.textStyle
        .copyWith(fontSize: 11, height: 1.0, color: statusColor);

    if (_showHeader) {
      final y = topSafe +
          PagedReaderWidget._tipHeaderEdgeInset +
          widget.settings.headerPaddingTop;
      _paintTipRow(
        canvas,
        size,
        y,
        headerStyle,
        _tipTextForHeader(
          widget.settings.headerLeftContent,
          renderPosition: renderPosition,
        ),
        _tipTextForHeader(
          widget.settings.headerCenterContent,
          renderPosition: renderPosition,
        ),
        _tipTextForHeader(
          widget.settings.headerRightContent,
          renderPosition: renderPosition,
        ),
        leftPadding: widget.settings.headerPaddingLeft,
        rightPadding: widget.settings.headerPaddingRight,
      );
      if (widget.settings.showHeaderLine) {
        final lineY = topSafe +
            _headerSlotHeight -
            (PagedReaderWidget._tipDividerThickness / 2);
        final paint = Paint()
          ..color = dividerColor
          ..strokeWidth = PagedReaderWidget._tipDividerThickness;
        final lineStart =
            widget.settings.headerPaddingLeft.clamp(0.0, size.width).toDouble();
        final lineEnd = (size.width - widget.settings.headerPaddingRight)
            .clamp(0.0, size.width)
            .toDouble();
        if (lineEnd > lineStart) {
          canvas.drawLine(
            Offset(lineStart, lineY),
            Offset(lineEnd, lineY),
            paint,
          );
        }
      }
    }

    if (_showFooter) {
      final footerSlotTop =
          size.height - bottomSafe - widget.padding.bottom - _bottomOffset;
      final dividerHeight = widget.settings.showFooterLine
          ? PagedReaderWidget._tipLineGap +
              PagedReaderWidget._tipDividerThickness
          : 0.0;
      final y = footerSlotTop +
          PagedReaderWidget._tipFooterEdgeInset +
          widget.settings.footerPaddingTop +
          dividerHeight;
      _paintTipRow(
        canvas,
        size,
        y,
        footerStyle,
        _tipTextForFooter(
          widget.settings.footerLeftContent,
          renderPosition: renderPosition,
        ),
        _tipTextForFooter(
          widget.settings.footerCenterContent,
          renderPosition: renderPosition,
        ),
        _tipTextForFooter(
          widget.settings.footerRightContent,
          renderPosition: renderPosition,
        ),
        leftPadding: widget.settings.footerPaddingLeft,
        rightPadding: widget.settings.footerPaddingRight,
      );
      if (widget.settings.showFooterLine) {
        final lineY = y -
            PagedReaderWidget._tipLineGap -
            (PagedReaderWidget._tipDividerThickness / 2);
        final paint = Paint()
          ..color = dividerColor
          ..strokeWidth = PagedReaderWidget._tipDividerThickness;
        final lineStart =
            widget.settings.footerPaddingLeft.clamp(0.0, size.width).toDouble();
        final lineEnd = (size.width - widget.settings.footerPaddingRight)
            .clamp(0.0, size.width)
            .toDouble();
        if (lineEnd > lineStart) {
          canvas.drawLine(
            Offset(lineStart, lineY),
            Offset(lineEnd, lineY),
            paint,
          );
        }
      }
    }
  }

  void _paintTipRow(
    Canvas canvas,
    Size size,
    double y,
    TextStyle style,
    String? left,
    String? center,
    String? right, {
    required double leftPadding,
    required double rightPadding,
  }) {
    final safeLeft = leftPadding.clamp(0.0, size.width).toDouble();
    final safeRight = rightPadding.clamp(0.0, size.width).toDouble();
    final maxWidth = (size.width - safeLeft - safeRight).clamp(0.0, size.width);
    if (maxWidth <= 0) return;

    if (left != null && left.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: left, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(safeLeft, y));
    }
    if (center != null && center.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: center, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      final x = safeLeft + (maxWidth - painter.width) / 2;
      painter.paint(canvas, Offset(x, y));
    }
    if (right != null && right.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: right, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      painter.paint(
        canvas,
        Offset(size.width - safeRight - painter.width, y),
      );
    }
  }

  String? _tipTextForHeader(
    int type, {
    required PageRenderPosition renderPosition,
  }) {
    return _tipText(
      type,
      isHeader: true,
      renderPosition: renderPosition,
    );
  }

  String? _tipTextForFooter(
    int type, {
    required PageRenderPosition renderPosition,
  }) {
    return _tipText(
      type,
      isHeader: false,
      renderPosition: renderPosition,
    );
  }

  String? _tipText(
    int type, {
    required bool isHeader,
    required PageRenderPosition renderPosition,
  }) {
    final time = DateFormat('HH:mm').format(DateTime.now());
    final bookProgress = _bookProgress(renderPosition);
    final chapterProgress = _chapterProgress(renderPosition);
    switch (type) {
      case 0:
        return isHeader
            ? widget.bookTitle
            : _progressText(bookProgress,
                enabled: widget.settings.showProgress);
      case 1:
        return isHeader
            ? renderPosition.chapterTitle
            : _pageText(renderPosition, includeTotal: true);
      case 2:
        return isHeader ? '' : _timeText(time);
      case 3:
        return isHeader ? _timeText(time) : _batteryText();
      case 4:
        return isHeader ? _batteryText() : '';
      case 5:
        return isHeader
            ? _progressText(bookProgress, enabled: widget.settings.showProgress)
            : renderPosition.chapterTitle;
      case 6:
        return isHeader
            ? _pageText(renderPosition, includeTotal: true)
            : widget.bookTitle;
      case 7:
        return _progressText(chapterProgress,
            enabled: widget.settings.showChapterProgress);
      case 8:
        return _pageText(renderPosition, includeTotal: true);
      case 9:
        return _timeBatteryText(time);
      default:
        return '';
    }
  }

  String _pageText(
    PageRenderPosition renderPosition, {
    bool includeTotal = true,
  }) {
    final current = renderPosition.pageIndex + 1;
    final total = renderPosition.totalPages.clamp(1, 9999);
    return includeTotal ? '$current/$total' : '$current';
  }

  String _progressText(double progress, {bool enabled = true}) {
    if (!enabled) return '';
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  String _batteryText() {
    if (!widget.settings.showBattery) return '';
    return '$_batteryLevel%';
  }

  String _timeText(String time) {
    if (!widget.settings.showTime) return '';
    return time;
  }

  String _timeBatteryText(String time) {
    final parts = <String>[];
    if (widget.settings.showTime) parts.add(time);
    if (widget.settings.showBattery) parts.add('$_batteryLevel%');
    return parts.join(' ');
  }

  double _chapterProgress(PageRenderPosition renderPosition) {
    final total = renderPosition.totalPages;
    if (total <= 0) return 0;
    return ((renderPosition.pageIndex + 1) / total).clamp(0.0, 1.0);
  }

  double _bookProgress(PageRenderPosition renderPosition) {
    final totalChapters = _factory.totalChapters;
    if (totalChapters <= 0) return 0;
    final chapterProgress = _chapterProgress(renderPosition);
    return ((renderPosition.chapterIndex + chapterProgress) / totalChapters)
        .clamp(0.0, 1.0);
  }
}
