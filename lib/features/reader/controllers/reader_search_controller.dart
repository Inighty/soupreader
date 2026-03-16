import 'dart:async';

import 'package:flutter/foundation.dart';

/// A single search match in the reader content.
class ReaderSearchHit {
  final int chapterIndex;
  final String chapterTitle;
  final int contentOffset;
  final int occurrenceIndex;
  final String matchText;
  final String contextBefore;
  final String contextAfter;

  const ReaderSearchHit({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.contentOffset,
    required this.occurrenceIndex,
    required this.matchText,
    required this.contextBefore,
    required this.contextAfter,
  });

  @override
  String toString() =>
      'SearchHit(ch=$chapterIndex, offset=$contentOffset, "$matchText")';
}

/// Stores the reader position before search was started so we can restore
/// it later.
class ReaderSearchProgressSnapshot {
  final int chapterIndex;
  final double chapterProgress;

  const ReaderSearchProgressSnapshot({
    required this.chapterIndex,
    required this.chapterProgress,
  });
}

/// Callback used by the controller to fetch chapter content for search.
typedef ChapterContentLoader = Future<String?> Function(
  int chapterIndex, {
  required int taskToken,
});

/// Manages the state machine for "search content within the book" feature.
///
/// Responsibilities:
/// - Execute a full-book search across chapters.
/// - Track the current hit, total hits, and search progress.
/// - Maintain a progress snapshot for restoring position after search.
///
/// UI rendering (overlay, highlight colors) remains in the View layer.
class ReaderSearchController extends ChangeNotifier {
  ReaderSearchController({
    required ChapterContentLoader contentLoader,
    required int Function() readableChapterCount,
    required String Function(int index) chapterTitleAt,
  })  : _contentLoader = contentLoader,
        _readableChapterCount = readableChapterCount,
        _chapterTitleAt = chapterTitleAt;

  // ── Dependencies (injected) ──

  final ChapterContentLoader _contentLoader;
  final int Function() _readableChapterCount;
  final String Function(int index) _chapterTitleAt;

  // ── State ──

  String _query = '';
  List<ReaderSearchHit> _hits = const [];
  int _currentHitIndex = -1;
  bool _isSearching = false;
  bool _useReplace = false;
  ReaderSearchProgressSnapshot? _progressSnapshot;
  int _taskToken = 0;

  // ── Getters ──

  String get query => _query;
  List<ReaderSearchHit> get hits => _hits;
  int get currentHitIndex => _currentHitIndex;
  bool get isSearching => _isSearching;
  bool get useReplace => _useReplace;
  ReaderSearchProgressSnapshot? get progressSnapshot => _progressSnapshot;

  bool get hasHits => _hits.isNotEmpty;
  ReaderSearchHit? get currentHit =>
      (_currentHitIndex >= 0 && _currentHitIndex < _hits.length)
          ? _hits[_currentHitIndex]
          : null;

  /// The query string to highlight in the reader, or `null` if search is not
  /// active.
  String? get activeHighlightQuery =>
      _query.isNotEmpty && _hits.isNotEmpty ? _query : null;

  // ── Actions ──

  /// Toggle whether replacement rules are applied during search.
  void toggleUseReplace() {
    _useReplace = !_useReplace;
    notifyListeners();
  }

  /// Save the current reading position before jumping around during search.
  void captureProgressSnapshot({
    required int chapterIndex,
    required double chapterProgress,
  }) {
    _progressSnapshot ??= ReaderSearchProgressSnapshot(
      chapterIndex: chapterIndex,
      chapterProgress: chapterProgress,
    );
  }

  /// Clear the progress snapshot (e.g. after the user confirms they don't
  /// want to restore).
  void clearProgressSnapshot() {
    _progressSnapshot = null;
  }

  /// Start a new search. Cancels any previous search in progress.
  ///
  /// [processContent] is an optional transform applied to chapter content
  /// before searching (e.g. replacement rules).
  Future<void> search(
    String query, {
    Future<String> Function(String raw, {required int taskToken})?
        processContent,
  }) async {
    if (query.trim().isEmpty) return;

    // Cancel any previous search.
    _taskToken++;
    final token = _taskToken;

    _query = query;
    _hits = const [];
    _currentHitIndex = -1;
    _isSearching = true;
    notifyListeners();

    final results = <ReaderSearchHit>[];
    final chapterCount = _readableChapterCount();

    for (int i = 0; i < chapterCount; i++) {
      if (_taskToken != token) return; // cancelled
      final raw = await _contentLoader(i, taskToken: token);
      if (_taskToken != token) return;
      if (raw == null || raw.isEmpty) continue;

      final content = processContent != null
          ? await processContent(raw, taskToken: token)
          : raw;
      if (_taskToken != token) return;

      final title = _chapterTitleAt(i);
      results.addAll(_collectHitsInChapter(
        chapterIndex: i,
        chapterTitle: title,
        content: content,
        query: query,
      ));
    }

    if (_taskToken != token) return;
    _hits = results;
    _currentHitIndex = results.isEmpty ? -1 : 0;
    _isSearching = false;
    notifyListeners();
  }

  /// Move to the next or previous hit.
  ///
  /// Returns the new current hit, or `null` if no hits.
  ReaderSearchHit? navigate(int delta) {
    if (_hits.isEmpty) return null;
    _currentHitIndex =
        (_currentHitIndex + delta).clamp(0, _hits.length - 1);
    notifyListeners();
    return currentHit;
  }

  /// Clear all search state and close the search session.
  void clear({bool clearSnapshot = true}) {
    _taskToken++;
    _query = '';
    _hits = const [];
    _currentHitIndex = -1;
    _isSearching = false;
    if (clearSnapshot) _progressSnapshot = null;
    notifyListeners();
  }

  // ── Internals ──

  List<ReaderSearchHit> _collectHitsInChapter({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
    required String query,
  }) {
    final lower = content.toLowerCase();
    final queryLower = query.toLowerCase();
    final hits = <ReaderSearchHit>[];
    var cursor = 0;
    var occurrence = 0;

    while (cursor < lower.length) {
      final idx = lower.indexOf(queryLower, cursor);
      if (idx < 0) break;

      const contextLen = 30;
      final beforeStart = (idx - contextLen).clamp(0, content.length);
      final afterEnd =
          (idx + query.length + contextLen).clamp(0, content.length);

      hits.add(ReaderSearchHit(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        contentOffset: idx,
        occurrenceIndex: occurrence,
        matchText: content.substring(idx, idx + query.length),
        contextBefore: content.substring(beforeStart, idx),
        contextAfter:
            content.substring(idx + query.length, afterEnd),
      ));
      occurrence++;
      cursor = idx + 1;
    }
    return hits;
  }
}
