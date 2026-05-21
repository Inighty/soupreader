// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoSessionCache on SearchBookInfoViewState {
  String _buildSessionCacheKeyForResult(SearchResult value) {
    final sourceUrl = value.sourceUrl.trim().toLowerCase();
    final bookUrl = value.bookUrl.trim();
    if (sourceUrl.isEmpty || bookUrl.isEmpty) return '';
    return '$sourceUrl|$bookUrl';
  }

  String _buildSessionCacheKey() {
    return _buildSessionCacheKeyForResult(_activeResult);
  }

  bool _matchesActiveResult(Book shelfBook) {
    final activeSource = _normalize(_activeResult.sourceUrl);
    final activeBookUrl = _normalize(_activeResult.bookUrl);
    final shelfSource = _normalize(
      (shelfBook.sourceUrl ?? shelfBook.sourceId ?? ''),
    );
    final shelfBookUrl = _normalize(shelfBook.bookUrl ?? '');

    final sourceMatched = activeSource.isEmpty ||
        shelfSource.isEmpty ||
        activeSource == shelfSource;
    final bookMatched = activeBookUrl.isEmpty ||
        shelfBookUrl.isEmpty ||
        activeBookUrl == shelfBookUrl;
    return sourceMatched && bookMatched;
  }

  bool _hasUsableDetail(BookDetail? detail) {
    if (detail == null) return false;
    return detail.name.trim().isNotEmpty ||
        detail.author.trim().isNotEmpty ||
        detail.coverUrl.trim().isNotEmpty ||
        detail.intro.trim().isNotEmpty ||
        detail.lastChapter.trim().isNotEmpty;
  }

  _BookInfoSessionCacheEntry? _readSessionCacheEntry(String key) {
    if (key.isEmpty) return null;
    final entry = SearchBookInfoViewState._sessionCache.remove(key);
    if (entry == null) return null;
    final age = DateTime.now().difference(entry.savedAt);
    if (age > SearchBookInfoViewState._sessionCacheTtl) return null;
    if (entry.toc.isEmpty && !_hasUsableDetail(entry.detail)) return null;
    SearchBookInfoViewState._sessionCache[key] = entry;
    return entry;
  }

  void _writeSessionCacheEntry({
    required String key,
    required BookDetail? detail,
    required List<TocItem> toc,
  }) {
    if (key.isEmpty) return;
    final safeToc = List<TocItem>.from(toc);
    if (safeToc.isEmpty && !_hasUsableDetail(detail)) {
      SearchBookInfoViewState._sessionCache.remove(key);
      return;
    }
    SearchBookInfoViewState._sessionCache.remove(key);
    SearchBookInfoViewState._sessionCache[key] = _BookInfoSessionCacheEntry(
      detail: detail,
      toc: safeToc,
      savedAt: DateTime.now(),
    );
    while (SearchBookInfoViewState._sessionCache.length >
        SearchBookInfoViewState._maxSessionCacheEntries) {
      SearchBookInfoViewState._sessionCache.remove(
        SearchBookInfoViewState._sessionCache.keys.first,
      );
    }
  }

  void _removeSessionCacheEntry(String key) {
    if (key.isEmpty) return;
    SearchBookInfoViewState._sessionCache.remove(key);
  }

  String _normalize(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _buildEphemeralSessionId() {
    return SearchBookInfoViewState._uuid.v5(
      Namespace.url.value,
      'ephemeral|${_activeResult.sourceUrl.trim()}|${_activeResult.bookUrl.trim()}',
    );
  }
}
