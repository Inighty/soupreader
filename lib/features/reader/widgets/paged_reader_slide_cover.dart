// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderSlideCover on _PagedReaderWidgetState {
  /// 水平滑动模式
  Widget _buildSlideAnimation(double screenWidth, double offset) {
    final currentPage = _buildRecordedPage(
      _curPagePicture,
      _factory.curPageData,
      slot: PageRenderSlot.current,
    );
    if (_direction == _PageDirection.none) {
      return currentPage;
    }
    if ((_direction == _PageDirection.next && offset > 0) ||
        (_direction == _PageDirection.prev && offset < 0)) {
      return currentPage;
    }
    final distanceX = offset > 0 ? offset - screenWidth : offset + screenWidth;
    return Stack(
      children: [
        if (_direction == _PageDirection.prev)
          Transform.translate(
            offset: Offset(distanceX + screenWidth, 0),
            child: currentPage,
          ),
        if (_direction == _PageDirection.prev)
          Transform.translate(
            offset: Offset(distanceX, 0),
            child: _buildRecordedPage(
              _prevPagePicture,
              _factory.prevPageData,
              slot: PageRenderSlot.prev,
            ),
          ),
        if (_direction == _PageDirection.next)
          Transform.translate(
            offset: Offset(distanceX, 0),
            child: _buildRecordedPage(
              _nextPagePicture,
              _factory.nextPageData,
              slot: PageRenderSlot.next,
            ),
          ),
        if (_direction == _PageDirection.next)
          Transform.translate(
            offset: Offset(distanceX - screenWidth, 0),
            child: currentPage,
          ),
      ],
    );
  }

  /// 覆盖模式
  Widget _buildCoverAnimation(double screenWidth, double offset) {
    final currentPage = _buildRecordedPage(
      _curPagePicture,
      _factory.curPageData,
      slot: PageRenderSlot.current,
    );
    if (_direction == _PageDirection.none) {
      return currentPage;
    }
    if ((_direction == _PageDirection.next && offset > 0) ||
        (_direction == _PageDirection.prev && offset < 0)) {
      return currentPage;
    }
    final distanceX = offset > 0 ? offset - screenWidth : offset + screenWidth;

    if (_direction == _PageDirection.next) {
      final revealLeft =
          (screenWidth + offset).clamp(0.0, screenWidth).toDouble();
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              clipper: _CoverNextRevealClipper(left: revealLeft),
              child: _buildRecordedPage(
                _nextPagePicture,
                _factory.nextPageData,
                slot: PageRenderSlot.next,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(distanceX - screenWidth, 0),
            child: _buildRecordedPage(
              _curPagePicture,
              _factory.curPageData,
              slot: PageRenderSlot.current,
            ),
          ),
          _buildLegacyCoverShadow(left: distanceX, screenWidth: screenWidth),
        ],
      );
    }

    if (offset > screenWidth) {
      return Stack(
        children: [
          currentPage,
          _buildRecordedPage(
            _prevPagePicture,
            _factory.prevPageData,
            slot: PageRenderSlot.prev,
          ),
        ],
      );
    }

    return Stack(
      children: [
        currentPage,
        Transform.translate(
          offset: Offset(distanceX, 0),
          child: _buildRecordedPage(
            _prevPagePicture,
            _factory.prevPageData,
            slot: PageRenderSlot.prev,
          ),
        ),
        _buildLegacyCoverShadow(left: distanceX, screenWidth: screenWidth),
      ],
    );
  }

  Widget _buildLegacyCoverShadow({
    required double left,
    required double screenWidth,
  }) {
    if (left == 0) {
      return const SizedBox.shrink();
    }
    final x = left < 0 ? left + screenWidth : left;
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 30,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x66111111), Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }
}
