import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/models/book.dart';

/// 目录抽屉里的「显示标题异步解析」+「自动滚动到当前章」逻辑。
///
/// 把这段相对独立的副作用从 [ReaderCatalogSheet] State 抽离出来，
/// 主组件只负责传入 chapters / currentChapterIndex / setState 等，
/// 实现细节集中在本类。
class ReaderCatalogTitleResolver {
  ReaderCatalogTitleResolver({
    required this.scheduleSetState,
    required this.isStillMounted,
  });

  /// 用 setState 包裹一次 mutation。
  final void Function(VoidCallback fn) scheduleSetState;
  final bool Function() isStillMounted;

  final Map<int, String> displayTitlesByChapterIndex = <int, String>{};
  int _resolverToken = 0;

  String displayTitleFor(Chapter chapter) {
    return displayTitlesByChapterIndex[chapter.index] ?? chapter.title;
  }

  void cancel() {
    _resolverToken++;
  }

  /// 按 [initialDisplayTitlesByIndex] 预填，并在 [chapters] / [currentChapterIndex]
  /// 周边异步解析。
  ///
  /// [reset] 为 `true` 时清空旧值（章节列表整体替换时）。
  void prime({
    required List<Chapter> chapters,
    required int currentChapterIndex,
    required Map<int, String> initialDisplayTitlesByIndex,
    required Future<String> Function(Chapter chapter)? resolveDisplayTitle,
    required bool reset,
  }) {
    final seeded = _sanitizeInitial(
      chapters: chapters,
      initialDisplayTitlesByIndex: initialDisplayTitlesByIndex,
    );
    if (reset) {
      displayTitlesByChapterIndex
        ..clear()
        ..addAll(seeded);
    } else {
      displayTitlesByChapterIndex.addAll(seeded);
    }
    resolveAroundCurrent(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
      resolveDisplayTitle: resolveDisplayTitle,
    );
  }

  /// 切换「替换规则」后，清空已解析标题再重算。
  void resetAfterReplaceToggle({
    required List<Chapter> chapters,
    required int currentChapterIndex,
    required Future<String> Function(Chapter chapter)? resolveDisplayTitle,
  }) {
    _resolverToken++;
    scheduleSetState(displayTitlesByChapterIndex.clear);
    resolveAroundCurrent(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
      resolveDisplayTitle: resolveDisplayTitle,
    );
  }

  void resolveAroundCurrent({
    required List<Chapter> chapters,
    required int currentChapterIndex,
    required Future<String> Function(Chapter chapter)? resolveDisplayTitle,
  }) {
    if (resolveDisplayTitle == null || chapters.isEmpty) {
      _resolverToken++;
      return;
    }
    final token = ++_resolverToken;
    final start = _currentChapterListPosition(chapters, currentChapterIndex);
    unawaited(_resolveInDirection(
      resolver: resolveDisplayTitle,
      chapters: chapters,
      token: token,
      start: start,
      step: 1,
    ));
    unawaited(_resolveInDirection(
      resolver: resolveDisplayTitle,
      chapters: chapters,
      token: token,
      start: start - 1,
      step: -1,
    ));
  }

  Map<int, String> _sanitizeInitial({
    required List<Chapter> chapters,
    required Map<int, String> initialDisplayTitlesByIndex,
  }) {
    if (initialDisplayTitlesByIndex.isEmpty || chapters.isEmpty) {
      return const <int, String>{};
    }
    final validIndexes = chapters.map((chapter) => chapter.index).toSet();
    final sanitized = <int, String>{};
    for (final entry in initialDisplayTitlesByIndex.entries) {
      if (!validIndexes.contains(entry.key)) continue;
      if (entry.value.trim().isEmpty) continue;
      sanitized[entry.key] = entry.value;
    }
    return sanitized;
  }

  int _currentChapterListPosition(List<Chapter> chapters, int currentIndex) {
    for (var i = 0; i < chapters.length; i++) {
      if (chapters[i].index == currentIndex) return i;
    }
    return 0;
  }

  Future<void> _resolveInDirection({
    required Future<String> Function(Chapter chapter) resolver,
    required List<Chapter> chapters,
    required int token,
    required int start,
    required int step,
  }) async {
    if (step == 0) return;
    for (var i = start; i >= 0 && i < chapters.length; i += step) {
      if (!isStillMounted() || token != _resolverToken) return;
      final chapter = chapters[i];
      if (displayTitlesByChapterIndex.containsKey(chapter.index)) continue;
      var resolved = chapter.title;
      try {
        final title = await resolver(chapter);
        if (title.trim().isNotEmpty) {
          resolved = title;
        }
      } catch (_) {
        // 保持目录可用：单条解析失败时回退原始标题。
      }
      if (!isStillMounted() || token != _resolverToken) return;
      if (displayTitlesByChapterIndex[chapter.index] == resolved) continue;
      scheduleSetState(() {
        displayTitlesByChapterIndex[chapter.index] = resolved;
      });
    }
  }
}

/// 目录章节列表的「自动滚动到当前章」逻辑。
class ReaderCatalogScrollPositioner {
  ReaderCatalogScrollPositioner({required this.scrollController});

  final ScrollController scrollController;
  final Map<int, GlobalKey> _itemKeys = <int, GlobalKey>{};
  int? _lastTargetChapterIndex;
  bool _pendingPreciseScroll = false;

  static const double _itemExtent = 60;
  static const double _targetAlignment = 0.08;

  GlobalKey keyFor(int chapterIndex) {
    return _itemKeys.putIfAbsent(
      chapterIndex,
      () => GlobalKey(debugLabel: 'catalog_chapter_$chapterIndex'),
    );
  }

  void reset() {
    _lastTargetChapterIndex = null;
    _pendingPreciseScroll = false;
  }

  /// 把当前章前一项滚动到可视区顶部。
  ///
  /// [filteredChapters] 是经过搜索/反转过滤的章节顺序；[currentIndex] 是
  /// 实际章节的 `Chapter.index`，用于在过滤后的列表中找到对应位置。
  void schedule({
    required List<Chapter> filteredChapters,
    required int currentIndex,
    required bool isMounted,
    required bool isChapterTab,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted) return;
      _scrollNow(
        filteredChapters: filteredChapters,
        currentIndex: currentIndex,
        isMounted: isMounted,
        isChapterTab: isChapterTab,
      );
    });
  }

  void _scrollNow({
    required List<Chapter> filteredChapters,
    required int currentIndex,
    required bool isMounted,
    required bool isChapterTab,
  }) {
    if (!isChapterTab) return;
    if (!scrollController.hasClients) return;
    if (filteredChapters.isEmpty) return;

    int? visibleIndex;
    for (var i = 0; i < filteredChapters.length; i++) {
      if (filteredChapters[i].index == currentIndex) {
        visibleIndex = i;
        break;
      }
    }
    if (visibleIndex == null) return;

    final targetVisibleIndex = visibleIndex > 0 ? visibleIndex - 1 : 0;
    if (targetVisibleIndex < 0 ||
        targetVisibleIndex >= filteredChapters.length) {
      return;
    }

    final targetChapterIndex = filteredChapters[targetVisibleIndex].index;
    if (_lastTargetChapterIndex != targetChapterIndex) {
      final estimated = targetVisibleIndex * _itemExtent;
      scrollController.jumpTo(_clamp(estimated));
      _lastTargetChapterIndex = targetChapterIndex;
    }
    if (_pendingPreciseScroll) return;

    _pendingPreciseScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingPreciseScroll = false;
      if (!isMounted ||
          !isChapterTab ||
          !scrollController.hasClients) {
        return;
      }
      final targetContext = keyFor(targetChapterIndex).currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignment: _targetAlignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  double _clamp(double rawOffset) {
    final position = scrollController.position;
    return rawOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }
}
