import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/book.dart';
import '../services/reader_legacy_menu_helper.dart';
import 'reader_catalog_actions.dart';
import 'reader_catalog_bookmark_list.dart';
import 'reader_catalog_chapter_list.dart';
import 'reader_catalog_header.dart';
import 'reader_catalog_state_helpers.dart';

/// 阅读器目录/书签面板（对标 legado 目录抽屉交互）
///
/// - 暖色背景（类似 Legado）
/// - 顶部展示书籍信息
/// - Tab：目录 / 书签
/// - 工具按钮：清缓存、刷新（检查更新/重新拉取目录由外部注入）
class ReaderCatalogSheet extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final List<BookmarkEntity> bookmarks;

  /// 清理本书已缓存章节内容（不删除目录条目）
  final Future<ChapterCacheInfo> Function() onClearBookCache;

  /// 刷新目录（可实现为“检查更新/重新拉取目录”），返回刷新后的章节列表
  final Future<List<Chapter>> Function() onRefreshCatalog;

  final ValueChanged<int> onChapterSelected;
  final ValueChanged<BookmarkEntity> onBookmarkSelected;
  final Future<void> Function(BookmarkEntity bookmark) onDeleteBookmark;
  final Future<void> Function(BookmarkEntity bookmark)? onEditBookmark;
  final Map<int, String> initialDisplayTitlesByIndex;
  final Future<String> Function(Chapter chapter)? resolveDisplayTitle;
  final bool isLocalTxtBook;
  final bool initialUseReplace;
  final bool initialLoadWordCount;
  final bool initialSplitLongChapter;
  final ValueChanged<bool>? onUseReplaceChanged;
  final ValueChanged<bool>? onLoadWordCountChanged;
  final ValueChanged<bool>? onSplitLongChapterChanged;
  final Future<void> Function(bool splitLongChapter)? onApplySplitLongChapter;
  final Future<void> Function()? onOpenLogs;
  final Future<void> Function()? onExportBookmark;
  final Future<void> Function()? onExportBookmarkMarkdown;
  final VoidCallback? onEditTocRule;

  const ReaderCatalogSheet({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.chapters,
    required this.currentChapterIndex,
    required this.bookmarks,
    required this.onClearBookCache,
    required this.onRefreshCatalog,
    required this.onChapterSelected,
    required this.onBookmarkSelected,
    required this.onDeleteBookmark,
    this.onEditBookmark,
    this.initialDisplayTitlesByIndex = const <int, String>{},
    this.resolveDisplayTitle,
    this.isLocalTxtBook = false,
    this.initialUseReplace = false,
    this.initialLoadWordCount = false,
    this.initialSplitLongChapter = false,
    this.onUseReplaceChanged,
    this.onLoadWordCountChanged,
    this.onSplitLongChapterChanged,
    this.onApplySplitLongChapter,
    this.onOpenLogs,
    this.onExportBookmark,
    this.onExportBookmarkMarkdown,
    this.onEditTocRule,
  });

  @override
  State<ReaderCatalogSheet> createState() => _ReaderCatalogSheetState();
}

class _ReaderCatalogSheetState extends State<ReaderCatalogSheet> {
  int _selectedTab = 0; // 0=目录, 1=书签
  bool _isReversed = false;
  bool _busy = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final ReaderCatalogTitleResolver _titleResolver;
  late final ReaderCatalogScrollPositioner _scroller;

  late List<Chapter> _chapters;
  late List<BookmarkEntity> _bookmarks;
  bool _useReplace = false;
  bool _loadWordCount = false;
  bool _splitLongChapter = false;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;
  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
  Color get _panelBg =>
      CupertinoColors.systemGroupedBackground.resolveFrom(context);
  Color get _textStrong => CupertinoColors.label.resolveFrom(context);
  Color get _textNormal =>
      CupertinoColors.secondaryLabel.resolveFrom(context);
  Color get _textSubtle =>
      CupertinoColors.tertiaryLabel.resolveFrom(context);
  Color get _lineColor => CupertinoColors.separator.resolveFrom(context);
  Color get _cardMutedBg =>
      CupertinoColors.tertiarySystemFill.resolveFrom(context);

  @override
  void initState() {
    super.initState();
    _chapters = List<Chapter>.from(widget.chapters);
    _bookmarks = List<BookmarkEntity>.from(widget.bookmarks);
    _useReplace = widget.initialUseReplace;
    _loadWordCount = widget.initialLoadWordCount;
    _splitLongChapter = widget.initialSplitLongChapter;
    _titleResolver = ReaderCatalogTitleResolver(
      scheduleSetState: (fn) {
        if (mounted) setState(fn);
      },
      isStillMounted: () => mounted,
    );
    _scroller = ReaderCatalogScrollPositioner(
      scrollController: _scrollController,
    );
    _primeTitles(reset: true);
    _scheduleScroll();
  }

  @override
  void dispose() {
    _titleResolver.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderCatalogSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    final chapterListChanged = !identical(oldWidget.chapters, widget.chapters);
    final currentChapterChanged =
        oldWidget.currentChapterIndex != widget.currentChapterIndex;
    if (chapterListChanged || currentChapterChanged) {
      _chapters = List<Chapter>.from(widget.chapters);
      _scroller.reset();
      _scheduleScroll();
    }
    if (!identical(oldWidget.bookmarks, widget.bookmarks)) {
      _bookmarks = List<BookmarkEntity>.from(widget.bookmarks);
    }
    if (oldWidget.initialUseReplace != widget.initialUseReplace) {
      _useReplace = widget.initialUseReplace;
    }
    if (oldWidget.initialLoadWordCount != widget.initialLoadWordCount) {
      _loadWordCount = widget.initialLoadWordCount;
    }
    if (oldWidget.initialSplitLongChapter != widget.initialSplitLongChapter) {
      _splitLongChapter = widget.initialSplitLongChapter;
    }

    final resolverChanged =
        oldWidget.resolveDisplayTitle != widget.resolveDisplayTitle;
    final initialTitlesChanged = !identical(
      oldWidget.initialDisplayTitlesByIndex,
      widget.initialDisplayTitlesByIndex,
    );
    if (chapterListChanged || resolverChanged || initialTitlesChanged) {
      _primeTitles(reset: true);
    } else if (currentChapterChanged) {
      _titleResolver.resolveAroundCurrent(
        chapters: _chapters,
        currentChapterIndex: widget.currentChapterIndex,
        resolveDisplayTitle: widget.resolveDisplayTitle,
      );
    }
  }

  void _primeTitles({required bool reset}) {
    _titleResolver.prime(
      chapters: _chapters,
      currentChapterIndex: widget.currentChapterIndex,
      initialDisplayTitlesByIndex: widget.initialDisplayTitlesByIndex,
      resolveDisplayTitle: widget.resolveDisplayTitle,
      reset: reset,
    );
  }

  void _scheduleScroll() {
    _scroller.schedule(
      filteredChapters: _filterChapters(),
      currentIndex: widget.currentChapterIndex,
      isMounted: mounted,
      isChapterTab: _selectedTab == 0,
    );
  }

  List<Chapter> _filterChapters() {
    var list = _chapters;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((c) => c.title.toLowerCase().contains(q))
          .toList(growable: false);
    }
    if (_isReversed) {
      list = list.reversed.toList(growable: false);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDesignTokens.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const ReaderCatalogGrabber(),
            ReaderCatalogHeader(
              bookTitle: widget.bookTitle,
              bookAuthor: widget.bookAuthor,
              coverUrl: widget.coverUrl,
              chapterCount: _chapters.length,
              textStrong: _textStrong,
              textSubtle: _textSubtle,
            ),
            ReaderCatalogTabBar(
              selectedTab: _selectedTab,
              chapterCount: _chapters.length,
              bookmarkCount: _bookmarks.length,
              busy: _busy,
              accent: _accent,
              textNormal: _textNormal,
              lineColor: _lineColor,
              onSelectTab: _selectTab,
              onShowMoreActions: _showTocActionsMenu,
              onClearCache: _confirmClearCache,
              onRefreshCatalog: _refreshCatalog,
            ),
            ReaderCatalogSearchAndSort(
              controller: _searchController,
              selectedTab: _selectedTab,
              searchQuery: _searchQuery,
              totalChapterCount: _chapters.length,
              matchedChapterCount: _filterChapters().length,
              isReversed: _isReversed,
              textStrong: _textStrong,
              textNormal: _textNormal,
              textSubtle: _textSubtle,
              cardMutedBg: _cardMutedBg,
              onQueryChanged: _onSearchChanged,
              onToggleReverse: _toggleReverse,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _selectedTab = index;
      _searchQuery = '';
      _searchController.text = '';
      _scroller.reset();
    });
    _scheduleScroll();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _scroller.reset();
    });
    _scheduleScroll();
  }

  void _toggleReverse() {
    setState(() {
      _isReversed = !_isReversed;
      _scroller.reset();
    });
    _scheduleScroll();
  }

  Widget _buildBody() {
    if (_selectedTab == 0) {
      return ReaderCatalogChapterList(
        chapters: _chapters,
        currentChapterIndex: widget.currentChapterIndex,
        searchQuery: _searchQuery,
        isReversed: _isReversed,
        loadWordCount: _loadWordCount,
        scrollController: _scrollController,
        chapterKeyFor: _scroller.keyFor,
        displayTitleFor: _titleResolver.displayTitleFor,
        accent: _accent,
        textStrong: _textStrong,
        textSubtle: _textSubtle,
        lineColor: _lineColor,
        cardMutedBg: _cardMutedBg,
        isDark: _isDark,
        onChapterSelected: widget.onChapterSelected,
      );
    }
    return ReaderCatalogBookmarkList(
      bookmarks: _bookmarks,
      searchQuery: _searchQuery,
      accent: _accent,
      textStrong: _textStrong,
      textSubtle: _textSubtle,
      lineColor: _lineColor,
      onBookmarkSelected: widget.onBookmarkSelected,
      onDeleteBookmark: (bookmark) async {
        await widget.onDeleteBookmark(bookmark);
        if (!mounted) return;
        setState(() {
          _bookmarks.removeWhere((b) => b.id == bookmark.id);
        });
      },
      onEditBookmark: widget.onEditBookmark,
    );
  }

  void _showTocActionsMenu() {
    showReaderCatalogTocActionsMenu(
      context: context,
      bookmarkTab: _selectedTab == 1,
      isLocalTxt: widget.isLocalTxtBook,
      flags: ReaderCatalogTocFlags(
        isReversed: _isReversed,
        useReplace: _useReplace,
        loadWordCount: _loadWordCount,
        splitLongChapter: _splitLongChapter,
      ),
      onAction: _runTocAction,
    );
  }

  Future<void> _runTocAction(ReaderLegacyTocMenuAction action) async {
    switch (action) {
      case ReaderLegacyTocMenuAction.reverseToc:
        _toggleReverse();
        return;
      case ReaderLegacyTocMenuAction.useReplace:
        setState(() => _useReplace = !_useReplace);
        widget.onUseReplaceChanged?.call(_useReplace);
        _titleResolver.resetAfterReplaceToggle(
          chapters: _chapters,
          currentChapterIndex: widget.currentChapterIndex,
          resolveDisplayTitle: widget.resolveDisplayTitle,
        );
        _showToast(_useReplace ? '已开启目录替换规则' : '已关闭目录替换规则');
        return;
      case ReaderLegacyTocMenuAction.loadWordCount:
        setState(() => _loadWordCount = !_loadWordCount);
        widget.onLoadWordCountChanged?.call(_loadWordCount);
        return;
      case ReaderLegacyTocMenuAction.tocRule:
        widget.onEditTocRule != null
            ? widget.onEditTocRule!.call()
            : _showToast('当前书籍未接入 TXT 目录规则配置');
        return;
      case ReaderLegacyTocMenuAction.splitLongChapter:
        await _toggleSplitLongChapter();
        return;
      case ReaderLegacyTocMenuAction.exportBookmark:
        await _runOptionalCallback(
            widget.onExportBookmark, '当前书籍不支持导出书签');
        return;
      case ReaderLegacyTocMenuAction.exportMarkdown:
        await _runOptionalCallback(
            widget.onExportBookmarkMarkdown, '当前书籍不支持导出 Markdown');
        return;
      case ReaderLegacyTocMenuAction.log:
        await _runOptionalCallback(widget.onOpenLogs, '日志入口不可用');
        return;
    }
  }

  Future<void> _runOptionalCallback(
    Future<void> Function()? cb,
    String fallback,
  ) async {
    if (cb != null) {
      await cb();
    } else {
      _showToast(fallback);
    }
  }

  Future<void> _toggleSplitLongChapter() async {
    final next = !_splitLongChapter;
    setState(() => _busy = true);
    try {
      if (widget.onApplySplitLongChapter != null) {
        await widget.onApplySplitLongChapter!.call(next);
      }
      widget.onSplitLongChapterChanged?.call(next);
      if (!mounted) return;
      setState(() => _splitLongChapter = next);
      _showToast(next ? '已开启“分割长章节”' : '已关闭“分割长章节”，重新加载正文可能需要更长时间');
    } catch (error) {
      if (mounted) _showToast('切换分割长章节失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  int _estimateCachedChapters() => _chapters
      .where((c) => c.isDownloaded && (c.content?.isNotEmpty ?? false))
      .length;

  Future<void> _confirmClearCache() async {
    final cachedCount = _estimateCachedChapters();
    if (cachedCount <= 0) {
      _showToast('暂无可清理的章节缓存');
      return;
    }

    final ok = await confirmReaderCatalogClearCache(
      context: context,
      cachedCount: cachedCount,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final info = await widget.onClearBookCache();
      if (!mounted) return;
      setState(() {
        _chapters = _chapters
            .map((c) => c.isDownloaded
                ? c.copyWith(isDownloaded: false, content: null)
                : c)
            .toList(growable: false);
      });
      _showToast(
          '已清理：${info.chapters}章 / ${formatReaderCatalogBytes(info.bytes)}');
    } catch (e) {
      if (!mounted) return;
      _showToast('清理失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshCatalog() async {
    setState(() => _busy = true);
    final oldCount = _chapters.length;
    try {
      final updated = await widget.onRefreshCatalog();
      if (!mounted) return;
      setState(() {
        _chapters = List<Chapter>.from(updated);
        _scroller.reset();
      });
      _primeTitles(reset: true);
      _scheduleScroll();

      final diff = _chapters.length - oldCount;
      _showToast(diff > 0 ? '发现更新：新增 $diff 章' : '暂无更新');
    } catch (e) {
      if (!mounted) return;
      _showToast('刷新失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
