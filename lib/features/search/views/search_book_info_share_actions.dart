// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoShareActions on SearchBookInfoViewState {
  String _resolveBookUrl() {
    return _pickFirstNonEmpty(<String>[
          _detail?.bookUrl ?? '',
          _activeResult.bookUrl,
          widget.bookshelfBook?.bookUrl ?? '',
        ]) ??
        '';
  }

  String _resolveTocUrl() {
    return _pickFirstNonEmpty(<String>[
          _detail?.tocUrl ?? '',
          _detail?.bookUrl ?? '',
          _activeResult.bookUrl,
          widget.bookshelfBook?.bookUrl ?? '',
        ]) ??
        '';
  }

  String _displaySourceVariableComment(BookSource source) {
    const defaultComment = '源变量可在js中通过source.getVariable()获取';
    final custom = (source.variableComment ?? '').trim();
    if (custom.isEmpty) return defaultComment;
    return '$custom\n$defaultComment';
  }

  String _displayBookVariableComment(BookSource source) {
    const defaultComment = '书籍变量可在js中通过book.getVariable("custom")获取';
    final custom = (source.variableComment ?? '').trim();
    if (custom.isEmpty) return defaultComment;
    return '$custom\n$defaultComment';
  }

  void _syncDisplayFromStoredBook(Book book) {
    final previousDetail = _detail;
    final resolvedBookUrl = _pickFirstNonEmpty(<String>[
          book.bookUrl ?? '',
          previousDetail?.bookUrl ?? '',
          _activeResult.bookUrl,
        ]) ??
        '';
    final resolvedTocUrl = _pickFirstNonEmpty(<String>[
          previousDetail?.tocUrl ?? '',
          resolvedBookUrl,
        ]) ??
        '';
    final resolvedLastChapter = _pickFirstNonEmpty(<String>[
          book.latestChapter ?? '',
          previousDetail?.lastChapter ?? '',
          _activeResult.lastChapter,
        ]) ??
        '';
    final resolvedSourceUrl = _pickFirstNonEmpty(<String>[
          book.sourceUrl ?? '',
          book.sourceId ?? '',
          _activeResult.sourceUrl,
        ]) ??
        '';

    _activeResult = SearchResult(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: book.intro ?? '',
      kind: _activeResult.kind,
      lastChapter: resolvedLastChapter,
      updateTime: _activeResult.updateTime,
      wordCount: _activeResult.wordCount,
      bookUrl: resolvedBookUrl,
      sourceUrl: resolvedSourceUrl,
      sourceName: _activeResult.sourceName,
    );
    _detail = BookDetail(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: book.intro ?? '',
      kind: previousDetail?.kind ?? _activeResult.kind,
      lastChapter: resolvedLastChapter,
      updateTime: previousDetail?.updateTime ?? _activeResult.updateTime,
      wordCount: previousDetail?.wordCount ?? _activeResult.wordCount,
      tocUrl: resolvedTocUrl,
      bookUrl: resolvedBookUrl,
    );
  }

  Book _buildShareBookSnapshot() {
    final stored = _resolveStoredBook();
    final resolvedName = _pickFirstNonEmpty(<String>[
          _detail?.name ?? '',
          _activeResult.name,
          stored?.title ?? '',
        ]) ??
        '';
    final resolvedAuthor = _pickFirstNonEmpty(<String>[
          _detail?.author ?? '',
          _activeResult.author,
          stored?.author ?? '',
        ]) ??
        '';
    final resolvedCoverUrl = _pickFirstNonEmpty(<String>[
          _detail?.coverUrl ?? '',
          _activeResult.coverUrl,
          stored?.coverUrl ?? '',
        ]) ??
        '';
    final resolvedIntro = _pickFirstNonBlankPreserve(<String?>[
          _detail?.intro,
          _activeResult.intro,
          stored?.intro,
        ]) ??
        '';
    final resolvedSourceUrl = _pickFirstNonEmpty(<String>[
          _source?.bookSourceUrl ?? '',
          _activeResult.sourceUrl,
          stored?.sourceUrl ?? '',
          stored?.sourceId ?? '',
        ]) ??
        '';
    final resolvedBookUrl = _resolveBookUrl();
    final resolvedLastChapter = _pickFirstNonEmpty(<String>[
          _detail?.lastChapter ?? '',
          _activeResult.lastChapter,
          stored?.latestChapter ?? '',
        ]) ??
        '';
    final resolvedTotalChapters =
        _toc.isEmpty ? stored?.totalChapters ?? 0 : _toc.length;
    if (stored != null) {
      return stored.copyWith(
        title: resolvedName,
        author: resolvedAuthor,
        coverUrl: resolvedCoverUrl,
        intro: resolvedIntro,
        sourceId: resolvedSourceUrl,
        sourceUrl: resolvedSourceUrl,
        bookUrl: resolvedBookUrl,
        latestChapter: resolvedLastChapter,
        totalChapters: resolvedTotalChapters,
      );
    }
    return Book(
      id: (_bookId?.trim().isNotEmpty ?? false)
          ? _bookId!.trim()
          : _buildEphemeralSessionId(),
      title: resolvedName,
      author: resolvedAuthor,
      coverUrl: resolvedCoverUrl.isEmpty ? null : resolvedCoverUrl,
      intro: resolvedIntro.isEmpty ? null : resolvedIntro,
      sourceId: resolvedSourceUrl.isEmpty ? null : resolvedSourceUrl,
      sourceUrl: resolvedSourceUrl.isEmpty ? null : resolvedSourceUrl,
      bookUrl: resolvedBookUrl.isEmpty ? null : resolvedBookUrl,
      latestChapter: resolvedLastChapter.isEmpty ? null : resolvedLastChapter,
      totalChapters: resolvedTotalChapters,
    );
  }

  Future<File?> _buildShareQrPngFile(String payload) async {
    if (kIsWeb) return null;
    // 对齐 legado `shareWithQr`：二维码承载 `bookUrl#bookJson`，使用高纠错等级降低扫码失败率。
    final painter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: CupertinoColors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: CupertinoColors.black,
      ),
    );
    final imageData = await painter.toImageData(
      1024,
      format: ui.ImageByteFormat.png,
    );
    final bytes = imageData?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'book_info_share_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.menu_share_it.qr_build',
        message: '生成书籍详情分享二维码失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'payloadLength': payload.length,
        },
      );
      rethrow;
    }
  }

  Future<void> _copyText(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    unawaited(showAppToast(context, message: successMessage));
  }

  Future<void> _shareBook() async {
    if (kIsWeb) {
      _showMessage('当前平台暂不支持二维码分享');
      return;
    }
    final snapshot = _buildShareBookSnapshot();
    final payload = SearchBookInfoShareHelper.buildPayload(snapshot);
    final subject =
        snapshot.title.trim().isEmpty ? '分享' : snapshot.title.trim();
    File? qrFile;
    try {
      qrFile = await _buildShareQrPngFile(payload);
    } catch (error) {
      _showMessage('分享失败：${_resolveShareErrorMessage(error)}');
      return;
    }
    if (qrFile == null) {
      ExceptionLogService().record(
        node: 'search_book_info.menu_share_it.qr_file',
        message: '生成书籍详情分享二维码失败',
        error: 'qr_file_null',
        context: <String, dynamic>{
          'bookId': snapshot.id,
          'bookUrl': (snapshot.bookUrl ?? '').trim(),
          'payloadLength': payload.length,
        },
      );
      _showMessage('文字太多，生成二维码失败');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(qrFile.path, mimeType: 'image/png'),
          ],
          subject: subject,
        ),
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'search_book_info.menu_share_it.share',
        message: '书籍详情分享失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': snapshot.id,
          'bookUrl': (snapshot.bookUrl ?? '').trim(),
          'payloadLength': payload.length,
        },
      );
      if (!mounted) return;
      _showMessage('分享失败：${_resolveShareErrorMessage(error)}');
    }
  }
}
