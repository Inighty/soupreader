// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderProgrammaticTurn on _PagedReaderWidgetState {
  void _startTurnAnimation() {
    if (_direction == _PageDirection.none) return;
    final effectiveMode = _effectivePageTurnMode;
    if (effectiveMode == PageTurnMode.none) {
      if (_needsPictureCache) {
        final size = MediaQuery.sizeOf(context);
        _ensureDirectionTargetPicture(
          size,
          direction: _direction,
          allowRecord: true,
        );
      }
      _completeNoAnimationTurn();
      return;
    }
    if (effectiveMode == PageTurnMode.simulation) {
      unawaited(_startSimulationTurnWhenReady());
      return;
    }
    if (_needsPictureCache) {
      final size = MediaQuery.sizeOf(context);
      _ensureDirectionTargetPicture(
        size,
        direction: _direction,
        allowRecord: true,
      );
    }
    if (effectiveMode == PageTurnMode.slide ||
        effectiveMode == PageTurnMode.cover) {
      _onAnimStartHorizontalLegacy();
      return;
    }
    _onAnimStart();
  }

  void _completeNoAnimationTurn() {
    final direction = _direction;
    final wasCancel = _isCancel;
    if (!wasCancel) {
      _fillPage(direction);
    }
    _stopScroll(direction: direction, wasCancel: wasCancel);
  }

  Future<void> _startSimulationTurnWhenReady() async {
    if (!mounted || _isPreparingSimulationTurn) return;
    if (_direction == _PageDirection.none) return;

    final direction = _direction;
    final token = ++_simulationPrepareToken;
    _isPreparingSimulationTurn = true;
    final size = MediaQuery.sizeOf(context);

    try {
      final ready = await _prepareSimulationTurnFrames(
        size: size,
        direction: direction,
        token: token,
      );
      if (!mounted || token != _simulationPrepareToken) return;
      if (_direction != direction) return;

      if (!ready) {
        _isMoved = false;
        _isRunning = false;
        _isStarted = false;
        _isCancel = false;
        _direction = _PageDirection.none;
        _touchX = _startX;
        _touchY = _startY;
        setState(() {});
        return;
      }
      _onAnimStart();
    } finally {
      if (token == _simulationPrepareToken) {
        _isPreparingSimulationTurn = false;
      }
    }
  }

  // === 对标 Legado: setStartPoint ===
  void _setStartPoint(double x, double y) {
    _startX = x;
    _startY = y;
    _lastX = x;
    _touchX = x;
    _touchY = y;
  }

  // === 对标 Legado: setTouchPoint ===
  void _setTouchPoint(double x, double y) {
    _lastX = _touchX;
    _touchX = x;
    _touchY = y;
  }

  // === 对标 Legado: nextPageByAnim ===
  bool _nextPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasNext()) return false;

    final size = MediaQuery.sizeOf(context);
    final touchStartY = startY ?? size.height * 0.9;
    final y = touchStartY > size.height / 2 ? size.height * 0.9 : 1.0;

    _setStartPoint(size.width * 0.9, y);
    _setDirection(_PageDirection.next);
    _startTurnAnimation();
    return true;
  }

  // === 对标 Legado: prevPageByAnim ===
  bool _prevPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasPrev()) return false;

    final size = MediaQuery.sizeOf(context);
    _setStartPoint(0, size.height);
    _setDirection(_PageDirection.prev);
    _startTurnAnimation();
    return true;
  }

  // === 对标 Legado: setDirection ===
  void _setDirection(_PageDirection direction) {
    _direction = direction;
    final size = MediaQuery.sizeOf(context);

    // === P2/P4: 在方向确定时计算角点（对标 Legado SimulationPageDelegate.setDirection）===
    if (direction == _PageDirection.prev) {
      // 上一页滑动不出现对角（原对标 Legado: 强制使用底边，现移除限制）
      // 现在跟随手指位置 (_startY)
      if (_startX > size.width / 2) {
        _calcCornerXY(_startX, _startY);
      } else {
        // P4: 左半边镜像处理
        _calcCornerXY(size.width - _startX, _startY);
      }
    } else if (direction == _PageDirection.next) {
      if (size.width / 2 > _startX) {
        // 左半边点击时，强制使用右边角点
        _calcCornerXY(size.width - _startX, _startY);
      } else {
        _calcCornerXY(_startX, _startY);
      }
    }

    _invalidateTargetCache();
    if (_needsShaderImages) {
      // 方向变化时立即准备目标帧，避免仿真模式在翻页完成后再异步补帧触发二次重绘。
      _ensureShaderImages(
        size,
        allowRecord: true,
        requestVisualUpdate: true,
      );
    }
    _schedulePrecache();
  }

  // === P2: 计算角点（对标 Legado calcCornerXY）===
  void _calcCornerXY(double x, double y) {
    final size = MediaQuery.sizeOf(context);
    _cornerX = x <= size.width / 2 ? 0 : size.width;
    _cornerY = y <= size.height / 2 ? 0 : size.height;
  }
}
