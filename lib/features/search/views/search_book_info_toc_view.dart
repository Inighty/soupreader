import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../settings/views/app_log_dialog.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../services/search_book_toc_filter_helper.dart';
import 'search_book_info_toc_widgets.dart';

class SearchBookTocUpdateResult {
  final List<TocItem> toc;
  final List<String> displayTitles;
  final bool splitLongChapterEnabled;
  final bool useReplaceEnabled;
  final bool loadWordCountEnabled;

  const SearchBookTocUpdateResult({
    required this.toc,
    required this.displayTitles,
    required this.splitLongChapterEnabled,
    required this.useReplaceEnabled,
    required this.loadWordCountEnabled,
  }) : assert(displayTitles.length == toc.length);
}

enum _RunningTocAction {
  useReplace,
  loadWordCount,
  tocRule,
  splitLongChapter,
  exportBookmark,
  exportBookmarkMarkdown,
}

class SearchBookTocView extends StatefulWidget {
  final String bookTitle;
  final String sourceName;
  final List<TocItem> toc;
  final List<String> displayTitles;
  final bool showTxtTocRuleAction;
  final bool showSplitLongChapterAction;
  final bool splitLongChapterEnabled;
  final bool showUseReplaceAction;
  final bool useReplaceEnabled;
  final bool showLoadWordCountAction;
  final bool loadWordCountEnabled;
  final bool showExportBookmarkAction;
  final Future<SearchBookTocUpdateResult?> Function()? onEditTocRule;
  final Future<SearchBookTocUpdateResult?> Function()? onToggleSplitLongChapter;
  final Future<SearchBookTocUpdateResult?> Function()? onToggleUseReplace;
  final Future<SearchBookTocUpdateResult?> Function()? onToggleLoadWordCount;
  final Future<void> Function()? onExportBookmark;
  final Future<void> Function()? onExportBookmarkMarkdown;

  const SearchBookTocView({
    super.key,
    required this.bookTitle,
    required this.sourceName,
    required this.toc,
    required this.displayTitles,
    this.showTxtTocRuleAction = false,
    this.showSplitLongChapterAction = false,
    this.splitLongChapterEnabled = false,
    this.showUseReplaceAction = true,
    this.useReplaceEnabled = false,
    this.showLoadWordCountAction = true,
    this.loadWordCountEnabled = true,
    this.showExportBookmarkAction = false,
    this.onEditTocRule,
    this.onToggleSplitLongChapter,
    this.onToggleUseReplace,
    this.onToggleLoadWordCount,
    this.onExportBookmark,
    this.onExportBookmarkMarkdown,
  }) : assert(displayTitles.length == toc.length);

  @override
  State<SearchBookTocView> createState() => _SearchBookTocViewState();
}
class _SearchBookTocViewState extends State<SearchBookTocView> {
  static const Key _menuSearchActionKey =
      Key('search_book_toc_menu_search_action');
  static const Key _menuSearchFieldKey =
      Key('search_book_toc_menu_search_field');
  static const Key _menuSearchCloseKey =
      Key('search_book_toc_menu_search_close');
  static const Key _menuMoreActionKey = Key('search_book_toc_menu_more_action');

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _searchExpanded = false;
  bool _reversed = false;
  final Set<_RunningTocAction> _running = <_RunningTocAction>{};
  late bool _useReplaceEnabled;
  late bool _loadWordCountEnabled;
  late bool _splitLongChapterEnabled;
  late List<TocItem> _toc;
  late List<String> _displayTitles;

  @override
  void initState() {
    super.initState();
    _toc = widget.toc;
    _displayTitles = widget.displayTitles;
    _useReplaceEnabled = widget.useReplaceEnabled;
    _loadWordCountEnabled = widget.loadWordCountEnabled;
    _splitLongChapterEnabled = widget.splitLongChapterEnabled;
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  @override
  void didUpdateWidget(covariant SearchBookTocView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.toc, widget.toc)) {
      _toc = widget.toc;
    }
    if (!listEquals(oldWidget.displayTitles, widget.displayTitles)) {
      _displayTitles = widget.displayTitles;
    }
    if (oldWidget.useReplaceEnabled != widget.useReplaceEnabled) {
      _useReplaceEnabled = widget.useReplaceEnabled;
    }
    if (oldWidget.loadWordCountEnabled != widget.loadWordCountEnabled) {
      _loadWordCountEnabled = widget.loadWordCountEnabled;
    }
    if (oldWidget.splitLongChapterEnabled != widget.splitLongChapterEnabled) {
      _splitLongChapterEnabled = widget.splitLongChapterEnabled;
    }
  }

  void _handleSearchFocusChange() {
    if (_searchFocusNode.hasFocus || !_searchExpanded || !mounted) return;
    setState(() {
      _searchExpanded = false;
    });
  }

  void _openSearch() {
    if (_searchExpanded) return;
    setState(() {
      _searchExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch({required bool clearQuery}) {
    if (!_searchExpanded && !(clearQuery && _searchQuery.isNotEmpty)) return;
    setState(() {
      _searchExpanded = false;
      if (clearQuery) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    _searchFocusNode.unfocus();
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<int, TocItem>> get _filtered {
    return SearchBookTocFilterHelper.filterEntries(
      toc: _toc,
      rawQuery: _searchQuery,
      reversed: _reversed,
    );
  }

  Future<void> _showTocMenu() async {
    if (_running.isNotEmpty) return;
    final items = buildSearchBookTocMenuItems(
      showTxtTocRuleAction: widget.showTxtTocRuleAction,
      showSplitLongChapterAction: widget.showSplitLongChapterAction,
      splitLongChapterEnabled: _splitLongChapterEnabled,
      showUseReplaceAction: widget.showUseReplaceAction,
      useReplaceEnabled: _useReplaceEnabled,
      showLoadWordCountAction: widget.showLoadWordCountAction,
      loadWordCountEnabled: _loadWordCountEnabled,
      showExportBookmarkAction: widget.showExportBookmarkAction,
    );
    final selected = await showAppActionListSheet<SearchBookTocMenuAction>(
      context: context,
      title: '目录操作',
      showCancel: true,
      items: items,
    );
    if (selected == null) return;
    switch (selected) {
      case SearchBookTocMenuAction.reverseToc:
        _toggleReverseToc();
      case SearchBookTocMenuAction.useReplace:
        await _runUpdateAction(
          widget.onToggleUseReplace,
          _RunningTocAction.useReplace,
        );
      case SearchBookTocMenuAction.loadWordCount:
        await _runUpdateAction(
          widget.onToggleLoadWordCount,
          _RunningTocAction.loadWordCount,
        );
      case SearchBookTocMenuAction.tocRule:
        await _runUpdateAction(
          widget.onEditTocRule,
          _RunningTocAction.tocRule,
        );
      case SearchBookTocMenuAction.splitLongChapter:
        await _runUpdateAction(
          widget.onToggleSplitLongChapter,
          _RunningTocAction.splitLongChapter,
        );
      case SearchBookTocMenuAction.exportBookmark:
        await _runVoidAction(
          widget.onExportBookmark,
          _RunningTocAction.exportBookmark,
        );
      case SearchBookTocMenuAction.exportBookmarkMarkdown:
        await _runVoidAction(
          widget.onExportBookmarkMarkdown,
          _RunningTocAction.exportBookmarkMarkdown,
        );
      case SearchBookTocMenuAction.log:
        await showAppLogDialog(context);
    }
  }

  void _toggleReverseToc() {
    setState(() => _reversed = !_reversed);
  }

  String? _resolveChapterWordCountLabel(TocItem item) {
    if (!_loadWordCountEnabled || item.isVolume) return null;
    final value = (item.wordCount ?? '').trim();
    if (value.isEmpty) return null;
    return value;
  }

  Future<void> _runUpdateAction(
    Future<SearchBookTocUpdateResult?> Function()? handler,
    _RunningTocAction key,
  ) async {
    if (handler == null || _running.contains(key)) return;
    setState(() => _running.add(key));
    try {
      final updated = await handler();
      if (!mounted || updated == null) return;
      if (updated.displayTitles.length != updated.toc.length) return;
      setState(() {
        _toc = updated.toc;
        _displayTitles = updated.displayTitles;
        _splitLongChapterEnabled = updated.splitLongChapterEnabled;
        _useReplaceEnabled = updated.useReplaceEnabled;
        _loadWordCountEnabled = updated.loadWordCountEnabled;
      });
    } finally {
      if (mounted) {
        setState(() => _running.remove(key));
      }
    }
  }

  Future<void> _runVoidAction(
    Future<void> Function()? handler,
    _RunningTocAction key,
  ) async {
    if (handler == null || _running.contains(key)) return;
    setState(() => _running.add(key));
    try {
      await handler();
    } finally {
      if (mounted) {
        setState(() => _running.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final filtered = _filtered;
    final searchAction = _searchExpanded
        ? AppNavBarButton(
            key: _menuSearchCloseKey,
            minimumSize: const Size(
              SourceUiTokens.minTapSize,
              SourceUiTokens.minTapSize,
            ),
            onPressed: () => _closeSearch(clearQuery: true),
            child: const Icon(CupertinoIcons.xmark, size: 18),
          )
        : AppNavBarButton(
            key: _menuSearchActionKey,
            minimumSize: const Size(
              SourceUiTokens.minTapSize,
              SourceUiTokens.minTapSize,
            ),
            onPressed: _openSearch,
            child: const Icon(CupertinoIcons.search, size: 18),
          );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        searchAction,
        if (_running.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: CupertinoActivityIndicator(radius: 8),
          ),
        AppNavBarButton(
          key: _menuMoreActionKey,
          minimumSize: const Size(
            SourceUiTokens.minTapSize,
            SourceUiTokens.minTapSize,
          ),
          onPressed: _running.isNotEmpty ? null : _showTocMenu,
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 18),
        ),
      ],
    );

    return AppCupertinoPageScaffold(
      title: '目录',
      middle: _searchExpanded
          ? SizedBox(
              width: 190,
              child: AppManageSearchField(
                key: _menuSearchFieldKey,
                controller: _searchController,
                focusNode: _searchFocusNode,
                placeholder: '搜索',
                onChanged: (value) => setState(() => _searchQuery = value),
                onSubmitted: (value) => setState(() => _searchQuery = value),
              ),
            )
          : null,
      trailing: trailing,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SourceUiTokens.pagePaddingHorizontal,
              10,
              SourceUiTokens.pagePaddingHorizontal,
              6,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.bookTitle} · ${widget.sourceName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textStyle.copyWith(
                  fontSize: SourceUiTokens.itemMetaSize,
                  color: secondaryTextColor,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SourceUiTokens.pagePaddingHorizontal,
              0,
              SourceUiTokens.pagePaddingHorizontal,
              6,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchQuery.trim().isEmpty
                    ? '共 ${_toc.length} 章'
                    : '匹配 ${filtered.length} 章',
                style: textStyle.copyWith(
                  fontSize: SourceUiTokens.itemMetaSize,
                  color: secondaryTextColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                SourceUiTokens.pagePaddingHorizontal,
                4,
                SourceUiTokens.pagePaddingHorizontal,
                12,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                final displayTitle = _displayTitles[entry.key];
                final wordCountLabel =
                    _resolveChapterWordCountLabel(entry.value);
                return SearchBookTocChapterRow(
                  chapterIndex: entry.key,
                  displayTitle: displayTitle,
                  item: entry.value,
                  wordCountLabel: wordCountLabel,
                  onTap: () => Navigator.of(context).pop(entry.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
