// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderMetrics on _PagedReaderWidgetState {
  PageFactory get _factory => widget.pageFactory;

  PageTurnMode get _effectivePageTurnMode => widget.pageTurnMode;

  bool _contentHasImageMarker(String content) {
    return ReaderImageMarkerCodec.containsMarker(content);
  }

  bool get _needsPictureCache =>
      _effectivePageTurnMode == PageTurnMode.simulation ||
      _effectivePageTurnMode == PageTurnMode.simulation2 ||
      _effectivePageTurnMode == PageTurnMode.slide ||
      _effectivePageTurnMode == PageTurnMode.cover ||
      _effectivePageTurnMode == PageTurnMode.none;

  bool get _needsShaderImages =>
      _effectivePageTurnMode == PageTurnMode.simulation;

  bool get _isLegacyNonSimulationMode =>
      _effectivePageTurnMode == PageTurnMode.slide ||
      _effectivePageTurnMode == PageTurnMode.cover ||
      _effectivePageTurnMode == PageTurnMode.none;

  bool get _hasHeaderSlot =>
      widget.settings.shouldShowHeader(showStatusBar: widget.showStatusBar);
  bool get _hasFooterSlot => widget.settings.shouldShowFooter();
  bool get _showHeader => widget.showTipBars && _hasHeaderSlot;
  bool get _showFooter => widget.showTipBars && _hasFooterSlot;
  bool get _showAnyTipBar => _showHeader || _showFooter;

  Color get _tipTextColor {
    final contentColor = widget.textStyle.color ?? const Color(0xff8B7961);
    return widget.settings.resolveTipTextColor(contentColor);
  }

  Color get _tipDividerColor {
    final defaultDivider = widget.textStyle.color?.withValues(alpha: 0.2) ??
        const Color(0x4C8B7961);
    return widget.settings.resolveTipDividerColor(
      contentColor: _tipTextColor,
      defaultDividerColor: defaultDivider,
    );
  }

  double get _headerSlotHeight {
    return PagedReaderWidget.resolveHeaderSlotHeight(
      settings: widget.settings,
      showStatusBar: widget.showStatusBar,
    );
  }

  double get _footerSlotHeight {
    return PagedReaderWidget.resolveFooterSlotHeight(
      settings: widget.settings,
    );
  }

  // 页眉/页脚占位保持稳定，避免仅隐藏提示条时正文发生上下跳动。
  double get _topOffset => _hasHeaderSlot ? _headerSlotHeight : 0.0;
  double get _bottomOffset => _hasFooterSlot ? _footerSlotHeight : 0.0;

  void _applyStableSystemPadding({
    required EdgeInsets padding,
    required Orientation orientation,
  }) {
    _stableSystemPadding = padding;
    _stablePaddingOrientation = orientation;
    _stableShowHeader = _hasHeaderSlot;
    _stableShowFooter = _hasFooterSlot;
    _pendingSystemPaddingRefresh = false;
    _debugTrace(
      'apply_stable_padding top=${padding.top.toStringAsFixed(1)} bottom=${padding.bottom.toStringAsFixed(1)} orientation=$orientation',
    );
  }

  bool _flushPendingSystemPaddingRefresh() {
    if (!_pendingSystemPaddingRefresh) return false;
    if (!mounted || _isInteractionRunning) return false;
    final mediaQuery = MediaQuery.of(context);
    _applyStableSystemPadding(
      padding: _resolveSystemPaddingForLayout(mediaQuery),
      orientation: mediaQuery.orientation,
    );
    _debugTrace('flush_pending_padding_refresh');
    return true;
  }

  EdgeInsets _resolveSystemPaddingForLayout(MediaQueryData mediaQuery) {
    final systemPadding = mediaQuery.padding;
    final viewPadding = mediaQuery.viewPadding;
    if (!widget.paddingDisplayCutouts) {
      return EdgeInsets.only(
        top: widget.showStatusBar ? systemPadding.top : 0.0,
        bottom: widget.settings.hideNavigationBar ? 0.0 : viewPadding.bottom,
      );
    }
    return EdgeInsets.only(
      left: viewPadding.left,
      top: widget.showStatusBar ? systemPadding.top : viewPadding.top,
      right: viewPadding.right,
      bottom: viewPadding.bottom,
    );
  }

  EdgeInsets _resolveStableSystemPadding() {
    final mediaQuery = MediaQuery.of(context);
    final mediaPadding = _resolveSystemPaddingForLayout(mediaQuery);
    final orientation = mediaQuery.orientation;
    final shouldRefresh = _stableSystemPadding == null ||
        _stablePaddingOrientation != orientation ||
        _stableShowHeader != _hasHeaderSlot ||
        _stableShowFooter != _hasFooterSlot ||
        _stableSystemPadding != mediaPadding;
    if (shouldRefresh) {
      if (_isInteractionRunning && _stableSystemPadding != null) {
        _pendingSystemPaddingRefresh = true;
        _debugTrace('defer_padding_refresh_during_interaction');
      } else {
        final paddingChanged = _stableSystemPadding != null &&
            _stableSystemPadding != mediaPadding;
        _applyStableSystemPadding(
          padding: mediaPadding,
          orientation: orientation,
        );
        if (paddingChanged && _needsPictureCache) {
          _invalidatePictures();
        }
      }
    }
    return _stableSystemPadding ?? mediaPadding;
  }

  bool get _isDoublePage => widget.settings.doublePage;
}
