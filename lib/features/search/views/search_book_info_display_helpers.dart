// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoDisplayHelpers on SearchBookInfoViewState {
  String get _displayName {
    final fromDetail = _detail?.name.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    return _activeResult.name.trim();
  }

  String get _displayAuthor {
    final fromDetail = _detail?.author.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    final fromResult = _activeResult.author.trim();
    return fromResult.isNotEmpty ? fromResult : '未知作者';
  }

  String get _displayCoverUrl {
    final fromDetail = _detail?.coverUrl.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    return _activeResult.coverUrl.trim();
  }

  String get _displayIntro {
    final fromDetail = _detail?.intro ?? '';
    if (fromDetail.trim().isNotEmpty) return fromDetail;
    final fromResult = _activeResult.intro;
    if (fromResult.trim().isNotEmpty) return fromResult;
    return '';
  }

  String get _displaySourceName {
    final fromSource = _source?.bookSourceName.trim() ?? '';
    if (fromSource.isNotEmpty) return fromSource;

    final fromResult = _activeResult.sourceName.trim();
    if (fromResult.isNotEmpty) return fromResult;

    final sourceUrl = (widget.bookshelfBook?.sourceUrl ??
            widget.bookshelfBook?.sourceId ??
            _activeResult.sourceUrl)
        .trim();
    return sourceUrl.isNotEmpty ? sourceUrl : '未知来源';
  }

  String _resolveTocMetaValue() {
    if (_loadingToc) return '加载中';
    if (_tocError != null && _toc.isEmpty) return '加载失败';
    if (_toc.isEmpty) return '暂无';

    var index = 0;
    final shelfBook = widget.bookshelfBook;
    if (shelfBook != null) {
      index = shelfBook.currentChapter;
    }

    final safeIndex = index.clamp(0, _toc.length - 1).toInt();
    final title = _toc[safeIndex].name.trim();
    if (title.isNotEmpty) return title;
    return '第${safeIndex + 1}章';
  }

  int _resolveChineseConverterType() {
    try {
      final rawType = _settingsService.readingSettings.chineseConverterType;
      if (ChineseConverterType.values.contains(rawType)) {
        return rawType;
      }
    } catch (_) {
      // 启动异常或测试环境下回退为关闭。
    }
    return ChineseConverterType.off;
  }

  Future<List<String>> _buildTocDisplayTitles(List<TocItem> toc) async {
    if (toc.isEmpty) return const <String>[];
    final sourceUrl = _activeResult.sourceUrl.trim();
    return _chapterTitleDisplayHelper.buildDisplayTitles(
      rawTitles: toc.map((item) => item.name).toList(growable: false),
      bookName: _displayName,
      sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
      chineseConverterType: _resolveChineseConverterType(),
      useReplaceRule: _tocUiUseReplace && _resolveBookUseReplaceRule(),
    );
  }

  bool _resolveBookUseReplaceRule() {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) return true;
    return _settingsService.getBookUseReplaceRule(id, fallback: true);
  }

  String? _pickFirstNonEmpty(List<String> candidates) {
    for (final raw in candidates) {
      final value = raw.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? _pickFirstNonBlankPreserve(List<String?> candidates) {
    for (final raw in candidates) {
      final value = raw ?? '';
      if (value.trim().isNotEmpty) return value;
    }
    return null;
  }

  Book? _resolveStoredBook() {
    final id = _bookId?.trim() ?? '';
    if (id.isEmpty) return widget.bookshelfBook;
    return _bookRepo.getBookById(id) ?? widget.bookshelfBook;
  }

  bool _isLocalBook() {
    return _resolveStoredBook()?.isLocal ?? false;
  }

  bool _isLocalTxtBook() {
    final book = _resolveStoredBook();
    if (book == null || !book.isLocal) return false;
    final lower = ((book.localPath ?? book.bookUrl ?? '')).toLowerCase();
    return lower.endsWith('.txt');
  }
}
