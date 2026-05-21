// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderGestures on _PagedReaderWidgetState {
  // === 对标 Legado HorizontalPageDelegate.onTouch ===
  void _onDragStart(DragStartDetails details) {
    if (!widget.enableGestures) return;
    // 对标 legado ACTION_DOWN：有活跃选区时，拖拽起始仅清除选区，不触发翻页
    if (_activeSelection != null) {
      _clearSelection();
      return;
    }
    _gestureInProgress = true;
    _cancelPendingSimulationPreparation();
    // 允许中断正在进行的动画，实现连续翻页
    _abortAnim();
    _setStartPoint(details.localPosition.dx, details.localPosition.dy);
    _isMoved = false;
    _isCancel = false;
    _direction = _PageDirection.none;
    if (_needsShaderImages) {
      final size = MediaQuery.sizeOf(context);
      _ensureShaderImages(
        size,
        allowRecord: true,
        requestVisualUpdate: false,
      );
    }
  }

  // === 对标 Legado HorizontalPageDelegate.onScroll ===
  void _onDragUpdate(DragUpdateDetails details) {
    // _onDragStart 已处理动画中断，此处直接处理拖拽

    final focusX = details.localPosition.dx;
    final focusY = details.localPosition.dy;

    // 判断是否移动了
    if (!_isMoved) {
      final deltaX = (focusX - _startX).abs();
      final deltaY = (focusY - _startY).abs();
      final distance = deltaX * deltaX + deltaY * deltaY;
      // 对齐 legado：0 使用系统 touch slop；非 0 直接作为阈值像素。
      final configuredSlop = widget.pageTouchSlop;
      final slop = configuredSlop == 0 ? kTouchSlop : configuredSlop.toDouble();
      final slopSquare = slop * slop; // 触发阈值

      _isMoved = distance > slopSquare;

      if (_isMoved) {
        // 先保存原始起始点用于方向判断
        final originalStartX = _startX;

        // 判断方向
        final goingRight = focusX - originalStartX > 0;

        if (goingRight) {
          // 向右滑动 = 上一页
          if (!_factory.hasPrev()) {
            _isMoved = false;
            return;
          }
          // 先设置起始点，再设置方向（这样角点计算使用最新坐标）
          _setStartPoint(focusX, focusY);
          _setDirection(_PageDirection.prev);
        } else {
          // 向左滑动 = 下一页
          if (!_factory.hasNext()) {
            _isMoved = false;
            return;
          }
          // 先设置起始点，再设置方向（这样角点计算使用最新坐标）
          _setStartPoint(focusX, focusY);
          _setDirection(_PageDirection.next);
        }
      }
    }

    if (_isMoved) {
      final size = MediaQuery.sizeOf(context);

      // === P3: 中间区域Y坐标强制调整（对标 Legado SimulationPageDelegate.onTouch）===
      double adjustedY = focusY;
      if (_effectivePageTurnMode == PageTurnMode.simulation) {
        // 中间区域：强制使用底边（仅保留中间区域点击的优化，移除上一页的强制锁定）
        // Fixed: Use 0.9 * height to create cone effect (avoid TouchY == CornerY)
        if (_startY > size.height / 3 && _startY < size.height * 2 / 3) {
          adjustedY = size.height * 0.9;
        }
        // 中间偏上区域且是下一页：强制使用顶边
        if (_startY > size.height / 3 &&
            _startY < size.height / 2 &&
            _direction == _PageDirection.next) {
          adjustedY = size.height * 0.1;
        }
      }

      // 判断是否取消（方向改变）
      _isCancel =
          _direction == _PageDirection.next ? focusX > _lastX : focusX < _lastX;
      _isRunning = true;

      // 设置触摸点
      _setTouchPoint(focusX, adjustedY);
      (context as Element).markNeedsBuild();
    }
  }

  // === 对标 Legado HorizontalPageDelegate.onTouch ACTION_UP ===
  void _onDragEnd(DragEndDetails details) {
    _gestureInProgress = false;
    if (!_isMoved) {
      _direction = _PageDirection.none;
      _flushPendingPictureInvalidationIfIdle();
      final refreshedPadding = _flushPendingSystemPaddingRefresh();
      if (refreshedPadding) {
        setState(() {});
      }
      _schedulePrecache();
      return;
    }

    // 开始动画（完成翻页或取消）
    _startTurnAnimation();
  }
}
