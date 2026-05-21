// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderPrecache on _PagedReaderWidgetState {
  /// 拆分式预渲染：每帧最多生成一张 Picture，避免一次性生成导致拖拽/动画掉帧。
  void _schedulePrecache() {
    if (!mounted) return;
    if (!_needsPictureCache) return;
    if (_precacheScheduled) return;

    // 正在拖拽/动画时不预渲染，避免争用 UI 线程
    if (_gestureInProgress || _isMoved || _isRunning || _isStarted) return;

    _precacheScheduled = true;
    final epoch = ++_precacheEpoch;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheScheduled = false;
      if (!mounted) return;
      if (epoch != _precacheEpoch) return;
      if (_gestureInProgress || _isMoved || _isRunning || _isStarted) return;

      final size = MediaQuery.sizeOf(context);
      final didWork = _precacheOnePicture(size);
      if (_needsShaderImages) {
        _ensureShaderImages(
          size,
          allowRecord: true,
          requestVisualUpdate: false,
        );
      }
      if (didWork) {
        // 仍有缺口，继续调度下一帧
        _schedulePrecache();
      }
    });
  }

  bool _precacheOnePicture(Size size) {
    _ensurePictureCacheSize(size);
    _syncAdjacentPictureAvailability();

    if (_curPagePicture == null &&
        _shouldUsePicturePathForContent(_factory.curPage)) {
      _curPagePicture = _recordPage(
        _factory.curPageData,
        size,
        slot: PageRenderSlot.current,
        rightPageData: _isDoublePage ? _factory.nextPageData : null,
        rightRenderPosition:
            _isDoublePage ? _factory.resolveRenderPositionByOffset(1) : null,
      );
      return true;
    }

    if (_factory.hasPrev() &&
        _prevPagePicture == null &&
        _shouldUsePicturePathForContent(_factory.prevPage)) {
      _prevPagePicture = _recordPage(
        _isDoublePage ? _factory.prevPrevPageData : _factory.prevPageData,
        size,
        slot: PageRenderSlot.prev,
        rightPageData: _isDoublePage ? _factory.prevPageData : null,
        rightRenderPosition:
            _isDoublePage ? _factory.resolveRenderPositionByOffset(-1) : null,
      );
      return true;
    }

    if (_factory.hasNext() &&
        _nextPagePicture == null &&
        _shouldUsePicturePathForContent(_factory.nextPage)) {
      _nextPagePicture = _recordPage(
        _isDoublePage ? _factory.nextNextPageData : _factory.nextPageData,
        size,
        slot: PageRenderSlot.next,
        rightPageData: _isDoublePage ? _factory.nextNextNextPageData : null,
        rightRenderPosition:
            _isDoublePage ? _factory.resolveRenderPositionByOffset(3) : null,
      );
      return true;
    }

    return false;
  }

  bool _isSimulationTurnReady(_PageDirection direction) {
    switch (direction) {
      case _PageDirection.next:
        return _curPageImage != null && _nextPagePicture != null;
      case _PageDirection.prev:
        return _targetPageImage != null && _curPagePicture != null;
      case _PageDirection.none:
        return false;
    }
  }

  Future<bool> _prepareSimulationTurnFrames({
    required Size size,
    required _PageDirection direction,
    required int token,
  }) async {
    if (direction == _PageDirection.none) return false;
    if (direction == _PageDirection.next && !_factory.hasNext()) return false;
    if (direction == _PageDirection.prev && !_factory.hasPrev()) return false;

    _ensureShaderImages(
      size,
      allowRecord: true,
      requestVisualUpdate: true,
    );
    if (_isSimulationTurnReady(direction)) return true;

    final deadline = DateTime.now().add(const Duration(milliseconds: 1800));
    while (mounted) {
      if (token != _simulationPrepareToken) return false;
      if (_isSimulationTurnReady(direction)) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return false;
      _ensureShaderImages(
        size,
        allowRecord: !_gestureInProgress,
        requestVisualUpdate: true,
      );
    }
    return false;
  }
}
