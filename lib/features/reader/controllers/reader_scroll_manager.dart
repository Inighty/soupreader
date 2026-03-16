import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../models/reader_view_models.dart';

/// Callback invoked when the scroll view determines the visible chapter
/// has changed. The host should update currentChapterIndex/title/content
/// and call setState.
typedef ScrollChapterSyncCallback = void Function({
  required int chapterIndex,
  required String title,
  required String content,
});

/// Callback to load a scroll segment for a given chapter index.
typedef ScrollSegmentLoader = Future<ScrollSegment> Function(int chapterIndex);

/// Manages all scroll-mode state and logic.
///
/// Holds scroll segments, offset ranges, tip notifier, and provides
/// methods for appending/prepending segments, syncing chapter from
/// scroll position, calculating tip data, etc.
///
/// The host widget creates this in initState and passes it the
/// ScrollController. Methods that need to trigger widget rebuilds
/// invoke callbacks rather than calling setState directly.
class ReaderScrollManager {
  ReaderScrollManager({
    required this.scrollController,
    required this.onChapterSync,
    required this.loadSegment,
  });

  final ScrollController scrollController;
  final ScrollChapterSyncCallback onChapterSync;
  final ScrollSegmentLoader loadSegment;

  // ── State ──

  final List<ScrollSegment> segments = [];
  final Map<int, GlobalKey> segmentKeys = {};
  final Map<int, double> segmentHeights = {};
  final List<ScrollSegmentOffsetRange> segmentOffsetRanges = [];
  final GlobalKey viewportKey = GlobalKey(debugLabel: 'scroll_viewport');
  final ValueNotifier<ScrollTipData> tipNotifier = ValueNotifier(
    const ScrollTipData(
      title: '',
      bookTitle: '',
      bookProgress: 0,
      chapterProgress: 0,
      currentPage: 0,
      totalPages: 0,
      currentTime: '',
    ),
  );
  final ValueNotifier<int> segmentsVersion = ValueNotifier(0);

  bool appending = false;
  bool prepending = false;
  bool syncingVisibleChapter = false;
  int? pendingTargetChapterIndex;
  double? pendingTargetChapterProgress;
  bool pendingJumpToEnd = false;
  int pendingJumpRetry = 0;
  double currentChapterProgress = 0.0;
  bool programmaticScrollInFlight = false;
  double anchorWithinViewport = 32.0;



  // ── Segment management ──

  /// Initialize segments starting from a given chapter.
  Future<void> initializeSegments({
    required int centerIndex,
    required int chapterCount,
    double? targetProgress,
    bool jumpToEnd = false,
  }) async {
    segments.clear();
    segmentKeys.clear();
    segmentHeights.clear();
    segmentOffsetRanges.clear();

    if (centerIndex < 0 || centerIndex >= chapterCount) return;

    final segment = await loadSegment(centerIndex);
    segments.add(segment);
    segmentsVersion.value++;

    pendingTargetChapterIndex = centerIndex;
    pendingTargetChapterProgress = targetProgress;
    pendingJumpToEnd = jumpToEnd;
  }

  GlobalKey segmentKeyFor(int chapterIndex) {
    return segmentKeys.putIfAbsent(
      chapterIndex,
      () => GlobalKey(debugLabel: 'scroll_segment_$chapterIndex'),
    );
  }

  /// Append next chapter segment if the user has scrolled near the bottom.
  Future<void> appendNextIfNeeded({
    required int chapterCount,
  }) async {
    if (appending || segments.isEmpty) return;
    final lastIndex = segments.last.chapterIndex;
    if (lastIndex >= chapterCount - 1) return;

    appending = true;
    try {
      final segment = await loadSegment(lastIndex + 1);
      segments.add(segment);
      segmentsVersion.value++;
    } finally {
      appending = false;
    }
  }

  /// Prepend previous chapter segment if scrolled near the top.
  Future<void> prependPrevIfNeeded() async {
    if (prepending || segments.isEmpty) return;
    final firstIndex = segments.first.chapterIndex;
    if (firstIndex <= 0) return;

    prepending = true;
    try {
      final segment = await loadSegment(firstIndex - 1);
      segments.insert(0, segment);
      segmentsVersion.value++;
    } finally {
      prepending = false;
    }
  }

  /// Trim segments to keep memory bounded.
  void trimWindow({int maxSegments = 7}) {
    if (segments.length <= maxSegments) return;
    // Keep segments around the current visible one
    // This is a simplified version - the full logic is more complex
    while (segments.length > maxSegments) {
      segments.removeLast();
    }
    segmentsVersion.value++;
  }

  // ── Offset tracking ──

  void refreshHeights() {
    for (final segment in segments) {
      final key = segmentKeys[segment.chapterIndex];
      if (key == null) continue;
      final renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        segmentHeights[segment.chapterIndex] = renderBox.size.height;
      }
    }
    rebuildOffsetRanges();
  }

  void rebuildOffsetRanges() {
    segmentOffsetRanges.clear();
    double offset = 0;
    for (final segment in segments) {
      final height =
          segmentHeights[segment.chapterIndex] ?? segment.estimatedHeight;
      segmentOffsetRanges.add(ScrollSegmentOffsetRange(
        segment: segment,
        start: offset,
        end: offset + height,
        height: height,
      ));
      offset += height;
    }
  }

  // ── Tip updates ──

  void updateTip({
    required String bookTitle,
    required double bookProgress,
    required String currentTime,
    required int totalPages,
    required int currentPage,
  }) {
    if (segments.isEmpty) return;
    final visible = _findVisibleSegment();
    if (visible == null) return;

    final newTip = ScrollTipData(
      title: visible.title,
      bookTitle: bookTitle,
      bookProgress: bookProgress,
      chapterProgress: currentChapterProgress,
      currentPage: currentPage,
      totalPages: totalPages,
      currentTime: currentTime,
    );
    if (tipNotifier.value != newTip) {
      tipNotifier.value = newTip;
    }
  }

  ScrollSegment? _findVisibleSegment() {
    if (segments.isEmpty) return null;
    if (!scrollController.hasClients) return segments.first;

    final scrollOffset = scrollController.offset;
    for (final range in segmentOffsetRanges) {
      if (scrollOffset >= range.start && scrollOffset < range.end) {
        return range.segment;
      }
    }
    return segments.first;
  }

  // ── Cleanup ──

  void dispose() {
    tipNotifier.dispose();
    segmentsVersion.dispose();
  }
}
