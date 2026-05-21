// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoTocActions on SearchBookInfoViewState {
  String? _resolveBookTxtTocRuleRegex(String bookId) {
    final regex = _settingsService.getBookTxtTocRule(bookId);
    if (regex == null) return null;
    final normalized = regex.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Future<List<TxtTocRuleOption>> _loadTxtTocRuleOptions() async {
    final enabledRules = await _txtTocRuleStore.loadEnabledRules();
    if (enabledRules.isEmpty) {
      return TxtParser.defaultTocRuleOptions;
    }
    return enabledRules
        .map(
          (rule) => TxtTocRuleOption(
            name: rule.name,
            rule: rule.rule,
            example: (rule.example ?? '').trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<String?> _pickTxtTocRuleRegex({
    required String currentRegex,
  }) async {
    final options = await _loadTxtTocRuleOptions();
    if (!mounted) return null;
    final normalizedCurrent = currentRegex.trim();
    final items = <AppActionListItem<String>>[
      AppActionListItem<String>(
        value: '',
        icon: normalizedCurrent.isEmpty
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.circle,
        label: normalizedCurrent.isEmpty ? '✓ 自动识别（默认）' : '自动识别（默认）',
      ),
      ...options.map(
        (option) => AppActionListItem<String>(
          value: option.rule,
          icon: normalizedCurrent == option.rule
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.doc_text,
          label: normalizedCurrent == option.rule
              ? '✓ ${option.name}'
              : option.name,
        ),
      ),
    ];
    return showAppActionListSheet<String>(
      context: context,
      title: 'TXT 目录规则',
      message: '选择后会立即重建本地 TXT 目录。',
      showCancel: true,
      items: items,
    );
  }

  Future<SearchBookTocUpdateResult?> _handleEditTxtTocRuleFromToc() async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty || !_isLocalTxtBook()) {
      _showMessage('当前书籍未接入 TXT 目录规则配置');
      return null;
    }
    final storedBook = _bookRepo.getBookById(id);
    if (storedBook == null || !storedBook.isLocal) {
      _showMessage('书籍信息不存在，无法配置 TXT 目录规则');
      return null;
    }

    final selectedRegex = await _pickTxtTocRuleRegex(
      currentRegex: _resolveBookTxtTocRuleRegex(id) ?? '',
    );
    if (selectedRegex == null) return null;
    final normalizedRegex = selectedRegex.trim();
    await _settingsService.saveBookTxtTocRule(
      id,
      normalizedRegex.isEmpty ? null : normalizedRegex,
    );

    final refreshed = await _refreshLocalBookshelfBook(
      force: true,
      showSuccessToast: false,
      txtTocRuleRegex: normalizedRegex.isEmpty ? null : normalizedRegex,
    );
    if (!refreshed) return null;

    final updatedToc = _loadStoredToc(id);
    final updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    if (mounted) {
      unawaited(showAppToast(context, message: 'TXT 目录规则已应用'));
    }
    return SearchBookTocUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: _splitLongChapter,
      useReplaceEnabled: _tocUiUseReplace,
      loadWordCountEnabled: _tocUiLoadWordCount,
    );
  }

  Future<SearchBookTocUpdateResult?>
      _handleToggleSplitLongChapterFromToc() async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty || !_isLocalTxtBook()) {
      _showMessage('当前书籍未接入拆分超长章节配置');
      return null;
    }
    final storedBook = _bookRepo.getBookById(id);
    if (storedBook == null || !storedBook.isLocal) {
      _showMessage('书籍信息不存在，无法调整拆分超长章节');
      return null;
    }

    final next = !_splitLongChapter;
    if (mounted) {
      setState(() => _splitLongChapter = next);
    }
    await _settingsService.saveBookSplitLongChapter(id, next);
    await _refreshLocalBookshelfBook(
      force: true,
      showSuccessToast: false,
      splitLongChapter: next,
    );

    final updatedToc = _loadStoredToc(id);
    List<String> updatedDisplayTitles;
    try {
      updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    } catch (_) {
      updatedDisplayTitles =
          updatedToc.map((item) => item.name).toList(growable: false);
    }
    return SearchBookTocUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: next,
      useReplaceEnabled: _tocUiUseReplace,
      loadWordCountEnabled: _tocUiLoadWordCount,
    );
  }

  Future<SearchBookTocUpdateResult?> _handleToggleUseReplaceFromToc() async {
    final next = !_tocUiUseReplace;
    if (mounted) {
      setState(() => _tocUiUseReplace = next);
    }
    await _settingsService.saveTocUiUseReplace(next);

    final id = _bookId?.trim() ?? '';
    final updatedToc =
        _inBookshelf && id.isNotEmpty ? _loadStoredToc(id) : _toc;
    List<String> updatedDisplayTitles;
    try {
      updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    } catch (_) {
      updatedDisplayTitles =
          updatedToc.map((item) => item.name).toList(growable: false);
    }

    return SearchBookTocUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: _splitLongChapter,
      useReplaceEnabled: next,
      loadWordCountEnabled: _tocUiLoadWordCount,
    );
  }

  Future<SearchBookTocUpdateResult?> _handleToggleLoadWordCountFromToc() async {
    final next = !_tocUiLoadWordCount;
    if (mounted) {
      setState(() => _tocUiLoadWordCount = next);
    }
    await _settingsService.saveTocUiLoadWordCount(next);

    final id = _bookId?.trim() ?? '';
    final updatedToc =
        _inBookshelf && id.isNotEmpty ? _loadStoredToc(id) : _toc;
    List<String> updatedDisplayTitles;
    try {
      updatedDisplayTitles = await _buildTocDisplayTitles(updatedToc);
    } catch (_) {
      updatedDisplayTitles =
          updatedToc.map((item) => item.name).toList(growable: false);
    }

    return SearchBookTocUpdateResult(
      toc: updatedToc,
      displayTitles: updatedDisplayTitles,
      splitLongChapterEnabled: _splitLongChapter,
      useReplaceEnabled: _tocUiUseReplace,
      loadWordCountEnabled: next,
    );
  }

  bool _resolveBookInfoDeleteAlertSetting() {
    try {
      return _settingsService.appSettings.bookInfoDeleteAlert;
    } catch (_) {
      return true;
    }
  }
}
