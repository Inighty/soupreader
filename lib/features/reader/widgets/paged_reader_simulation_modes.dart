// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderSimulationModes on _PagedReaderWidgetState {
  /// 仿真模式 - 对标 Legado SimulationPageDelegate.onDraw
  /// 关键：只在 isRunning (拖拽或动画) 时渲染仿真效果
  Widget _buildSimulationAnimation(Size size) {
    // === 对标 Legado: if (!isRunning) return ===
    // 静止状态直接返回当前页面Widget，不使用 CustomPaint
    // 这样避免了状态切换时的闪烁
    final isRunning = _isMoved || _isRunning || _isStarted;
    if (!isRunning || _pageCurlProgram == null) {
      return _buildStaticRecordedPage(size);
    }

    final isNext = _direction == _PageDirection.next;
    if (_direction == _PageDirection.none) {
      return _buildStaticRecordedPage(size);
    }
    if (isNext && _curPageImage == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPageData,
        slot: PageRenderSlot.current,
      );
    }
    if (!isNext && _targetPageImage == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPageData,
        slot: PageRenderSlot.current,
      );
    }

    // === P6: 仿真逻辑修正 ===
    // Next: Peel Current(Top) to reveal Next(Bottom). Curl from Right.
    // Prev: Un-curl Prev(Top) to cover Current(Bottom). Curl from Right (simulating unrolling).

    ui.Image? imageToCurl;
    ui.Picture? bottomPicture;
    double effectiveCornerX;

    if (isNext) {
      imageToCurl = _curPageImage;
      bottomPicture = _nextPagePicture;
      effectiveCornerX = _cornerX;
    } else {
      // Prev: Use Target as the Curling Page (Top), Current as Background (Bottom)
      imageToCurl = _targetPageImage;
      bottomPicture = _curPagePicture;
      // Force Corner to be Right side (simulating we are holding the right edge of the prev page)
      effectiveCornerX = size.width;
    }

    if (imageToCurl == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPageData,
        slot: PageRenderSlot.current,
      );
    }

    double simulationTouchX = _touchX;
    if (!isNext) {
      // Prev: Apply coordinate mapping to ensure the page un-curls from the left edge (0)
      // instead of starting half-open.
      // Relationship: FoldX = (TouchX + CornerX) / 2
      // We want FoldX = _touchX (approximately, for visual tracking).
      // Since CornerX = width, we solve: _touchX = (VirtualTouchX + width) / 2
      // => VirtualTouchX = 2 * _touchX - size.width
      simulationTouchX = 2 * _touchX - size.width;
    }

    return CustomPaint(
      size: size,
      painter: SimulationPagePainter(
        // Note: 'curPagePicture' arg is unused in Painter logic for shader mode or used as fallback
        // We only care about 'nextPagePicture' which is the Bottom Layer.
        curPagePicture: null,
        nextPagePicture: bottomPicture,
        touch: Offset(simulationTouchX, _touchY),
        viewSize: size,
        isTurnToNext: isNext,
        backgroundColor: widget.shaderBackgroundColor ?? widget.backgroundColor,
        cornerX: effectiveCornerX,
        cornerY: _cornerY,
        shaderProgram: _pageCurlProgram!,
        curPageImage: imageToCurl,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
    );
  }

  /// 仿真模式2 - 使用贝塞尔曲线（参考 flutter_novel）
  Widget _buildSimulation2Animation(Size size) {
    final isRunning = _isMoved || _isRunning || _isStarted;
    if (!isRunning) {
      return _buildStaticRecordedPage(size);
    }

    final isNext = _direction == _PageDirection.next;

    // 确保 Picture 已生成（拖拽期间如未命中缓存，则允许降级为普通渲染以避免卡顿）
    _ensurePagePictures(size, allowRecord: !_gestureInProgress);

    ui.Picture? pictureToCurl;
    ui.Picture? bottomPicture;
    double effectiveCornerX;

    if (isNext) {
      pictureToCurl = _curPagePicture;
      bottomPicture = _nextPagePicture;
      effectiveCornerX = _cornerX;
    } else {
      pictureToCurl = _prevPagePicture;
      bottomPicture = _curPagePicture;
      effectiveCornerX = size.width;
    }

    if (pictureToCurl == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPageData,
        slot: PageRenderSlot.current,
      );
    }

    double simulationTouchX = _touchX;
    if (!isNext) {
      simulationTouchX = 2 * _touchX - size.width;
    }

    return CustomPaint(
      size: size,
      painter: SimulationPagePainter2(
        curPagePicture: pictureToCurl,
        nextPagePicture: bottomPicture,
        touch: Offset(simulationTouchX, _touchY),
        viewSize: size,
        isTurnToNext: isNext,
        backgroundColor: widget.shaderBackgroundColor ?? widget.backgroundColor,
        cornerX: effectiveCornerX,
        cornerY: _cornerY,
      ),
    );
  }

  /// 无动画模式
  Widget _buildNoAnimation() {
    // 对齐 legado NoAnimPageDelegate：交互期间不渲染中间过渡帧，始终保持当前页。
    return _buildRecordedPage(
      _curPagePicture,
      _factory.curPageData,
      slot: PageRenderSlot.current,
    );
  }
}
