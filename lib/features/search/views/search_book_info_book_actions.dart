// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoBookActions on SearchBookInfoViewState {
  Future<void> _openBookEdit() async {
    final id = _bookId?.trim() ?? '';
    if (!_inBookshelf || id.isEmpty) {
      _showMessage('当前书籍不在书架，无法编辑');
      return;
    }
    final stored = _bookRepo.getBookById(id);
    if (stored == null) {
      _showMessage('书架记录不存在，无法编辑');
      return;
    }

    final edited = await Navigator.of(context).push<SearchBookInfoEditDraft>(
      CupertinoPageRoute<SearchBookInfoEditDraft>(
        builder: (_) => SearchBookInfoEditView(
          initialDraft: SearchBookInfoEditHelper.fromBook(stored),
        ),
      ),
    );
    if (edited == null) return;

    final updated = SearchBookInfoEditHelper.applyDraft(
      original: stored,
      draft: edited,
    );
    try {
      await _bookRepo.updateBook(updated);
    } catch (e) {
      if (!mounted) return;
      _showMessage('保存失败\n${_compactReason(e.toString())}');
      return;
    }
    if (!mounted) return;

    setState(() {
      _syncDisplayFromStoredBook(updated);
    });
  }

  Future<void> _openSourceLogin() async {
    final source = _source;
    if (source == null) {
      _showMessage('当前书籍未匹配到书源');
      return;
    }

    if (SourceLoginUiHelper.hasLoginUi(source.loginUi)) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginFormView(source: source),
        ),
      );
      return;
    }

    final resolvedUrl = SourceLoginUrlResolver.resolve(
      baseUrl: source.bookSourceUrl,
      loginUrl: source.loginUrl ?? '',
    );
    if (resolvedUrl.isEmpty) {
      _showMessage('当前书源未配置登录地址');
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      _showMessage('登录地址不是有效网页地址');
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceLoginWebViewView(
          source: source,
          initialUrl: resolvedUrl,
        ),
      ),
    );
  }

  Future<void> _pinBookToTop() async {
    final id = _bookId?.trim() ?? '';
    if (id.isEmpty) return;

    final stored = _bookRepo.getBookById(id) ??
        ((_isBookshelfEntry && widget.bookshelfBook?.id == id)
            ? widget.bookshelfBook
            : null);
    if (stored == null) return;

    final pinned = SearchBookInfoTopHelper.buildPinnedBook(
      book: stored,
      now: DateTime.now(),
    );
    await _bookRepo.updateBook(pinned);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setSourceVariable() async {
    final source = _source;
    if (source == null) {
      _showMessage('书源不存在');
      return;
    }
    final sourceKey = source.bookSourceUrl;

    final note = _displaySourceVariableComment(source);
    final current = await SourceVariableStore.getVariable(sourceKey) ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    final result = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置源变量'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note,
                style: TextStyle(
                  fontSize: SourceUiTokens.itemMetaSize,
                  color: SourceUiTokens.resolveSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                maxLines: 6,
                placeholder: '输入变量 JSON 或文本',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    await SourceVariableStore.putVariable(sourceKey, result);
  }

  Future<void> _setBookVariable() async {
    final source = _source;
    if (source == null) {
      _showMessage('书源不存在');
      return;
    }
    final bookKey = _resolveBookUrl();
    if (bookKey.isEmpty) {
      return;
    }

    final note = _displayBookVariableComment(source);
    final current = await BookVariableStore.getVariable(bookKey) ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    final result = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置书籍变量'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note,
                style: TextStyle(
                  fontSize: SourceUiTokens.itemMetaSize,
                  color: SourceUiTokens.resolveSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                maxLines: 6,
                placeholder: '输入变量 JSON 或文本',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    await BookVariableStore.putVariable(bookKey, result);
  }
}
