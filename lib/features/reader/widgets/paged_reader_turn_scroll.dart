// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderScrollTurn on _PagedReaderWidgetState {
  // === 对标 Legado: abortAnim ===
  void _abortAnim() {
    _cancelPendingSimulationPreparation();
    final committedDirection = _direction;
    _isStarted = false;
    _isMoved = false;
    _isRunning = false;
    if (_animController.isAnimating) {
      _animController.stop();
      if (!_isCancel && committedDirection != _PageDirection.none) {
        _fillPage(committedDirection);
        if (_needsPictureCache) {
          final promoted =
              _promoteCachedPicturesOnPageFilled(committedDirection);
          if (promoted) {
            _pendingPictureInvalidation = false;
          } else {
            _markPictureInvalidationPending();
          }
        }
        if (mounted) {
          setState(() {});
          _schedulePrecache();
        }
      }
    }
  }

  // === 对标 Legado: Cover/Slide onAnimStart ===
  void _onAnimStartHorizontalLegacy() {
    final size = MediaQuery.sizeOf(context);
    double distanceX;
    if (_direction == _PageDirection.next) {
      if (_isCancel) {
        var dis = size.width - _startX + _touchX;
        if (dis > size.width) {
          dis = size.width;
        }
        distanceX = size.width - dis;
      } else {
        distanceX = -(_touchX + (size.width - _startX));
      }
    } else {
      if (_isCancel) {
        distanceX = -(_touchX - _startX);
      } else {
        distanceX = size.width - (_touchX - _startX);
      }
    }
    _startScroll(_touchX, 0, distanceX, 0, widget.animDuration);
  }

  // === 对标 Legado: onAnimStart (SimulationPageDelegate) ===
  void _onAnimStart() {
    final size = MediaQuery.sizeOf(context);
    double dx, dy;

    // 使用预先计算的角点（对标 Legado mCornerX, mCornerY）
    // 不要重新计算，因为 _setDirection 已经计算好了

    if (_isCancel) {
      // === 取消翻页，回到原位 ===
      if (_cornerX > 0 && _direction == _PageDirection.next) {
        dx = size.width - _touchX;
      } else {
        dx = -_touchX;
      }
      if (_direction != _PageDirection.next) {
        dx = -(size.width + _touchX);
      }
      dy = _cornerY > 0 ? (size.height - _touchY) : -_touchY;
    } else {
      // === 完成翻页 ===
      if (_cornerX > 0 && _direction == _PageDirection.next) {
        dx = -(size.width + _touchX);
      } else {
        dx = size.width - _touchX;
      }
      dy = _cornerY > 0 ? (size.height - _touchY) : (1 - _touchY);
    }

    _startScroll(_touchX, _touchY, dx, dy, widget.animDuration);
  }

  // === 对标 Legado: startScroll ===
  // P5: 动态动画时长计算（对标 Legado PageDelegate.startScroll）
  void _startScroll(
      double startX, double startY, double dx, double dy, int animationSpeed) {
    final size = MediaQuery.sizeOf(context);
    int duration;
    if (dx != 0) {
      duration = (animationSpeed * dx.abs() / size.width).toInt();
    } else {
      duration = (animationSpeed * dy.abs() / size.height).toInt();
    }

    _scrollStartX = startX;
    _scrollStartY = startY;
    _scrollDx = dx;
    _scrollDy = dy;

    _isRunning = true;
    _isStarted = true;
    _animController.duration = Duration(milliseconds: duration);
    _animController.forward(from: 0);
  }

  // === 对标 Legado: computeScroll (由 AnimationController 驱动) ===
  void _computeScroll() {
    if (!_isStarted || !mounted) return;

    final progress = _animController.value;
    _touchX = _scrollStartX + _scrollDx * progress;
    _touchY = _scrollStartY + _scrollDy * progress;

    // 触发重绘
    (context as Element).markNeedsBuild();
  }

  // === 动画完成回调 ===
  void _onAnimComplete() {
    if (!_isStarted) return;
    final direction = _direction;
    final wasCancel = _isCancel;
    if (!wasCancel) {
      _fillPage(direction);
    }
    _stopScroll(direction: direction, wasCancel: wasCancel);
  }

  // === 对标 Legado: fillPage ===
  void _fillPage(_PageDirection direction) {
    if (direction == _PageDirection.next) {
      if (_isDoublePage) {
        _factory.moveToNextDouble();
      } else {
        _factory.moveToNext();
      }
    } else if (direction == _PageDirection.prev) {
      if (_isDoublePage) {
        _factory.moveToPrevDouble();
      } else {
        _factory.moveToPrev();
      }
    }
  }

  // === 对标 Legado: stopScroll ===
  bool _promoteCachedPicturesOnPageFilled(_PageDirection direction) {
    ui.Picture? oldCur = _curPagePicture;
    switch (direction) {
      case _PageDirection.next:
        final promotedCur = _nextPagePicture;
        if (promotedCur == null) return false;
        _prevPagePicture?.dispose();
        _curPagePicture = promotedCur;
        _prevPagePicture = oldCur;
        _nextPagePicture = null;
        break;
      case _PageDirection.prev:
        final promotedCur = _prevPagePicture;
        if (promotedCur == null) return false;
        _nextPagePicture?.dispose();
        _curPagePicture = promotedCur;
        _nextPagePicture = oldCur;
        _prevPagePicture = null;
        break;
      case _PageDirection.none:
        return false;
    }

    _invalidateTargetCache();
    _curPageImage?.dispose();
    _curPageImage = null;
    _isCurImageLoading = false;
    _syncAdjacentPictureAvailability();
    return true;
  }

  void _flushPendingPictureInvalidationAfterSettle({
    required _PageDirection settledDirection,
    required bool wasCancel,
  }) {
    if (!_pendingPictureInvalidation) return;
    if (_isInteractionRunning) return;

    final promoted =
        !wasCancel && _promoteCachedPicturesOnPageFilled(settledDirection);
    if (!promoted) {
      _invalidatePictures();
    }
    _pendingPictureInvalidation = false;
  }

  void _stopScroll({
    required _PageDirection direction,
    required bool wasCancel,
  }) {
    _isStarted = false;
    _isRunning = false;
    // 对齐 legado：动画完成后仅做状态收尾，不在此处触发换页。
    if (mounted) {
      _gestureInProgress = false;
      _isMoved = false;
      _isCancel = false;
      _direction = _PageDirection.none;

      // 重置坐标系统，确保下一次交互从干净状态开始。
      _touchX = 0.1;
      _touchY = 0.1;
      _startX = 0;
      _startY = 0;
      _lastX = 0;
      _scrollDx = 0;
      _scrollDy = 0;
      _cornerX = 0;
      _cornerY = 0;

      _flushPendingPictureInvalidationAfterSettle(
        settledDirection: direction,
        wasCancel: wasCancel,
      );
      _flushPendingSystemPaddingRefresh();
      setState(() {});
      _schedulePrecache();
    }
  }
}
