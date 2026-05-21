// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoMoreMenuItems on SearchBookInfoViewState {
  Map<String, dynamic> _buildMoreActionLogContext({
    required String actionKey,
  }) {
    return <String, dynamic>{
      'action': actionKey,
      'bookId': (_bookId ?? '').trim(),
      'bookName': _displayName,
      'sourceUrl': _activeResult.sourceUrl,
      'sourceName': _displaySourceName,
      'bookUrl': _resolveBookUrl(),
      'inBookshelf': _inBookshelf,
      'isLocalBook': _isLocalBook(),
      'isLocalTxtBook': _isLocalTxtBook(),
    };
  }

  /// 详情页菜单动作统一兜底：
  /// 1) 记录关键错误日志；2) 给用户明确提示；3) 防止异常冒泡导致页面崩溃。
  Future<void> _executeMoreActionSafely({
    required String actionKey,
    required String actionLabel,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.more_action.$actionKey',
        message: '详情页菜单动作执行失败',
        error: error,
        stackTrace: stackTrace,
        context: _buildMoreActionLogContext(actionKey: actionKey),
      );
      if (!mounted) return;
      _showMessage('$actionLabel失败：${_compactReason(error.toString())}');
    }
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>> _buildSyncMenuItems({
    required bool showEdit,
    required bool showShare,
    required bool showUpload,
    required bool hasLogin,
  }) {
    return [
      if (showEdit)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.edit,
          icon: CupertinoIcons.pencil,
          label: '编辑',
        ),
      if (showShare)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.share,
          icon: CupertinoIcons.share,
          label: '分享',
        ),
      if (showUpload)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.uploadWebDav,
          icon: CupertinoIcons.cloud_upload,
          label: '上传 WebDav',
        ),
      const AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.refresh,
        icon: CupertinoIcons.refresh,
        label: '刷新',
      ),
      if (hasLogin)
        const AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.login,
          icon: CupertinoIcons.person,
          label: '登录',
        ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildVariableMenuItems({
    required bool showSetVariable,
  }) {
    if (!showSetVariable)
      return const <AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>[];
    return const [
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.setSourceVariable,
        icon: CupertinoIcons.slider_horizontal_3,
        label: '设置源变量',
      ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.setBookVariable,
        icon: CupertinoIcons.book,
        label: '设置书籍变量',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildCopyMenuItems() {
    return const [
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.copyBookUrl,
        icon: CupertinoIcons.link,
        label: '拷贝书籍 URL',
      ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.copyTocUrl,
        icon: CupertinoIcons.link,
        label: '拷贝目录 URL',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildOptionMenuItems({
    required bool showAllowUpdate,
    required bool showSplitLongChapter,
  }) {
    return [
      if (showAllowUpdate)
        AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.toggleAllowUpdate,
          icon: CupertinoIcons.check_mark,
          label: '${_allowUpdate ? '✓ ' : ''}允许更新',
        ),
      if (showSplitLongChapter)
        AppPopoverMenuItem(
          value: _SearchBookInfoMoreMenuAction.toggleSplitLongChapter,
          icon: CupertinoIcons.textformat,
          label: _splitLongChapter ? '分割长章节：开' : '分割长章节：关',
        ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.toggleDeleteAlert,
        icon: CupertinoIcons.bell,
        label: '${_deleteAlertEnabled ? '✓ ' : ''}删除提醒',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>>
      _buildUtilityMenuItems() {
    return const [
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.clearCache,
        icon: CupertinoIcons.delete,
        label: '清理缓存',
      ),
      AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.logs,
        icon: CupertinoIcons.doc_text,
        label: '日志',
      ),
    ];
  }

  List<AppPopoverMenuItem<_SearchBookInfoMoreMenuAction>> _buildMoreMenuItems({
    required bool showEdit,
    required bool showShare,
    required bool hasLogin,
    required bool showSetVariable,
    required bool showAllowUpdate,
    required bool showUpload,
    required bool showSplitLongChapter,
  }) {
    return [
      ..._buildSyncMenuItems(
        showEdit: showEdit,
        showShare: showShare,
        showUpload: showUpload,
        hasLogin: hasLogin,
      ),
      const AppPopoverMenuItem(
        value: _SearchBookInfoMoreMenuAction.pinTop,
        icon: CupertinoIcons.arrow_up_to_line,
        label: '置顶',
      ),
      ..._buildVariableMenuItems(showSetVariable: showSetVariable),
      ..._buildCopyMenuItems(),
      ..._buildOptionMenuItems(
        showAllowUpdate: showAllowUpdate,
        showSplitLongChapter: showSplitLongChapter,
      ),
      ..._buildUtilityMenuItems(),
    ];
  }
}
