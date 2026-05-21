// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoMoreMenuActions on SearchBookInfoViewState {
  _SearchBookInfoMoreActionConfig? _resolveSyncMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    switch (action) {
      case _SearchBookInfoMoreMenuAction.edit:
        return (
          actionKey: 'edit',
          actionLabel: '编辑',
          action: _openBookEdit,
        );
      case _SearchBookInfoMoreMenuAction.share:
        return (
          actionKey: 'share',
          actionLabel: '分享',
          action: _shareBook,
        );
      case _SearchBookInfoMoreMenuAction.uploadWebDav:
        return (
          actionKey: 'upload',
          actionLabel: '上传 WebDav',
          action: _uploadToRemote,
        );
      case _SearchBookInfoMoreMenuAction.refresh:
        return (
          actionKey: 'refresh',
          actionLabel: '刷新',
          action: _triggerRefresh,
        );
      case _SearchBookInfoMoreMenuAction.login:
        return (
          actionKey: 'login',
          actionLabel: '登录',
          action: _openSourceLogin,
        );
      case _SearchBookInfoMoreMenuAction.pinTop:
        return (
          actionKey: 'top',
          actionLabel: '置顶',
          action: _pinBookToTop,
        );
      default:
        return null;
    }
  }

  _SearchBookInfoMoreActionConfig? _resolveVariableMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    switch (action) {
      case _SearchBookInfoMoreMenuAction.setSourceVariable:
        return (
          actionKey: 'set_source_variable',
          actionLabel: '设置源变量',
          action: _setSourceVariable,
        );
      case _SearchBookInfoMoreMenuAction.setBookVariable:
        return (
          actionKey: 'set_book_variable',
          actionLabel: '设置书籍变量',
          action: _setBookVariable,
        );
      case _SearchBookInfoMoreMenuAction.copyBookUrl:
        return (
          actionKey: 'copy_book_url',
          actionLabel: '拷贝书籍 URL',
          action: _copyBookUrl,
        );
      case _SearchBookInfoMoreMenuAction.copyTocUrl:
        return (
          actionKey: 'copy_toc_url',
          actionLabel: '拷贝目录 URL',
          action: _copyTocUrl,
        );
      default:
        return null;
    }
  }

  _SearchBookInfoMoreActionConfig? _resolveToggleMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    switch (action) {
      case _SearchBookInfoMoreMenuAction.toggleAllowUpdate:
        return (
          actionKey: 'allow_update',
          actionLabel: '允许更新',
          action: _toggleAllowUpdate,
        );
      case _SearchBookInfoMoreMenuAction.toggleSplitLongChapter:
        return (
          actionKey: 'split_long_chapter',
          actionLabel: '分割长章节',
          action: _toggleSplitLongChapter,
        );
      case _SearchBookInfoMoreMenuAction.toggleDeleteAlert:
        return (
          actionKey: 'delete_alert',
          actionLabel: '删除提醒',
          action: _toggleDeleteAlertEnabled,
        );
      case _SearchBookInfoMoreMenuAction.clearCache:
        return (
          actionKey: 'clear_cache',
          actionLabel: '清理缓存',
          action: _clearBookCache,
        );
      case _SearchBookInfoMoreMenuAction.logs:
        return (
          actionKey: 'log',
          actionLabel: '日志',
          action: _openAppLogDialog,
        );
      default:
        return null;
    }
  }

  _SearchBookInfoMoreActionConfig _resolveMoreMenuActionConfig(
    _SearchBookInfoMoreMenuAction action,
  ) {
    final resolved = _resolveSyncMoreMenuActionConfig(action) ??
        _resolveVariableMoreMenuActionConfig(action) ??
        _resolveToggleMoreMenuActionConfig(action);
    if (resolved == null) {
      throw StateError('SearchBookInfo: unhandled more menu action: $action');
    }
    return resolved;
  }

  Future<void> _handleMoreMenuAction(_SearchBookInfoMoreMenuAction action) {
    final config = _resolveMoreMenuActionConfig(action);
    return _executeMoreActionSafely(
      actionKey: config.actionKey,
      actionLabel: config.actionLabel,
      action: config.action,
    );
  }

  Future<void> _showMoreActions() async {
    final showInlineEditAction = _shouldShowInlineEditAction(context);
    final showInlineShareAction = _shouldShowInlineShareAction(context);
    final source = _source;
    final hasLogin = SearchBookInfoMenuHelper.shouldShowLogin(
      loginUrl: source?.loginUrl,
    );
    final showSetVariable = SearchBookInfoMenuHelper.shouldShowSetVariable(
      hasSource: source != null,
    );
    final showAllowUpdate = SearchBookInfoMenuHelper.shouldShowAllowUpdate(
      hasSource: source != null,
    );
    final showUpload = SearchBookInfoMenuHelper.shouldShowUpload(
      isLocalBook: _isLocalBook(),
    );
    final showSplitLongChapter =
        SearchBookInfoMenuHelper.shouldShowSplitLongChapter(
      isLocalTxtBook: _isLocalTxtBook(),
    );
    final items = _buildMoreMenuItems(
      showEdit: _inBookshelf && !showInlineEditAction,
      showShare: !showInlineShareAction,
      hasLogin: hasLogin,
      showSetVariable: showSetVariable,
      showAllowUpdate: showAllowUpdate,
      showUpload: showUpload,
      showSplitLongChapter: showSplitLongChapter,
    );
    if (items.isEmpty || !mounted) return;
    final selected = await showAppPopoverMenu<_SearchBookInfoMoreMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: items,
    );
    if (!mounted || selected == null) return;
    await _handleMoreMenuAction(selected);
  }

  int _resolveInlineActionCapacity(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= SearchBookInfoViewState._minWidthForInlineEditAction) {
      return 2;
    }
    if (width >= SearchBookInfoViewState._minWidthForInlineShareAction) {
      return 1;
    }
    return 0;
  }

  bool _shouldShowInlineShareAction(BuildContext context) {
    return _resolveInlineActionCapacity(context) >= 1;
  }

  bool _shouldShowInlineEditAction(BuildContext context) {
    if (!_inBookshelf) return false;
    return _resolveInlineActionCapacity(context) >= 2;
  }
}
