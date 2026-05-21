// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoSyncActions on SearchBookInfoViewState {
  Future<void> _uploadToRemote() async {
    final book = _resolveStoredBook();
    if (book == null || !book.isLocal) {
      _showMessage('当前书籍不是本地书籍，无法上传');
      return;
    }
    if ((book.localPath ?? '').trim().isEmpty) {
      _showMessage('本地文件路径缺失，暂无法上传');
      return;
    }

    final settings = _settingsService.appSettings;
    final bookId = book.id.trim();
    final existingRemoteUrl =
        bookId.isEmpty ? null : _settingsService.getBookRemoteUploadUrl(bookId);
    if (existingRemoteUrl != null) {
      final confirmed = await showCupertinoBottomSheetDialog<bool>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: const Text('提醒'),
              content: const Text('远程webDav链接已存在，是否继续'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('确定'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }

    OverlayEntry? loadingOverlay;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState != null) {
      loadingOverlay = OverlayEntry(
        builder: (overlayContext) => ColoredBox(
          color: const Color(0x33000000),
          child: Center(
            child: CupertinoPopupSurface(
              isSurfacePainted: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(),
                    SizedBox(width: 12),
                    Text('上传中.....'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      overlayState.insert(loadingOverlay);
    }

    String feedback = '上传成功';
    try {
      final result = await _webDavService.uploadLocalBook(
        book: book,
        settings: settings,
      );
      if (bookId.isNotEmpty) {
        await _settingsService.saveBookRemoteUploadUrl(
            bookId, result.remoteUrl);
      }
    } catch (error) {
      feedback = _compactReason(error.toString(), maxLength: 180);
    } finally {
      loadingOverlay?.remove();
    }

    if (!mounted) return;
    _showMessage(feedback);
  }

  Future<void> _copyBookUrl() async {
    final bookUrl = _resolveBookUrl();
    await _copyText(bookUrl, '复制完成');
  }

  Future<void> _copyTocUrl() async {
    final tocUrl = _resolveTocUrl();
    await _copyText(tocUrl, '复制完成');
  }

  Future<void> _toggleAllowUpdate() async {
    final next = !_allowUpdate;
    setState(() => _allowUpdate = next);
    final id = _bookId?.trim() ?? '';
    if (_inBookshelf && id.isNotEmpty) {
      await _settingsService.saveBookCanUpdate(id, next);
    }
  }

  Future<void> _toggleSplitLongChapter() async {
    final next = !_splitLongChapter;
    if (!mounted) return;
    setState(() => _splitLongChapter = next);
    final id = _bookId?.trim() ?? '';
    if (_inBookshelf && id.isNotEmpty) {
      await _settingsService.saveBookSplitLongChapter(id, next);
    }
    var refreshSuccess = true;
    if (_inBookshelf && id.isNotEmpty && _isLocalTxtBook()) {
      refreshSuccess = await _refreshLocalBookshelfBook(
        force: true,
        splitLongChapter: next,
        showSuccessToast: false,
      );
    } else {
      if (!mounted) return;
      setState(() {
        _loading = true;
        _loadingToc = true;
      });
      await _loadContext(silent: true, forceRemote: true);
    }
    if (!mounted || !refreshSuccess) return;
    if (!next) {
      _showMessage('已关闭“分割长章节”，重新加载正文可能需要更长时间');
      return;
    }
    _showMessage('已开启“分割长章节”');
  }

  Future<void> _toggleDeleteAlertEnabled() async {
    setState(() {
      _deleteAlertEnabled = !_deleteAlertEnabled;
    });
    try {
      await _settingsService.saveAppSettings(
        _settingsService.appSettings.copyWith(
          bookInfoDeleteAlert: _deleteAlertEnabled,
        ),
      );
    } catch (_) {
      // SettingsService 未初始化时仅保持本页会话内状态。
    }
  }

  Future<void> _clearBookCache() async {
    final id = (_bookId?.trim().isNotEmpty ?? false)
        ? _bookId!.trim()
        : _buildEphemeralSessionId();
    _removeSessionCacheEntry(_buildSessionCacheKey());
    try {
      await _chapterRepo.clearDownloadedCacheForBook(id);
      if (!mounted) return;
      unawaited(showAppToast(context, message: '成功清理缓存'));
    } catch (e) {
      if (!mounted) return;
      _showMessage('清理缓存出错\n${_compactReason(e.toString())}');
    }
  }

  Future<void> _openAppLogDialog() async {
    await showAppLogDialog(context);
  }

  Future<void> _triggerRefresh() async {
    if (_inBookshelf) {
      if (_isLocalBook()) {
        await _refreshLocalBookshelfBook();
        return;
      }
      await _refreshBookshelfToc();
      return;
    }
    await _loadContext(forceRemote: true);
  }
}
