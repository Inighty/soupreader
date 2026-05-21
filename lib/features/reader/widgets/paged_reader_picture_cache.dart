// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderPictureCache on _PagedReaderWidgetState {
  void _invalidatePictures() {
    // 清除选文缓存（页面内容变化时选区失效）
    _activeSelection = null;
    _selectionLines = null;
    // 取消未执行的预渲染回调（通过 epoch 失效化）
    _precacheEpoch++;
    _curPagePicture?.dispose();
    _curPagePicture = null;
    _prevPagePicture?.dispose();
    _prevPagePicture = null;
    _nextPagePicture?.dispose();
    _nextPagePicture = null;
    _curPageImage?.dispose();
    _curPageImage = null;
    _targetPageImage?.dispose();
    _targetPageImage = null;
    _isCurImageLoading = false;
    _isTargetImageLoading = false;
  }

  void _invalidateTargetCache() {
    _targetPageImage?.dispose();
    _targetPageImage = null;
    _isTargetImageLoading = false;
  }

  void _cancelPendingSimulationPreparation() {
    _simulationPrepareToken++;
    _isPreparingSimulationTurn = false;
  }

  void _warmupSimulationFrames() {
    if (!mounted || !_needsShaderImages) return;
    final size = MediaQuery.sizeOf(context);
    _ensureShaderImages(
      size,
      allowRecord: true,
      requestVisualUpdate: false,
    );
  }

  Future<ui.Image> _convertToHighResImage(ui.Picture picture, Size size) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final int w = (size.width * dpr).toInt();
    final int h = (size.height * dpr).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    canvas.drawPicture(picture);
    final highResPicture = recorder.endRecording();

    final img = await highResPicture.toImage(w, h);
    // highResPicture.dispose(); // Picture.toImage consumes or we can dispose?
    // Actually ui.Picture.toImage doesn't consume, but we should dispose the picture after use.
    highResPicture.dispose();
    return img;
  }

  void _ensurePictureCacheSize(Size size) {
    if (_lastSize != size) {
      _invalidatePictures();
      _lastSize = size;
    }
  }

  void _syncAdjacentPictureAvailability() {
    if (!_factory.hasPrev()) {
      _prevPagePicture?.dispose();
      _prevPagePicture = null;
    }
    if (!_factory.hasNext()) {
      _nextPagePicture?.dispose();
      _nextPagePicture = null;
    }
  }

  bool _shouldUsePicturePathForContent(String content) {
    if (!_contentHasImageMarker(content)) {
      return true;
    }
    final mode = _effectivePageTurnMode;
    return mode == PageTurnMode.simulation || mode == PageTurnMode.simulation2;
  }

  String _contentForPictureSnapshot(String content) {
    if (!_contentHasImageMarker(content)) {
      return content;
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = ReaderImageMarkerCodec.decodeMetaLine(line) == null
          ? line
          : ReaderImageMarkerCodec.textFallbackPlaceholder;
      buffer.write(text);
      if (i != lines.length - 1) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  void _ensureCurrentPagePicture(
    Size size, {
    bool allowRecord = true,
  }) {
    _ensurePictureCacheSize(size);
    _syncAdjacentPictureAvailability();
    if (!allowRecord) return;
    if (!_shouldUsePicturePathForContent(_factory.curPage)) {
      _curPagePicture?.dispose();
      _curPagePicture = null;
      return;
    }
    _curPagePicture ??= _recordPage(
      _factory.curPageData,
      size,
      slot: PageRenderSlot.current,
      rightPageData: _isDoublePage ? _factory.nextPageData : null,
      rightRenderPosition:
          _isDoublePage ? _factory.resolveRenderPositionByOffset(1) : null,
    );
  }

  void _ensureDirectionTargetPicture(
    Size size, {
    required _PageDirection direction,
    bool allowRecord = true,
  }) {
    _ensureCurrentPagePicture(size, allowRecord: allowRecord);
    if (!allowRecord) return;

    if (direction == _PageDirection.prev && _factory.hasPrev()) {
      if (_shouldUsePicturePathForContent(_factory.prevPage)) {
        _prevPagePicture ??= _recordPage(
          _isDoublePage ? _factory.prevPrevPageData : _factory.prevPageData,
          size,
          slot: PageRenderSlot.prev,
          rightPageData: _isDoublePage ? _factory.prevPageData : null,
          rightRenderPosition:
              _isDoublePage ? _factory.resolveRenderPositionByOffset(-1) : null,
        );
      } else {
        _prevPagePicture?.dispose();
        _prevPagePicture = null;
      }
    } else if (direction == _PageDirection.next && _factory.hasNext()) {
      if (_shouldUsePicturePathForContent(_factory.nextPage)) {
        _nextPagePicture ??= _recordPage(
          _isDoublePage ? _factory.nextNextPageData : _factory.nextPageData,
          size,
          slot: PageRenderSlot.next,
          rightPageData: _isDoublePage ? _factory.nextNextNextPageData : null,
          rightRenderPosition:
              _isDoublePage ? _factory.resolveRenderPositionByOffset(3) : null,
        );
      } else {
        _nextPagePicture?.dispose();
        _nextPagePicture = null;
      }
    }
  }

  void _ensurePagePictures(Size size, {bool allowRecord = true}) {
    _ensureCurrentPagePicture(size, allowRecord: allowRecord);
    if (!allowRecord) return;

    // 相邻页：预渲染上一页/下一页，避免拖拽时临时生成导致卡顿
    if (_factory.hasPrev()) {
      if (_shouldUsePicturePathForContent(_factory.prevPage)) {
        _prevPagePicture ??= _recordPage(
          _isDoublePage ? _factory.prevPrevPageData : _factory.prevPageData,
          size,
          slot: PageRenderSlot.prev,
          rightPageData: _isDoublePage ? _factory.prevPageData : null,
          rightRenderPosition:
              _isDoublePage ? _factory.resolveRenderPositionByOffset(-1) : null,
        );
      } else {
        _prevPagePicture?.dispose();
        _prevPagePicture = null;
      }
    } else {
      _prevPagePicture?.dispose();
      _prevPagePicture = null;
    }

    if (_factory.hasNext()) {
      if (_shouldUsePicturePathForContent(_factory.nextPage)) {
        _nextPagePicture ??= _recordPage(
          _isDoublePage ? _factory.nextNextPageData : _factory.nextPageData,
          size,
          slot: PageRenderSlot.next,
          rightPageData: _isDoublePage ? _factory.nextNextNextPageData : null,
          rightRenderPosition:
              _isDoublePage ? _factory.resolveRenderPositionByOffset(3) : null,
        );
      } else {
        _nextPagePicture?.dispose();
        _nextPagePicture = null;
      }
    } else {
      _nextPagePicture?.dispose();
      _nextPagePicture = null;
    }
  }

  bool _shouldRebuildForShaderImageUpdate({
    required bool requestVisualUpdate,
  }) {
    if (requestVisualUpdate &&
        !_isInteractionRunning &&
        !_isPreparingSimulationTurn) {
      _debugTrace('skip_shader_setstate_when_idle');
    }
    return _isInteractionRunning || _isPreparingSimulationTurn;
  }

  void _ensureShaderImages(
    Size size, {
    bool allowRecord = true,
    bool requestVisualUpdate = false,
  }) {
    _ensurePagePictures(size, allowRecord: allowRecord);
    if (!_needsShaderImages) return;

    // 当前页 Image
    if (_curPagePicture != null &&
        _curPageImage == null &&
        !_isCurImageLoading) {
      _isCurImageLoading = true;
      _convertToHighResImage(_curPagePicture!, size).then((img) {
        if (!mounted) {
          img.dispose();
          _isCurImageLoading = false;
          return;
        }
        if (!_needsShaderImages) {
          img.dispose();
          _isCurImageLoading = false;
          return;
        }
        _curPageImage?.dispose();
        _curPageImage = img;
        _isCurImageLoading = false;
        if (_shouldRebuildForShaderImageUpdate(
          requestVisualUpdate: requestVisualUpdate,
        )) {
          setState(() {});
        }
      }).catchError((_) {
        _isCurImageLoading = false;
      });
    }

    // 目标页 Image
    final targetPicture = _direction == _PageDirection.next
        ? _nextPagePicture
        : _direction == _PageDirection.prev
            ? _prevPagePicture
            : null;

    if (targetPicture != null &&
        _targetPageImage == null &&
        !_isTargetImageLoading) {
      _isTargetImageLoading = true;
      _convertToHighResImage(targetPicture, size).then((img) {
        if (!mounted) {
          img.dispose();
          _isTargetImageLoading = false;
          return;
        }
        if (!_needsShaderImages) {
          img.dispose();
          _isTargetImageLoading = false;
          return;
        }
        _targetPageImage?.dispose();
        _targetPageImage = img;
        _isTargetImageLoading = false;
        if (_shouldRebuildForShaderImageUpdate(
          requestVisualUpdate: requestVisualUpdate,
        )) {
          setState(() {});
        }
      }).catchError((_) {
        _isTargetImageLoading = false;
      });
    }
  }
}
