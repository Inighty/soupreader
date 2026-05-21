// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderSelectionStart on _PagedReaderWidgetState {
  void _onTap(Offset position) {
    final action = _resolveClickAction(position);
    switch (action) {
      case ClickAction.showMenu:
        // 对标 legado：翻页动画进行中不响应菜单触发（MC 区域 !isAbortAnim 保护）
        if (!_isInteractionRunning) widget.onTap?.call();
        break;
      case ClickAction.nextPage:
        if (widget.enableGestures) {
          _nextPageByAnim(startY: position.dy);
        }
        break;
      case ClickAction.prevPage:
        if (widget.enableGestures) {
          _prevPageByAnim(startY: position.dy);
        }
        break;
      default:
        widget.onAction?.call(action);
    }
  }

  void _onLongPressStart(Offset globalPosition) {
    if (!mounted) return;
    if (!widget.enableGestures) return;
    if (_isInteractionRunning) return;

    // 选文模式
    if (widget.selectTextEnabled && !_isDoublePage) {
      _startTextSelection(globalPosition);
      return;
    }

    final callback = widget.onTextLongPress;
    if (callback == null) return;
    final text = _resolveLongPressSelectedText(globalPosition).trim();
    if (text.isEmpty) return;
    callback(
      PagedReaderLongPressSelection(
        text: text,
        globalPosition: globalPosition,
      ),
    );
  }

  void _startTextSelection(Offset globalPosition) {
    final result = _resolveSelectionHitResult(globalPosition);
    if (result == null) return;
    final (lineIndex, charIndex) = result;
    final lines = _getSelectionLines();
    if (lines == null || lineIndex >= lines.length) return;
    final line = lines[lineIndex];
    // 获取词边界作为初始选区
    final wordBounds = _extractWordBoundsAtIndex(line.plainText, charIndex);
    final selection = _TextSelection(
      startLineIndex: lineIndex,
      startCharIndex: wordBounds.$1,
      endLineIndex: lineIndex,
      endCharIndex: wordBounds.$2,
      selectedText: line.plainText.substring(
          wordBounds.$1.clamp(0, line.plainText.length),
          wordBounds.$2.clamp(0, line.plainText.length)),
    );
    setState(() {
      _activeSelection = selection;
    });
    // 菜单在手指抬起时弹出（onLongPressEnd），对标 legado ACTION_UP 触发
  }

  void _onSelectionHandleStartDrag(Offset globalPosition) {
    final result = _resolveSelectionHitResult(globalPosition);
    if (result == null || _activeSelection == null) return;
    final (lineIndex, charIndex) = result;
    final sel = _activeSelection!;
    final isAfterEnd = lineIndex > sel.endLineIndex ||
        (lineIndex == sel.endLineIndex && charIndex >= sel.endCharIndex);
    setState(() {
      if (isAfterEnd) {
        // 起始手柄拖过结束位置：交换，原结束变起始
        _activeSelection = _rebuildSelection(
          startLineIndex: sel.endLineIndex,
          startCharIndex: sel.endCharIndex,
          endLineIndex: lineIndex,
          endCharIndex: charIndex,
        );
      } else {
        _activeSelection = _rebuildSelection(
          startLineIndex: lineIndex,
          startCharIndex: charIndex,
          endLineIndex: sel.endLineIndex,
          endCharIndex: sel.endCharIndex,
        );
      }
    });
  }

  void _onSelectionHandleEndDrag(Offset globalPosition) {
    final result = _resolveSelectionHitResult(globalPosition);
    if (result == null || _activeSelection == null) return;
    final (lineIndex, charIndex) = result;
    final sel = _activeSelection!;
    final isBeforeStart = lineIndex < sel.startLineIndex ||
        (lineIndex == sel.startLineIndex && charIndex <= sel.startCharIndex);
    setState(() {
      if (isBeforeStart) {
        // 结束手柄拖过起始位置：交换，原起始变结束
        _activeSelection = _rebuildSelection(
          startLineIndex: lineIndex,
          startCharIndex: charIndex,
          endLineIndex: sel.startLineIndex,
          endCharIndex: sel.startCharIndex,
        );
      } else {
        _activeSelection = _rebuildSelection(
          startLineIndex: sel.startLineIndex,
          startCharIndex: sel.startCharIndex,
          endLineIndex: lineIndex,
          endCharIndex: charIndex,
        );
      }
    });
  }

  void _onSelectionHandleDragEnd() {
    _selectionOverlayKey.currentState?.showMenu();
  }

  void _clearSelection() {
    setState(() {
      _activeSelection = null;
      _selectionLines = null;
    });
  }

  _TextSelection _rebuildSelection({
    required int startLineIndex,
    required int startCharIndex,
    required int endLineIndex,
    required int endCharIndex,
  }) {
    final lines = _getSelectionLines();
    final buffer = StringBuffer();
    if (lines != null) {
      for (var i = startLineIndex; i <= endLineIndex && i < lines.length; i++) {
        final line = lines[i];
        final s = (i == startLineIndex) ? startCharIndex : 0;
        final e = (i == endLineIndex) ? endCharIndex : line.plainText.length;
        if (s < e && s >= 0 && e <= line.plainText.length) {
          buffer.write(line.plainText.substring(s, e));
        }
        if (i < endLineIndex) buffer.write('\n');
      }
    }
    return _TextSelection(
      startLineIndex: startLineIndex,
      startCharIndex: startCharIndex,
      endLineIndex: endLineIndex,
      endCharIndex: endCharIndex,
      selectedText: buffer.toString(),
    );
  }
}
