class ReaderSearchNavigationHelper {
  const ReaderSearchNavigationHelper._();

  static int? resolvePageIndexByOccurrence({
    required List<String> pages,
    required String query,
    required int occurrenceIndex,
    String? chapterTitle,
    bool trimFirstPageTitlePrefix = false,
  }) {
    if (occurrenceIndex < 0 || pages.isEmpty) {
      return null;
    }
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return null;
    }

    var remaining = occurrenceIndex;
    for (var i = 0; i < pages.length; i++) {
      var pageText = pages[i];
      if (i == 0 && trimFirstPageTitlePrefix) {
        pageText = _stripFirstPageTitlePrefix(
          pageText: pageText,
          chapterTitle: chapterTitle,
        );
      }
      var from = 0;
      while (from < pageText.length) {
        final found = pageText.indexOf(normalizedQuery, from);
        if (found == -1) {
          break;
        }
        if (remaining == 0) {
          return i;
        }
        remaining -= 1;
        from = found + normalizedQuery.length;
      }
    }
    return null;
  }

  static int resolveNextHitIndex({
    required int currentIndex,
    required int delta,
    required int totalHits,
  }) {
    if (totalHits <= 0) {
      return -1;
    }
    final next = currentIndex + delta;
    if (next < 0) {
      return 0;
    }
    if (next >= totalHits) {
      return totalHits - 1;
    }
    return next;
  }

  static int? resolvePageIndexByOffset({
    required List<String> pages,
    required int contentOffset,
  }) {
    if (pages.isEmpty) {
      return null;
    }

    var cursor = 0;
    for (var i = 0; i < pages.length; i++) {
      final nextCursor = cursor + pages[i].length;
      if (contentOffset < nextCursor) {
        return i;
      }
      cursor = nextCursor;
    }
    return pages.length - 1;
  }

  static String _stripFirstPageTitlePrefix({
    required String pageText,
    required String? chapterTitle,
  }) {
    final title = chapterTitle?.trim() ?? '';
    if (title.isEmpty || !pageText.startsWith(title)) {
      return pageText;
    }
    var normalized = pageText.substring(title.length);
    if (normalized.startsWith('\n')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('\n')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }
}
