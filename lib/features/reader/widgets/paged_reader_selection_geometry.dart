// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderSelectionGeometry on _PagedReaderWidgetState {
  List<LegacyComposedLine>? _getSelectionLines() {
    if (_selectionLines != null) return _selectionLines;
    final pageData = _factory.curPageData;
    if (pageData.text.trim().isEmpty) return null;
    // 优先使用预排版缓存（含标题行），避免重排
    if (pageData.precomposedLines != null) {
      _selectionLines = pageData.precomposedLines;
      return _selectionLines;
    }
    final size = MediaQuery.sizeOf(context);
    final totalWidth = size.width - widget.padding.left - widget.padding.right;
    final columnWidth =
        _isDoublePage ? (totalWidth - _doublePageGutter) / 2 : totalWidth;
    if (columnWidth <= 0) return null;
    final bodyText = _stripImageMarkersFromContent(pageData.text);
    if (bodyText.trim().isEmpty) return null;
    _selectionLines = LegacyJustifyComposer.composeContentLines(
      content: bodyText,
      style: widget.textStyle,
      maxWidth: columnWidth,
      justify: widget.settings.textFullJustify,
      paragraphIndent: widget.settings.paragraphIndent,
      applyParagraphIndent: false,
      preserveEmptyLines: true,
      emptyLineHeight: widget.settings.paragraphSpacing > 0
          ? widget.settings.fontSize * widget.settings.paragraphSpacing / 10.0
          : null,
    );
    return _selectionLines;
  }

  /// 将全局坐标映射到 (lineIndex, charIndex)，返回 null 表示未命中。
  (int, int)? _resolveSelectionHitResult(Offset globalPosition) {
    final content = _factory.curPage;
    if (content.trim().isEmpty) return null;
    final size = MediaQuery.sizeOf(context);
    final totalWidth = size.width - widget.padding.left - widget.padding.right;
    final columnWidth =
        _isDoublePage ? (totalWidth - _doublePageGutter) / 2 : totalWidth;
    if (columnWidth <= 0) return null;
    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final contentTop = topSafe + _topOffset + widget.padding.top;
    final localY = globalPosition.dy - contentTop;
    if (!localY.isFinite || localY < 0) return null;
    final lines = _getSelectionLines();
    if (lines == null || lines.isEmpty) return null;
    // 计算底部对齐 extraGap（与 paintContentOnCanvas 一致）
    final contentHeight = size.height -
        (topSafe + _topOffset + widget.padding.top) -
        (systemPadding.bottom + _bottomOffset + widget.padding.bottom);
    final extraGap = LegacyJustifyComposer.computeBottomJustifyGap(
      bottomJustify: widget.settings.textBottomJustify,
      lines: lines,
      maxHeight: contentHeight,
    );
    // 行命中（lineStartY 不含 extraGap，需补加）
    int lineIndex = lines.length - 1;
    for (var i = 0; i < lines.length; i++) {
      final gapOffset = i > 0 ? extraGap * i : 0.0;
      final lineTop = lines[i].lineStartY + gapOffset;
      if (localY <= lineTop + lines[i].height) {
        lineIndex = i;
        break;
      }
    }
    final line = lines[lineIndex];
    final localDx =
        (globalPosition.dx - widget.padding.left).clamp(0.0, columnWidth);
    final charIndex = _resolveCharacterIndexInLine(
      line: line,
      x: localDx,
      style: widget.textStyle,
      maxWidth: columnWidth,
    );
    return (lineIndex, charIndex);
  }

  /// 返回词边界 (start, end)，inclusive start, exclusive end。
  /// 复用与 _extractWordAtIndex 相同的扩展逻辑，直接返回索引避免 indexOf 二次查找。
  (int, int) _extractWordBoundsAtIndex(String text, int index) {
    if (text.isEmpty) return (0, 0);
    final normalized = text.trimRight();
    if (normalized.isEmpty) return (0, 0);
    var safeIndex = index.clamp(0, normalized.length - 1).toInt();
    // 空白字符：找最近非空白
    if (_isWhitespace(normalized[safeIndex])) {
      final left = _findNearestNonWhitespace(
          text: normalized, start: safeIndex, step: -1);
      final right = _findNearestNonWhitespace(
          text: normalized, start: safeIndex, step: 1);
      if (left == null && right == null)
        return (safeIndex, (safeIndex + 1).clamp(0, text.length));
      if (left == null) {
        safeIndex = right!;
      } else if (right == null) {
        safeIndex = left;
      } else {
        safeIndex = (safeIndex - left).abs() <= (right - safeIndex).abs()
            ? left
            : right;
      }
    }
    final current = normalized[safeIndex];
    if (!_isWordLike(current)) {
      return (safeIndex, (safeIndex + 1).clamp(0, text.length));
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
    return (start, end.clamp(0, text.length));
  }

  /// 构建选区覆盖层 Widget。
  Widget _buildSelectionOverlay(Size size) {
    final sel = _activeSelection;
    if (sel == null) return const SizedBox.shrink();
    final lines = _getSelectionLines();
    if (lines == null || lines.isEmpty) return const SizedBox.shrink();

    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final totalWidth = size.width - widget.padding.left - widget.padding.right;
    final columnWidth =
        _isDoublePage ? (totalWidth - _doublePageGutter) / 2 : totalWidth;
    final bodyOriginY = topSafe + _topOffset + widget.padding.top;
    final origin = Offset(widget.padding.left, bodyOriginY);

    final contentHeight = size.height -
        (systemPadding.top + _topOffset + widget.padding.top) -
        (systemPadding.bottom + _bottomOffset + widget.padding.bottom);
    final rects = LegacyJustifyPainter.resolveSelectionRects(
      lines: lines,
      startLineIndex: sel.startLineIndex,
      startCharIndex: sel.startCharIndex,
      endLineIndex: sel.endLineIndex,
      endCharIndex: sel.endCharIndex,
      style: widget.textStyle,
      maxWidth: columnWidth,
      origin: origin,
      bottomJustify: widget.settings.textBottomJustify,
      maxHeight: contentHeight,
    );

    if (rects.isEmpty) return const SizedBox.shrink();

    final firstRect = rects.first;
    final lastRect = rects.last;
    // 手柄圆点紧贴行底部（对标系统文本选择）
    final startHandlePos = Offset(firstRect.left, firstRect.bottom);
    final endHandlePos = Offset(lastRect.right, lastRect.bottom);

    final highlightColor =
        CupertinoColors.activeBlue.resolveFrom(context).withValues(alpha: 0.3);
    final handleColor = CupertinoColors.activeBlue.resolveFrom(context);

    return ReaderTextSelectionOverlay(
      key: _selectionOverlayKey,
      selectionRects: rects,
      startHandlePos: startHandlePos,
      endHandlePos: endHandlePos,
      selectedText: sel.selectedText,
      highlightColor: highlightColor,
      handleColor: handleColor,
      onDismiss: _clearSelection,
      onStartHandleDragUpdate: _onSelectionHandleStartDrag,
      onEndHandleDragUpdate: _onSelectionHandleEndDrag,
      onHandleDragEnd: _onSelectionHandleDragEnd,
      onCopy: widget.onCopySelectedText != null
          ? () {
              Clipboard.setData(ClipboardData(text: sel.selectedText));
              widget.onCopySelectedText!(sel.selectedText);
              _clearSelection();
            }
          : null,
      onBookmark: widget.onBookmarkSelectedText != null
          ? () {
              widget.onBookmarkSelectedText!(sel.selectedText);
              _clearSelection();
            }
          : null,
      onReadAloud: widget.onReadAloudSelectedText != null
          ? () {
              widget.onReadAloudSelectedText!(sel.selectedText);
              _clearSelection();
            }
          : null,
      onDict: widget.onDictSelectedText != null
          ? () {
              widget.onDictSelectedText!(sel.selectedText);
              _clearSelection();
            }
          : null,
      onSearchContent: widget.onSearchSelectedText != null
          ? () {
              widget.onSearchSelectedText!(sel.selectedText);
              _clearSelection();
            }
          : null,
      onShare: widget.onShareSelectedText != null
          ? () {
              widget.onShareSelectedText!(sel.selectedText);
              _clearSelection();
            }
          : null,
    );
  }

  String _resolveLongPressSelectedText(Offset globalPosition) {
    final pageData = _factory.curPageData;
    if (pageData.text.trim().isEmpty) return '';

    final size = MediaQuery.sizeOf(context);
    final contentWidth =
        size.width - widget.padding.left - widget.padding.right;
    if (!contentWidth.isFinite || contentWidth <= 0) return '';

    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final contentTop = topSafe + _topOffset + widget.padding.top;
    final contentLeft = widget.padding.left;
    final localY = globalPosition.dy - contentTop;
    if (!localY.isFinite || localY < 0) return '';

    // 优先使用预排版缓存（含标题行）
    final lines = pageData.precomposedLines ??
        LegacyJustifyComposer.composeContentLines(
          content: _stripImageMarkersFromContent(pageData.text),
          style: widget.textStyle,
          maxWidth: contentWidth,
          justify: widget.settings.textFullJustify,
          paragraphIndent: widget.settings.paragraphIndent,
          applyParagraphIndent: false,
          preserveEmptyLines: true,
          emptyLineHeight: widget.settings.paragraphSpacing > 0
              ? widget.settings.fontSize *
                  widget.settings.paragraphSpacing /
                  10.0
              : null,
        );
    if (lines.isEmpty) return '';

    LegacyComposedLine? targetLine;
    for (final line in lines) {
      if (line.isVisualEmpty) continue;
      if (localY <= line.lineStartY + line.height) {
        targetLine = line;
        break;
      }
    }
    targetLine ??= lines.lastWhere(
      (l) => !l.isVisualEmpty,
      orElse: () => lines.last,
    );

    final localDx = (globalPosition.dx - contentLeft).clamp(0.0, contentWidth);
    final effectiveStyle = (targetLine.isTitle && _resolvedTitleStyle != null)
        ? _resolvedTitleStyle!
        : widget.textStyle;
    final charIndex = _resolveCharacterIndexInLine(
      line: targetLine,
      x: localDx,
      style: effectiveStyle,
      maxWidth: contentWidth,
    );
    return _extractWordAtIndex(targetLine.plainText, charIndex);
  }
}
