import 'dart:async';

import 'package:flutter/cupertino.dart';

export 'auto_page_progress_line.dart';
export 'auto_read_panel.dart';

class AutoPager {
  static const int minSpeedSeconds = 1;
  static const int maxSpeedSeconds = 120;
  static const int defaultSpeedSeconds = 10;
  static const Duration _scrollTick = Duration(milliseconds: 16);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  int _speed = defaultSpeedSeconds;
  int get speed => _speed;

  AutoPagerMode _mode = AutoPagerMode.scroll;
  AutoPagerMode get mode => _mode;

  /// 翻页模式下当前页的进度（0.0 = 刚开始，1.0 = 即将翻页）
  double _pageProgress = 0.0;
  double get pageProgress => _pageProgress;

  int _pageStartTime = 0;

  Timer? _timer;
  Timer? _progressTimer;
  ScrollController? _scrollController;
  VoidCallback? _onNextPage;
  final List<VoidCallback> _listeners = [];

  void setScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  void setOnNextPage(VoidCallback callback) {
    _onNextPage = callback;
  }

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in _listeners) l();
  }

  void setSpeed(int speed) {
    _speed = speed.clamp(minSpeedSeconds, maxSpeedSeconds);
    if (_isRunning) {
      _timer?.cancel();
      _timer = null;
      _progressTimer?.cancel();
      _progressTimer = null;
      _mode == AutoPagerMode.scroll ? _startScrollMode() : _startPageMode();
    }
    _notifyListeners();
  }

  void setMode(AutoPagerMode mode) {
    _mode = mode;
    if (_isRunning) {
      _timer?.cancel();
      _timer = null;
      _progressTimer?.cancel();
      _progressTimer = null;
      _pageProgress = 0.0;
      _mode == AutoPagerMode.scroll ? _startScrollMode() : _startPageMode();
    }
    _notifyListeners();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _mode == AutoPagerMode.scroll ? _startScrollMode() : _startPageMode();
    _notifyListeners();
  }

  void _startScrollMode() {
    _timer = Timer.periodic(_scrollTick, (_) {
      final controller = _scrollController;
      if (controller == null || !controller.hasClients) return;
      final position = controller.position;
      final currentOffset = controller.offset;
      final maxOffset = position.maxScrollExtent;
      if (currentOffset >= maxOffset - 0.5) {
        _onNextPage?.call();
        return;
      }
      final viewport = position.viewportDimension;
      if (!viewport.isFinite || viewport <= 0) return;
      final pixelsPerMs = viewport / (_speed * 1000.0);
      final delta = pixelsPerMs * _scrollTick.inMilliseconds;
      if (delta <= 0) return;
      final nextOffset = (currentOffset + delta)
          .clamp(position.minScrollExtent, maxOffset)
          .toDouble();
      if (nextOffset <= currentOffset) return;
      try {
        controller.jumpTo(nextOffset);
      } catch (_) {
        return;
      }
      if (nextOffset >= maxOffset - 0.5) {
        _onNextPage?.call();
      }
    });
  }

  void _startPageMode() {
    _pageProgress = 0.0;
    _pageStartTime = DateTime.now().millisecondsSinceEpoch;
    final totalMs = _speed * 1000.0;
    _progressTimer = Timer.periodic(_scrollTick, (_) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _pageStartTime;
      _pageProgress = (elapsed / totalMs).clamp(0.0, 1.0);
      _notifyListeners();
    });
    _timer = Timer.periodic(Duration(seconds: _speed), (_) {
      // 对标 legado autoPager.reset()：翻页后重置进度计时
      _pageProgress = 0.0;
      _pageStartTime = DateTime.now().millisecondsSinceEpoch;
      _onNextPage?.call();
    });
  }

  void pause() {
    if (!_isRunning) return;
    _timer?.cancel();
    _timer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _isRunning = false;
    _isPaused = true;
    _notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _pageProgress = 0.0;
    _isRunning = false;
    _isPaused = false;
    _notifyListeners();
  }

  void resume() {
    if (_isRunning) return;
    _isPaused = false;
    start();
  }

  void toggle() {
    if (_isRunning) {
      pause();
    } else if (_isPaused) {
      resume();
    } else {
      start();
    }
  }

  void dispose() {
    _progressTimer?.cancel();
    _progressTimer = null;
    stop();
    _listeners.clear();
    _scrollController = null;
    _onNextPage = null;
  }
}

enum AutoPagerMode { scroll, page }

extension AutoPagerModeLabel on AutoPagerMode {
  String get label => switch (this) {
        AutoPagerMode.scroll => '滚动模式',
        AutoPagerMode.page => '翻页模式',
      };
}
