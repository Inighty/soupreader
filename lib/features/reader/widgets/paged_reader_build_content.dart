// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderBuildContent on _PagedReaderWidgetState {
  Widget _buildPageContent() {
    // 产品约束：除了“滚动”以外，所有翻页模式都只允许水平手势/水平渲染。
    // 说明：
    // - 滚动模式不使用 PagedReaderWidget（见 SimpleReaderView），因此这里直接兜底为水平。
    // - 这样即使历史配置里残留 `pageDirection=vertical`，也不会把 slide/cover/none/simulation 变成垂直翻页。
    final isVertical = false;
    // 只有启用手势且无活跃选区时才允许滑动翻页
    final enableDrag = widget.enableGestures && _activeSelection == null;

    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        if (_activeSelection != null) {
          _clearSelection();
          return;
        }
        _onTap(d.localPosition);
      },
      onLongPressStart: (widget.enableGestures && !_isInteractionRunning)
          ? (details) => _onLongPressStart(details.localPosition)
          : null,
      onLongPressEnd: widget.selectTextEnabled
          ? (_) {
              if (_activeSelection != null) {
                _selectionOverlayKey.currentState?.showMenu();
              }
            }
          : null,
      onLongPressMoveUpdate: widget.selectTextEnabled
          ? (details) {
              if (_activeSelection != null) {
                _onSelectionHandleEndDrag(details.globalPosition);
              }
            }
          : null,
      // 水平方向手势（仅在启用手势且为水平方向时）
      onHorizontalDragStart: (!isVertical && enableDrag) ? _onDragStart : null,
      onHorizontalDragUpdate:
          (!isVertical && enableDrag) ? _onDragUpdate : null,
      onHorizontalDragEnd: (!isVertical && enableDrag) ? _onDragEnd : null,
      // 垂直方向手势：按产品约束禁用（滚动模式不走这里）
      onVerticalDragStart: null,
      onVerticalDragUpdate: null,
      onVerticalDragEnd: null,
      child: Stack(
        children: [
          _buildAnimatedPages(),
          if (_activeSelection != null) _buildSelectionOverlay(size),
        ],
      ),
    );
  }

  Widget _buildAnimatedPages() {
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final isRunning = _isMoved || _isRunning || _isStarted;
    final effectiveMode = _effectivePageTurnMode;
    if (!isRunning) {
      // 静止态提前预渲染相邻页，避免首次拖拽时同步生成导致的卡顿
      _schedulePrecache();
    }

    // 计算偏移量（基于触摸点相对于起始点的位移）
    // 对于滑动/覆盖模式使用
    final offset = _touchX - _startX;

    switch (effectiveMode) {
      case PageTurnMode.slide:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        if (_needsPictureCache) {
          _ensureDirectionTargetPicture(
            size,
            direction: _direction,
            allowRecord: !_gestureInProgress,
          );
        }
        return _buildSlideAnimation(screenWidth, offset);
      case PageTurnMode.cover:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        if (_needsPictureCache) {
          _ensureDirectionTargetPicture(
            size,
            direction: _direction,
            allowRecord: !_gestureInProgress,
          );
        }
        return _buildCoverAnimation(screenWidth, offset);
      case PageTurnMode.simulation:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        return _buildSimulationAnimation(size);
      case PageTurnMode.simulation2:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        return _buildSimulation2Animation(size);
      case PageTurnMode.none:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        if (_needsPictureCache) {
          _ensureDirectionTargetPicture(
            size,
            direction: _direction,
            allowRecord: !_gestureInProgress,
          );
        }
        return _buildNoAnimation();
      default:
        return _buildSlideAnimation(screenWidth, offset);
    }
  }

  Widget _buildRecordedPage(
    ui.Picture? picture,
    PageData fallbackPageData, {
    required PageRenderSlot slot,
  }) {
    final fallbackContent = fallbackPageData.text;
    if (_contentHasImageMarker(fallbackContent)) {
      return _buildPageWidget(fallbackPageData, slot: slot);
    }
    // 对齐 legado：动画期间保持快照渲染路径稳定，避免因单帧缓存 miss 回退到 Widget
    // 引发页眉/正文二次重排。
    final resolvedPicture =
        picture ?? _resolveFallbackPictureForAnimation(slot);
    if (resolvedPicture == null) {
      final lockSnapshotDuringInteraction =
          _isInteractionRunning && _isLegacyNonSimulationMode;
      if (lockSnapshotDuringInteraction) {
        final emergencyPicture =
            _curPagePicture ?? _nextPagePicture ?? _prevPagePicture;
        if (emergencyPicture != null) {
          _debugTrace('interaction_running_emergency_picture slot=$slot');
          return RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _PagePicturePainter(emergencyPicture),
                isComplex: true,
              ),
            ),
          );
        }
        _debugTrace('interaction_running_block_widget_fallback slot=$slot');
        return Container(color: widget.backgroundColor);
      }
      return _buildPageWidget(fallbackPageData, slot: slot);
    }
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _PagePicturePainter(resolvedPicture),
          isComplex: true,
        ),
      ),
    );
  }

  ui.Picture? _resolveFallbackPictureForAnimation(PageRenderSlot slot) {
    if (!_isInteractionRunning) return null;
    switch (slot) {
      case PageRenderSlot.prev:
        return _prevPagePicture ?? _curPagePicture ?? _nextPagePicture;
      case PageRenderSlot.current:
        return _curPagePicture ?? _nextPagePicture ?? _prevPagePicture;
      case PageRenderSlot.next:
        return _nextPagePicture ?? _curPagePicture ?? _prevPagePicture;
    }
  }

  Widget _buildStaticRecordedPage(Size size) {
    if (_needsPictureCache) {
      // 静止态仅同步确保当前页快照，邻页通过分帧预渲染补齐，减少收尾重绘抖动。
      _ensureCurrentPagePicture(size, allowRecord: true);
    }
    return _buildRecordedPage(
      _curPagePicture,
      _factory.curPageData,
      slot: PageRenderSlot.current,
    );
  }
}
