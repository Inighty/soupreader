import '../../bookshelf/models/book.dart';
import 'reader_legacy_menu_helper.dart';

class ReaderRefreshSelection {
  final int startIndex;
  final bool clearFollowing;

  const ReaderRefreshSelection({
    required this.startIndex,
    required this.clearFollowing,
  });
}

class ReaderRefreshRangeResult {
  final int startIndex;
  final int endIndex;
  final List<Chapter> nextChapters;
  final List<Chapter> updates;

  const ReaderRefreshRangeResult({
    required this.startIndex,
    required this.endIndex,
    required this.nextChapters,
    required this.updates,
  });

  bool get hasRange => endIndex >= startIndex;
}

class ReaderRefreshScopeHelper {
  const ReaderRefreshScopeHelper._();

  static ReaderRefreshSelection selectionFromLegacyAction({
    required ReaderLegacyRefreshMenuAction action,
    required int currentChapterIndex,
  }) {
    switch (action) {
      case ReaderLegacyRefreshMenuAction.current:
        return ReaderRefreshSelection(
          startIndex: currentChapterIndex,
          clearFollowing: false,
        );
      case ReaderLegacyRefreshMenuAction.after:
        return ReaderRefreshSelection(
          startIndex: currentChapterIndex,
          clearFollowing: true,
        );
      case ReaderLegacyRefreshMenuAction.all:
        return const ReaderRefreshSelection(
          startIndex: 0,
          clearFollowing: true,
        );
    }
  }

  static ReaderRefreshRangeResult clearCachedRange({
    required List<Chapter> chapters,
    required int startIndex,
    required bool clearFollowing,
  }) {
    if (chapters.isEmpty) {
      return const ReaderRefreshRangeResult(
        startIndex: 0,
        endIndex: -1,
        nextChapters: <Chapter>[],
        updates: <Chapter>[],
      );
    }
    final safeStart = startIndex.clamp(0, chapters.length - 1).toInt();
    final safeEnd = clearFollowing ? chapters.length - 1 : safeStart;
    final nextChapters = List<Chapter>.from(chapters, growable: false);
    final updates = <Chapter>[];

    for (var index = safeStart; index <= safeEnd; index += 1) {
      final original = nextChapters[index];
      final cleared = original.copyWith(
        content: null,
        isDownloaded: false,
      );
      nextChapters[index] = cleared;
      if (original.isDownloaded || (original.content?.isNotEmpty ?? false)) {
        updates.add(cleared);
      }
    }

    return ReaderRefreshRangeResult(
      startIndex: safeStart,
      endIndex: safeEnd,
      nextChapters: nextChapters,
      updates: updates,
    );
  }
}
