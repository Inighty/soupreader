// ignore_for_file: invalid_use_of_protected_member
part of 'search_book_info_view.dart';

class _CupertinoCardContainer extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;

  const _CupertinoCardContainer({
    required this.padding,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = SourceUiTokens.borderWidth,
    this.borderRadius = SourceUiTokens.radiusCard,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBackground =
        backgroundColor ?? SourceUiTokens.resolveCardBackgroundColor(context);
    final resolvedBorder =
        borderColor ?? SourceUiTokens.resolveSeparatorColor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: resolvedBorder,
          width: borderWidth,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  final String coverUrl;
  final String title;
  final String author;

  const _HeroBackground({
    required this.coverUrl,
    required this.title,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    const blurSigma = 18.0;
    const blurScale = 1.08;

    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Transform.scale(
          scale: blurScale,
          child: AppCoverImage(
            urlOrPath: coverUrl,
            title: title,
            author: author,
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
            fit: BoxFit.cover,
            showTextOnPlaceholder: false,
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;
  final bool isLast;

  const _MetaLine({
    required this.icon,
    required this.text,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final borderColor = SourceUiTokens.resolveSeparatorColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: borderColor.withValues(alpha: 0.6),
                  width: SourceUiTokens.borderWidth,
                ),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: secondaryTextColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle.copyWith(
                fontSize: SourceUiTokens.itemMetaSize,
                color: secondaryTextColor,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _MetaActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _MetaActionChip({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final disabledColor = CupertinoColors.inactiveGray.resolveFrom(context);
    final resolvedColor = onPressed == null ? disabledColor : color;
    final resolvedBackground = resolvedColor.withValues(
      alpha: onPressed == null ? 0.10 : 0.14,
    );

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 0),
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: resolvedBackground,
          borderRadius: BorderRadius.circular(SourceUiTokens.radiusControl),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: textStyle.copyWith(
              fontSize: SourceUiTokens.itemMetaSize,
              fontWeight: FontWeight.w600,
              color: resolvedColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textStyle.copyWith(
          fontSize: SourceUiTokens.itemMetaSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchBookTocRuleUpdateResult {
  final List<TocItem> toc;
  final List<String> displayTitles;
  final bool splitLongChapterEnabled;
  final bool useReplaceEnabled;
  final bool loadWordCountEnabled;

  const _SearchBookTocRuleUpdateResult({
    required this.toc,
    required this.displayTitles,
    required this.splitLongChapterEnabled,
    required this.useReplaceEnabled,
    required this.loadWordCountEnabled,
  }) : assert(displayTitles.length == toc.length);
}

enum _SearchBookTocMenuAction {
  reverseToc,
  useReplace,
  loadWordCount,
  tocRule,
  splitLongChapter,
  exportBookmark,
  exportBookmarkMarkdown,
  log,
}

class _SearchBookTocView extends StatefulWidget {
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
  final Future<_SearchBookTocRuleUpdateResult?> Function()? onEditTocRule;
  final Future<_SearchBookTocRuleUpdateResult?> Function()?
      onToggleSplitLongChapter;
  final Future<_SearchBookTocRuleUpdateResult?> Function()? onToggleUseReplace;
  final Future<_SearchBookTocRuleUpdateResult?> Function()?
      onToggleLoadWordCount;
  final Future<void> Function()? onExportBookmark;
  final Future<void> Function()? onExportBookmarkMarkdown;

  const _SearchBookTocView({
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
  State<_SearchBookTocView> createState() => _SearchBookTocViewState();
}

class _SearchBookTocViewState extends State<_SearchBookTocView> {
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
  bool _runningUseReplaceAction = false;
  bool _runningLoadWordCountAction = false;
  bool _runningTocRuleAction = false;
  bool _runningSplitLongChapterAction = false;
  bool _runningExportBookmarkAction = false;
  bool _runningExportBookmarkMarkdownAction = false;
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
  void didUpdateWidget(covariant _SearchBookTocView oldWidget) {
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
    if (_runningUseReplaceAction ||
        _runningLoadWordCountAction ||
        _runningTocRuleAction ||
        _runningSplitLongChapterAction ||
        _runningExportBookmarkAction ||
        _runningExportBookmarkMarkdownAction) {
      return;
    }
    final items = <AppActionListItem<_SearchBookTocMenuAction>>[
      if (widget.showTxtTocRuleAction)
        const AppActionListItem<_SearchBookTocMenuAction>(
          value: _SearchBookTocMenuAction.tocRule,
          icon: CupertinoIcons.doc_text,
          label: 'TXT 目录规则',
        ),
      if (widget.showSplitLongChapterAction)
        AppActionListItem<_SearchBookTocMenuAction>(
          value: _SearchBookTocMenuAction.splitLongChapter,
          icon: _splitLongChapterEnabled
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.textformat_size,
          label: _splitLongChapterEnabled ? '✓ 拆分超长章节' : '拆分超长章节',
        ),
      const AppActionListItem<_SearchBookTocMenuAction>(
        value: _SearchBookTocMenuAction.reverseToc,
        icon: CupertinoIcons.arrow_up_arrow_down,
        label: '反转目录',
      ),
      if (widget.showUseReplaceAction)
        AppActionListItem<_SearchBookTocMenuAction>(
          value: _SearchBookTocMenuAction.useReplace,
          icon: _useReplaceEnabled
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.textformat,
          label: _useReplaceEnabled ? '✓ 使用替换' : '使用替换',
        ),
      if (widget.showLoadWordCountAction)
        AppActionListItem<_SearchBookTocMenuAction>(
          value: _SearchBookTocMenuAction.loadWordCount,
          icon: _loadWordCountEnabled
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.number,
          label: _loadWordCountEnabled ? '✓ 加载字数' : '加载字数',
        ),
      if (widget.showExportBookmarkAction)
        const AppActionListItem<_SearchBookTocMenuAction>(
          value: _SearchBookTocMenuAction.exportBookmark,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出',
        ),
      if (widget.showExportBookmarkAction)
        const AppActionListItem<_SearchBookTocMenuAction>(
          value: _SearchBookTocMenuAction.exportBookmarkMarkdown,
          icon: CupertinoIcons.doc_text_fill,
          label: '导出(MD)',
        ),
      const AppActionListItem<_SearchBookTocMenuAction>(
        value: _SearchBookTocMenuAction.log,
        icon: CupertinoIcons.doc_text_search,
        label: '日志',
      ),
    ];
    final selected = await showAppActionListSheet<_SearchBookTocMenuAction>(
      context: context,
      title: '目录操作',
      showCancel: true,
      items: items,
    );
    if (selected == null) return;
    switch (selected) {
      case _SearchBookTocMenuAction.reverseToc:
        _toggleReverseToc();
        return;
      case _SearchBookTocMenuAction.useReplace:
        await _runUseReplaceAction();
        return;
      case _SearchBookTocMenuAction.loadWordCount:
        await _runLoadWordCountAction();
        return;
      case _SearchBookTocMenuAction.tocRule:
        await _runTocRuleAction();
        return;
      case _SearchBookTocMenuAction.splitLongChapter:
        await _runSplitLongChapterAction();
        return;
      case _SearchBookTocMenuAction.exportBookmark:
        await _runExportBookmarkAction();
        return;
      case _SearchBookTocMenuAction.exportBookmarkMarkdown:
        await _runExportBookmarkMarkdownAction();
        return;
      case _SearchBookTocMenuAction.log:
        await showAppLogDialog(context);
        return;
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

  Future<void> _runUseReplaceAction() async {
    final handler = widget.onToggleUseReplace;
    if (handler == null || _runningUseReplaceAction) return;
    setState(() => _runningUseReplaceAction = true);
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
        setState(() => _runningUseReplaceAction = false);
      }
    }
  }

  Future<void> _runLoadWordCountAction() async {
    final handler = widget.onToggleLoadWordCount;
    if (handler == null || _runningLoadWordCountAction) return;
    setState(() => _runningLoadWordCountAction = true);
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
        setState(() => _runningLoadWordCountAction = false);
      }
    }
  }

  Future<void> _runTocRuleAction() async {
    final handler = widget.onEditTocRule;
    if (handler == null || _runningTocRuleAction) return;
    setState(() => _runningTocRuleAction = true);
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
        setState(() => _runningTocRuleAction = false);
      }
    }
  }

  Future<void> _runSplitLongChapterAction() async {
    final handler = widget.onToggleSplitLongChapter;
    if (handler == null || _runningSplitLongChapterAction) return;
    setState(() => _runningSplitLongChapterAction = true);
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
        setState(() => _runningSplitLongChapterAction = false);
      }
    }
  }

  Future<void> _runExportBookmarkAction() async {
    final handler = widget.onExportBookmark;
    if (handler == null || _runningExportBookmarkAction) return;
    setState(() => _runningExportBookmarkAction = true);
    try {
      await handler();
    } finally {
      if (mounted) {
        setState(() => _runningExportBookmarkAction = false);
      }
    }
  }

  Future<void> _runExportBookmarkMarkdownAction() async {
    final handler = widget.onExportBookmarkMarkdown;
    if (handler == null || _runningExportBookmarkMarkdownAction) return;
    setState(() => _runningExportBookmarkMarkdownAction = true);
    try {
      await handler();
    } finally {
      if (mounted) {
        setState(() => _runningExportBookmarkMarkdownAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final cardColor = SourceUiTokens.resolveCardBackgroundColor(context);
    final borderColor = SourceUiTokens.resolveSeparatorColor(context);
    final primaryTextColor = CupertinoColors.label.resolveFrom(context);
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
        if (_runningUseReplaceAction ||
            _runningLoadWordCountAction ||
            _runningTocRuleAction ||
            _runningSplitLongChapterAction ||
            _runningExportBookmarkAction ||
            _runningExportBookmarkMarkdownAction)
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
          onPressed: (_runningUseReplaceAction ||
                  _runningLoadWordCountAction ||
                  _runningTocRuleAction ||
                  _runningSplitLongChapterAction ||
                  _runningExportBookmarkAction ||
                  _runningExportBookmarkMarkdownAction)
              ? null
              : _showTocMenu,
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(entry.key),
                    child: _CupertinoCardContainer(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      backgroundColor: cardColor,
                      borderColor: borderColor,
                      borderWidth: SourceUiTokens.borderWidth,
                      borderRadius: SourceUiTokens.radiusCard,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${entry.key + 1}',
                              style: textStyle.copyWith(
                                fontSize: SourceUiTokens.itemMetaSize,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textStyle.copyWith(
                                fontSize: SourceUiTokens.actionTextSize,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          if (wordCountLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                wordCountLabel,
                                style: textStyle.copyWith(
                                  fontSize: SourceUiTokens.itemMetaSize,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
