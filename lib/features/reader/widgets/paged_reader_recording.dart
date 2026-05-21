// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderRecording on _PagedReaderWidgetState {
  /// 使用 PictureRecorder 预渲染页面内容
  ui.Picture _recordPage(
    PageData pageData,
    Size size, {
    required PageRenderSlot slot,
    PageData? rightPageData,
    PageRenderPosition? rightRenderPosition,
  }) {
    final content = pageData.text;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final bottomSafe = systemPadding.bottom;
    final renderPosition = _factory.resolveRenderPosition(slot);

    // 绘制背景：先填底色，再叠加图片（如有）
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = widget.shaderBackgroundColor ?? widget.backgroundColor,
    );
    final bgImage = widget.backgroundUiImage;
    if (bgImage != null && widget.backgroundImageOpacity > 0) {
      final srcRect = Rect.fromLTWH(
          0, 0, bgImage.width.toDouble(), bgImage.height.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(
        bgImage,
        srcRect,
        dstRect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(
              255, 255, 255, widget.backgroundImageOpacity.clamp(0.0, 1.0)),
      );
    }

    if (content.isNotEmpty) {
      final totalWidth =
          size.width - widget.padding.left - widget.padding.right;
      final columnWidth =
          _isDoublePage ? (totalWidth - _doublePageGutter) / 2 : totalWidth;
      final contentHeight = size.height -
          (topSafe + _topOffset + widget.padding.top) -
          (bottomSafe + _bottomOffset + widget.padding.bottom);

      void paintColumn(PageData colData, double originX) {
        final col = _contentForPictureSnapshot(colData.text);
        final bodyOriginY = topSafe + _topOffset + widget.padding.top;
        if (contentHeight > 0) {
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(
            originX,
            bodyOriginY,
            columnWidth,
            contentHeight,
          ));
          LegacyJustifyPainter.paintContentOnCanvas(
            canvas: canvas,
            origin: Offset(originX, bodyOriginY),
            content: col,
            style: widget.textStyle,
            titleStyle: _resolvedTitleStyle,
            maxWidth: columnWidth,
            justify: widget.settings.textFullJustify,
            paragraphIndent: widget.settings.paragraphIndent,
            applyParagraphIndent: false,
            preserveEmptyLines: true,
            maxHeight: contentHeight,
            bottomJustify: widget.settings.textBottomJustify,
            highlightQuery: widget.searchHighlightQuery,
            highlightBackgroundColor: widget.searchHighlightColor,
            highlightTextColor: widget.searchHighlightTextColor,
            precomposedLines: colData.precomposedLines,
            emptyLineHeight: widget.settings.paragraphSpacing > 0
                ? widget.settings.fontSize *
                    widget.settings.paragraphSpacing /
                    10.0
                : null,
          );
          canvas.restore();
        }
      }

      paintColumn(pageData, widget.padding.left);

      if (_isDoublePage) {
        final rightOriginX =
            widget.padding.left + columnWidth + _doublePageGutter;
        final rightCol = rightPageData;
        if (rightCol != null && rightCol.text.isNotEmpty)
          paintColumn(rightCol, rightOriginX);

        // 双栏中间分隔线
        final dividerX =
            widget.padding.left + columnWidth + _doublePageGutter / 2;
        canvas.drawLine(
          Offset(dividerX, topSafe + _topOffset + widget.padding.top),
          Offset(dividerX,
              size.height - bottomSafe - _bottomOffset - widget.padding.bottom),
          Paint()
            ..color = widget.textStyle.color!.withValues(alpha: 0.12)
            ..strokeWidth = 0.5,
        );
      }
    }

    // 绘制状态栏
    if (_showAnyTipBar) {
      _paintHeaderFooter(
        canvas,
        size,
        topSafe,
        bottomSafe,
        renderPosition: renderPosition,
      );
    }

    return recorder.endRecording();
  }
}
