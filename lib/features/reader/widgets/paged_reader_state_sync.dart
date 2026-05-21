// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderStateSync on _PagedReaderWidgetState {
  bool get _isInteractionRunning =>
      _gestureInProgress || _isMoved || _isRunning || _isStarted;

  void _debugTrace(String message) {
    assert(() {
      debugPrint('[PagedReaderWidget] $message');
      return true;
    }());
  }

  void _onPageFactoryContentChangedForRender() {
    if (!mounted) return;
    _cancelPendingSimulationPreparation();
    if (_isInteractionRunning) {
      _markPictureInvalidationPending();
      return;
    }
    _pendingPictureInvalidation = false;
    _invalidatePictures();
    setState(() {});
    _schedulePrecache();
  }

  void _markPictureInvalidationPending() {
    _pendingPictureInvalidation = true;
    _schedulePendingPictureInvalidationFlush();
  }

  void _schedulePendingPictureInvalidationFlush() {
    if (!mounted) return;
    if (_pendingPictureInvalidationFlushScheduled) return;
    _pendingPictureInvalidationFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingPictureInvalidationFlushScheduled = false;
      if (!mounted) return;
      _flushPendingPictureInvalidationIfIdle();
      if (_pendingPictureInvalidation) {
        _schedulePendingPictureInvalidationFlush();
      }
    });
  }

  void _flushPendingPictureInvalidationIfIdle({bool rebuild = true}) {
    if (!_pendingPictureInvalidation) return;
    if (_isInteractionRunning) return;
    _pendingPictureInvalidation = false;
    _invalidatePictures();
    if (rebuild && mounted) {
      setState(() {});
    }
  }

  Future<void> _loadShader() async {
    if (_pageCurlProgram != null) return;
    try {
      _pageCurlProgram = await ui.FragmentProgram.fromAsset(
          'lib/features/reader/shaders/page_curl.frag');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load shader: $e');
    }
  }

  Future<void> _initBattery() async {
    try {
      _applyBatteryLevel(await _battery.batteryLevel, forceRebuild: true);
      _batteryStateSubscription =
          _battery.onBatteryStateChanged.listen((state) {
        unawaited(_updateBatteryLevel());
      });
    } catch (_) {}
  }

  Future<void> _updateBatteryLevel() async {
    try {
      _applyBatteryLevel(await _battery.batteryLevel);
    } catch (_) {}
  }

  void _applyBatteryLevel(int rawLevel, {bool forceRebuild = false}) {
    final nextLevel = rawLevel.clamp(0, 100).toInt();
    final changed = _batteryLevel != nextLevel;
    _batteryLevel = nextLevel;
    if (!mounted) return;
    if (!changed && !forceRebuild) return;
    if (_isInteractionRunning && !forceRebuild) {
      if (_needsPictureCache) {
        _markPictureInvalidationPending();
      }
      return;
    }
    if (_needsPictureCache && _showAnyTipBar && widget.settings.showBattery) {
      _pendingPictureInvalidation = false;
      _invalidatePictures();
      _schedulePrecache();
    }
    setState(() {});
  }
}
