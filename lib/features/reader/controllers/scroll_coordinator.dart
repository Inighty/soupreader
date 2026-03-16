import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../models/reader_view_models.dart';
import 'reader_state.dart';

/// 构建滚动片段所需的参数。
typedef ScrollSegmentBuilder = Future<ScrollSegment> Function(
  int chapterIndex, {
  bool showLoading,
});

/// 滚动模式的逻辑委托。
///
/// 操作 [ScrollModeState] 和 [ChapterState]，不持有任何 Widget 引用。
/// 通过 [onChapterChanged] 回调通知 Coordinator 当前章节已变化。
class ScrollCoordinator {
  ScrollCoordinator({
    required this.scroll,
    required this.chapter,
    required this.settings,
    required this.buildSegment,
    required this.onChapterChanged,
    required this.onSaveProgress,
    required this.getBookProgress,
    required this.getCurrentTime,
  });

  final ScrollModeState scroll;
  final ChapterState chapter;
  final SettingsState settings;
  final ScrollSegmentBuilder buildSegment;
  final VoidCallback onChapterChanged;
  final Future<void> Function() onSaveProgress;
  final double Function() getBookProgress;
  final String Function() getCurrentTime;

  static const int _uiSyncIntervalMs = 100;
  static const int _saveProgressIntervalMs = 450;
  static const int _preloadIntervalMs = 80;
  static const double _preloadExtent = 280.0;
  static const int _maxSegmentWindow = 7;

  // ═══════════════════════════════════════════════════════════════════
  // 初始化
  // ═══════════════════════════════════════════════════════════════════

  Future<void> initializeSegments({
    required int centerIndex,
    bool restoreOffset = false,
    bool goToLastPage = false,
    double? targetChapterProgress,
  }) async {
    final count = chapter.readableCount;
    if (count <= 0) return;
    final max = count - 1;
    final safe = centerIndex.clamp(0, max);
    final start = (safe - 1).clamp(0, max);
    final end = (safe + 1).clamp(0, max);

    final newSegments = <ScrollSegment>[];
    for (var i = start; i <= end; i++) {
      newSegments.add(await buildSegment(i, showLoading: i == safe));
    }

    scroll.segments
      ..clear()
      ..addAll(newSegments);
    scroll.bumpVersion();

    scroll.pendingTargetIndex = safe;
    scroll.pendingTargetProgress = targetChapterProgress;
    scroll.pendingJumpToEnd = goToLastPage;

    // 更新当前章节
    final seg = newSegments.firstWhere(
      (s) => s.chapterIndex == safe,
      orElse: () => newSegments.first,
    );
    chapter.update(
      index: safe,
      title: seg.title,
      content: seg.content,
    );
    onChapterChanged();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 追加/预加载
  // ═══════════════════════════════════════════════════════════════════

  Future<void> appendNextIfNeeded() async {
    if (scroll.appending || scroll.segments.isEmpty) return;
    final lastIdx = scroll.segments.last.chapterIndex;
    if (lastIdx >= chapter.maxIndex) return;

    scroll.appending = true;
    try {
      final seg = await buildSegment(lastIdx + 1, showLoading: false);
      scroll.segments.add(seg);
      scroll.bumpVersion();
    } finally {
      scroll.appending = false;
    }
  }

  Future<void> prependPrevIfNeeded() async {
    if (scroll.prepending || scroll.segments.isEmpty) return;
    final firstIdx = scroll.segments.first.chapterIndex;
    if (firstIdx <= 0) return;

    scroll.prepending = true;
    try {
      final seg = await buildSegment(firstIdx - 1, showLoading: false);
      scroll.segments.insert(0, seg);
      scroll.bumpVersion();
    } finally {
      scroll.prepending = false;
    }
  }

  void trimWindow() {
    while (scroll.segments.length > _maxSegmentWindow) {
      scroll.segments.removeLast();
    }
    scroll.bumpVersion();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 偏移追踪
  // ═══════════════════════════════════════════════════════════════════

  void refreshHeights() {
    for (final seg in scroll.segments) {
      final key = scroll.segmentKeys[seg.chapterIndex];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        scroll.segmentHeights[seg.chapterIndex] = box.size.height;
      }
    }
    rebuildOffsetRanges();
  }

  void rebuildOffsetRanges() {
    scroll.offsetRanges.clear();
    double offset = 0;
    for (final seg in scroll.segments) {
      final h = scroll.segmentHeights[seg.chapterIndex] ?? seg.estimatedHeight;
      scroll.offsetRanges.add(ScrollSegmentOffsetRange(
        segment: seg,
        start: offset,
        end: offset + h,
        height: h,
      ));
      offset += h;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 滚动同步：识别当前可见章节
  // ═══════════════════════════════════════════════════════════════════

  void syncChapterFromScroll({bool saveProgress = false}) {
    final sc = scroll.controller;
    if (!sc.hasClients ||
        scroll.segments.isEmpty ||
        scroll.syncingVisibleChapter) {
      return;
    }
    scroll.syncingVisibleChapter = true;
    try {
      if (scroll.offsetRanges.length != scroll.segments.length) {
        rebuildOffsetRanges();
      }
      if (scroll.offsetRanges.isEmpty) return;

      final pos = sc.position;
      final anchor = (sc.offset + scroll.anchorWithinViewport)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent + pos.viewportDimension)
          .toDouble();

      ScrollSegmentOffsetRange? chosen;
      double progress = scroll.currentChapterProgress;
      double bestDist = double.infinity;

      for (final range in scroll.offsetRanges) {
        if (anchor >= range.start && anchor <= range.end) {
          chosen = range;
          progress = ((anchor - range.start) / range.height).clamp(0.0, 1.0);
          break;
        }
        final dist = anchor < range.start
            ? (range.start - anchor)
            : (anchor - range.end);
        if (dist < bestDist) {
          bestDist = dist;
          chosen = range;
          progress = ((anchor - range.start) / range.height).clamp(0.0, 1.0);
        }
      }

      final seg = chosen?.segment;
      if (seg == null) return;

      final chapterChanged = seg.chapterIndex != chapter.currentIndex;
      final progressChanged =
          (progress - scroll.currentChapterProgress).abs() > 0.02;
      if (!chapterChanged && !progressChanged) return;

      chapter.currentIndex = seg.chapterIndex;
      chapter.currentTitle = seg.title;
      chapter.currentContent = seg.content;
      scroll.currentChapterProgress = progress;

      updateTip();

      if (chapterChanged) onChapterChanged();

      if (saveProgress) {
        final now = DateTime.now();
        if (now.difference(scroll.lastProgressSyncAt).inMilliseconds >=
            _saveProgressIntervalMs) {
          scroll.lastProgressSyncAt = now;
          unawaited(onSaveProgress());
        }
      }
    } finally {
      scroll.syncingVisibleChapter = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 提示栏更新
  // ═══════════════════════════════════════════════════════════════════

  void updateTip() {
    final tip = ScrollTipData(
      title: chapter.currentTitle,
      bookTitle: '',
      bookProgress: getBookProgress(),
      chapterProgress: scroll.currentChapterProgress,
      currentPage: 0, // TODO: compute from layout
      totalPages: 0,
      currentTime: getCurrentTime(),
    );
    scroll.tipNotifier.value = tip;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 滚动事件处理
  // ═══════════════════════════════════════════════════════════════════

  void handleScrollTick() {
    if (scroll.programmaticScrollInFlight) return;

    final now = DateTime.now();

    // UI 同步（高频）
    if (now.difference(scroll.lastUiSyncAt).inMilliseconds >= _uiSyncIntervalMs) {
      scroll.lastUiSyncAt = now;
      syncChapterFromScroll(saveProgress: true);
    }

    // 预加载检查（低频）
    if (now.difference(scroll.lastPreloadCheckAt).inMilliseconds >=
        _preloadIntervalMs) {
      scroll.lastPreloadCheckAt = now;
      _checkPreload();
    }
  }

  void _checkPreload() {
    final sc = scroll.controller;
    if (!sc.hasClients) return;
    final pos = sc.position;
    final remaining = pos.maxScrollExtent - sc.offset;
    if (remaining < _preloadExtent) {
      unawaited(appendNextIfNeeded());
    }
    if (sc.offset < _preloadExtent) {
      unawaited(prependPrevIfNeeded());
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 翻页
  // ═══════════════════════════════════════════════════════════════════

  Future<void> scrollPage({required bool up}) async {
    final sc = scroll.controller;
    if (!sc.hasClients) return;
    final viewportHeight = sc.position.viewportDimension;
    final step = viewportHeight * 0.9;
    final target = up
        ? (sc.offset - step).clamp(0.0, sc.position.maxScrollExtent)
        : (sc.offset + step).clamp(0.0, sc.position.maxScrollExtent);

    scroll.programmaticScrollInFlight = true;
    try {
      await sc.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } finally {
      scroll.programmaticScrollInFlight = false;
    }

    syncChapterFromScroll(saveProgress: true);
  }

  GlobalKey segmentKeyFor(int chapterIndex) {
    return scroll.segmentKeys.putIfAbsent(
      chapterIndex,
      () => GlobalKey(debugLabel: 'scroll_seg_$chapterIndex'),
    );
  }
}
