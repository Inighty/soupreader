import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/js_runtime.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/services/webdav_service.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/utils/chinese_script_converter.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../bookshelf/models/book.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../import/txt_parser.dart';
import '../../replace/models/replace_rule.dart';
import '../../replace/views/replace_rule_list_view.dart';
import '../../replace/services/replace_rule_service.dart';
import '../../replace/views/replace_rule_edit_view.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_cover_loader.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_edit_view.dart';
import '../../source/views/source_list_view.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_login_webview_view.dart';
import '../../source/views/source_web_verify_view.dart';
import '../../search/services/search_book_info_refresh_helper.dart';
import '../../search/models/search_scope.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../../search/views/search_book_info_view.dart';
import '../../settings/views/app_help_dialog.dart';
import '../../settings/views/app_log_dialog.dart';
import '../../settings/views/exception_logs_view.dart';
import '../../settings/views/reading_tip_settings_view.dart';
import '../models/reading_settings.dart';
import '../services/chapter_title_display_helper.dart';
import '../services/read_style_import_export_service.dart';
import '../services/reader_bookmark_export_service.dart';
import '../services/reader_charset_service.dart';
import '../services/reader_key_paging_helper.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_resolver.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_legacy_menu_helper.dart';
import '../services/reader_refresh_scope_helper.dart';
import '../services/reader_search_navigation_helper.dart';
import '../services/reader_source_action_helper.dart';
import '../services/reader_source_switch_helper.dart';
import '../services/reader_system_ui_helper.dart';
import '../services/reader_theme_mode_helper.dart';
import '../services/reader_top_bar_action_helper.dart';
import '../services/http_tts_engine.dart';
import '../services/http_tts_rule_store.dart';
import '../services/read_aloud_service.dart';
import '../services/txt_toc_rule_store.dart';
import '../utils/chapter_progress_utils.dart';
import '../widgets/auto_pager.dart';
import '../widgets/paged_reader_widget.dart';
import '../widgets/page_factory.dart';
import '../widgets/reader_menus.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_status_bar.dart';
import '../widgets/legacy_justified_text.dart';
import '../widgets/reader_catalog_sheet.dart';
import '../widgets/scroll_page_step_calculator.dart';
import '../widgets/scroll_segment_paint_view.dart';
import '../widgets/scroll_text_layout_engine.dart';
import '../widgets/scroll_runtime_helper.dart';
import '../widgets/reader_txt_toc_rule_dialog.dart';
import '../widgets/reader_read_aloud_bar.dart';
import '../widgets/reader_more_config_sheet.dart';
import '../widgets/reader_padding_config_dialog.dart';
import '../widgets/reader_style_quick_sheet.dart';
import '../widgets/source_switch_candidate_sheet.dart';
import 'reader_content_editor.dart';
import 'reader_dict_lookup_sheet.dart';
import 'simple_reader_types.dart';
import 'simple_reader_scroll_content.dart';

import 'simple_reader_view.dart';

extension _SimpleReaderViewActions on _SimpleReaderViewState {
  /// 刷新当前章节

  void _refreshChapter() {
    _closeReaderMenuOverlay();
    _loadChapter(_currentChapterIndex);
  }

  void _showToast(String message) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  void _showCopyToast(String message) {
    if (!mounted) return;
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context)
                        .resolveFrom(context)
                        .withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _ReadAloudCapability _detectReadAloudCapability() {
    if (kIsWeb) {
      return const _ReadAloudCapability(
        available: false,
        reason: '当前平台暂不支持语音朗读',
      );
    }
    if (_chapters.isEmpty) {
      return const _ReadAloudCapability(
        available: false,
        reason: '当前书籍暂无可朗读章节',
      );
    }
    if (_currentContent.trim().isEmpty) {
      return const _ReadAloudCapability(
        available: false,
        reason: '当前章节暂无可朗读内容',
      );
    }
    return const _ReadAloudCapability(
      available: true,
      reason: '',
    );
  }

  void _refreshCurrentSourceName() {
    final sourceUrl = _currentSourceUrl;
    if (sourceUrl == null || sourceUrl.trim().isEmpty) {
      _currentSourceName = widget.effectiveSourceName ?? _currentSourceName;
      return;
    }
    final source = _sourceRepo.getSourceByUrl(sourceUrl);
    _currentSourceName = source?.bookSourceName ??
        widget.effectiveSourceName ??
        _currentSourceName;
  }

  String _normalizeChapterUrl(String? url) {
    return ReaderTopBarActionHelper.normalizeChapterUrl(url);
  }

  bool _isCurrentBookLocal() {
    if (widget.isEphemeral) return false;
    return _bookRepo.getBookById(widget.bookId)?.isLocal ?? false;
  }

  bool _isCurrentBookLocalTxt() {
    if (widget.isEphemeral) return false;
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) return false;
    final lower = ((book.localPath ?? book.bookUrl ?? '')).toLowerCase();
    return lower.endsWith('.txt');
  }

  bool _isCurrentBookEpub() {
    if (widget.isEphemeral) return false;
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) return false;
    final lower = ((book.localPath ?? book.bookUrl ?? '')).toLowerCase();
    return lower.endsWith('.epub');
  }

  bool _defaultUseReplaceRule() {
    // 对齐 legado：epub（以及图片类）默认关闭替换规则；
    // 当前项目暂无图片阅读模式，先按 epub 分支对齐默认语义。
    if (_isCurrentBookEpub()) {
      return false;
    }
    return true;
  }

  String _normalizeLegacyImageStyle(String? raw) {
    final normalized = (raw ?? '').trim().toUpperCase();
    if (_SimpleReaderViewState._legacyImageStyles.contains(normalized)) {
      return normalized;
    }
    return _SimpleReaderViewState._defaultLegacyImageStyle;
  }

  bool _hasWebDavProgressConfig() {
    final settings = _settingsService.appSettings;
    final rootUrl = _webDavService.buildRootUrl(settings).trim();
    final rootUri = Uri.tryParse(rootUrl);
    if (rootUri == null) return false;
    final scheme = rootUri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    return _webDavService.hasValidConfig(settings);
  }

  bool _isSyncBookProgressEnabled() {
    return _settingsService.appSettings.syncBookProgress;
  }

  Future<void> _openExceptionLogsFromReader() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const ExceptionLogsView(),
      ),
    );
  }

  String _progressSyncBookTitle() {
    final bookTitleFromRepo =
        _bookRepo.getBookById(widget.bookId)?.title.trim() ?? '';
    if (bookTitleFromRepo.isNotEmpty) {
      return bookTitleFromRepo;
    }
    final title = widget.bookTitle.trim();
    if (title.isNotEmpty) {
      return title;
    }
    return '未知书名';
  }

  String _progressSyncBookAuthor() {
    final authorFromRepo =
        _bookRepo.getBookById(widget.bookId)?.author.trim() ?? '';
    if (authorFromRepo.isNotEmpty) {
      return authorFromRepo;
    }
    final author = _bookAuthor.trim();
    if (author.isNotEmpty) {
      return author;
    }
    return '未知作者';
  }

  WebDavBookProgress _buildLocalBookProgressPayload() {
    final chapterProgress = _getChapterProgress().clamp(0.0, 1.0).toDouble();
    final readableChapterCount = _effectiveReadableChapterCount();
    final safeChapterIndex = readableChapterCount > 0
        ? _currentChapterIndex.clamp(0, readableChapterCount - 1).toInt()
        : 0;
    return WebDavBookProgress(
      name: _progressSyncBookTitle(),
      author: _progressSyncBookAuthor(),
      durChapterIndex: safeChapterIndex,
      durChapterPos: (chapterProgress * 10000).round(),
      durChapterTime: DateTime.now().millisecondsSinceEpoch,
      durChapterTitle: _currentTitle,
      chapterProgress: chapterProgress,
      readProgress: _getBookProgress().clamp(0.0, 1.0).toDouble(),
      totalChapters: readableChapterCount,
    );
  }

  double _decodeRemoteChapterProgress(WebDavBookProgress remote) {
    final explicit = remote.chapterProgress;
    if (explicit != null) {
      return explicit.clamp(0.0, 1.0).toDouble();
    }
    final pos = remote.durChapterPos;
    if (pos <= 0) return 0.0;
    if (pos <= 10000) {
      return (pos / 10000.0).clamp(0.0, 1.0).toDouble();
    }
    return 0.0;
  }

  Future<void> _pushBookProgressToWebDav() async {
    if (!_isSyncBookProgressEnabled()) {
      return;
    }
    if (!_hasWebDavProgressConfig()) {
      return;
    }
    if (_chapters.isEmpty) {
      return;
    }
    final bookTitle = _progressSyncBookTitle();
    final bookAuthor = _progressSyncBookAuthor();
    try {
      await _saveProgress();
      final progress = _buildLocalBookProgressPayload();
      await _webDavService.uploadBookProgress(
        progress: progress,
        settings: _settingsService.appSettings,
      );
      if (!mounted) return;
      _showToast('上传成功');
    } catch (error, stackTrace) {
      final reason = _normalizeReaderErrorMessage(error);
      ExceptionLogService().record(
        node: 'reader.menu.cover_progress.failed',
        message: '上传阅读进度失败《$bookTitle》\n$reason',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': bookTitle,
          'bookAuthor': bookAuthor,
          'syncBookProgress': _settingsService.appSettings.syncBookProgress,
          'sourceUrl': _currentSourceUrl,
        },
      );
      if (!mounted) return;
      _showToast('上传进度失败\n$reason');
    }
  }

  Future<void> _pullBookProgressFromWebDav() async {
    if (!_isSyncBookProgressEnabled()) {
      return;
    }
    if (!_hasWebDavProgressConfig()) {
      return;
    }
    if (_chapters.isEmpty) {
      return;
    }
    final bookTitle = _progressSyncBookTitle();
    final bookAuthor = _progressSyncBookAuthor();
    try {
      final remote = await _webDavService.getBookProgress(
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        settings: _settingsService.appSettings,
      );
      if (remote == null) return;
      await _applyRemoteBookProgress(
        remote,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
      );
    } catch (error, stackTrace) {
      final reason = _normalizeReaderErrorMessage(error);
      ExceptionLogService().record(
        node: 'reader.menu.get_progress.failed',
        message: '拉取阅读进度失败《$bookTitle》\n$reason',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'bookAuthor': _bookAuthor,
          'syncBookProgress': _settingsService.appSettings.syncBookProgress,
          'sourceUrl': _currentSourceUrl,
        },
      );
    }
  }

  Future<void> _applyRemoteBookProgress(
    WebDavBookProgress remote, {
    required String bookTitle,
    required String bookAuthor,
  }) async {
    final readableChapterCount = _effectiveReadableChapterCount();
    if (readableChapterCount <= 0) return;
    final maxIndex = readableChapterCount - 1;
    final targetChapterIndex = remote.durChapterIndex;
    if (targetChapterIndex < 0 || targetChapterIndex > maxIndex) {
      return;
    }
    var targetChapterProgress = _decodeRemoteChapterProgress(remote);
    final remotePos = remote.durChapterPos;
    final hasLegacyRawPos = remote.chapterProgress == null && remotePos > 10000;
    if (hasLegacyRawPos && targetChapterProgress <= 0) {
      final chapterContent =
          (_chapters[targetChapterIndex].content ?? '').trim();
      if (chapterContent.isNotEmpty) {
        targetChapterProgress =
            (remotePos / chapterContent.length).clamp(0.0, 1.0).toDouble();
      }
    }
    final localChapterIndex = _currentChapterIndex.clamp(0, maxIndex).toInt();
    final localChapterProgress =
        _getChapterProgress().clamp(0.0, 1.0).toDouble();
    final remoteBehindLocal = targetChapterIndex < localChapterIndex ||
        (targetChapterIndex == localChapterIndex &&
            targetChapterProgress < localChapterProgress);

    if (remoteBehindLocal) {
      if (!mounted) return;
      final confirmOverride = await showCupertinoBottomSheetDialog<bool>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: const Text('获取进度'),
              content: const Text('\n当前进度超过云端，是否覆盖为云端进度？'),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('覆盖'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmOverride) return;
    }

    final chapterProgressDelta =
        (targetChapterProgress - localChapterProgress).abs();
    final remoteEqualsLocal = targetChapterIndex == localChapterIndex &&
        chapterProgressDelta <= 0.0001;
    if (remoteEqualsLocal) {
      if (!remoteBehindLocal) {
        final syncedTitle = (remote.durChapterTitle ?? '').trim();
        final suffix = syncedTitle.isEmpty ? '' : ' $syncedTitle';
        ExceptionLogService().record(
          node: 'reader.menu.get_progress.synced',
          message: '自动同步阅读进度成功《$bookTitle》$suffix',
          context: <String, dynamic>{
            'bookId': widget.bookId,
            'bookTitle': bookTitle,
            'bookAuthor': bookAuthor,
            'chapterIndex': targetChapterIndex,
            'chapterTitle': remote.durChapterTitle,
            'sourceUrl': _currentSourceUrl,
          },
        );
      }
      return;
    }

    await _loadChapter(
      targetChapterIndex,
      restoreOffset: true,
      targetChapterProgress: targetChapterProgress,
    );
    await _saveProgress();
    if (remoteBehindLocal) {
      return;
    }

    final syncedTitle = (remote.durChapterTitle ?? '').trim();
    final suffix = syncedTitle.isEmpty ? '' : ' $syncedTitle';
    ExceptionLogService().record(
      node: 'reader.menu.get_progress.synced',
      message: '自动同步阅读进度成功《$bookTitle》$suffix',
      context: <String, dynamic>{
        'bookId': widget.bookId,
        'bookTitle': bookTitle,
        'bookAuthor': bookAuthor,
        'chapterIndex': targetChapterIndex,
        'chapterTitle': remote.durChapterTitle,
        'sourceUrl': _currentSourceUrl,
      },
    );
  }

  Future<void> _openContentEditFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      _showToast('当前章节不存在');
      return;
    }

    final chapterIndex = _currentChapterIndex;
    final chapter = _chapters[chapterIndex];
    final initialRawContent = await _resolveCurrentChapterRawContentForMenu(
      chapter: chapter,
      chapterIndex: chapterIndex,
      actionTag: 'edit_content',
      showFetchFailureToast: true,
    );
    if (!mounted) return;

    final payload = await Navigator.of(context).push<ReaderContentEditPayload>(
      CupertinoPageRoute<ReaderContentEditPayload>(
        fullscreenDialog: true,
        builder: (_) => ReaderContentEditorPage(
          initialTitle: chapter.title,
          initialContent: initialRawContent,
          onResetContent: () => _reloadChapterRawContentForEditor(
            chapterIndex: chapterIndex,
          ),
        ),
      ),
    );
    if (payload == null) return;

    final nextContent = payload.content;
    final nextTitle =
        payload.title.trim().isEmpty ? chapter.title : payload.title.trim();
    final shouldPersistContent = nextContent.isNotEmpty;
    final nextStoredContent =
        shouldPersistContent ? nextContent : chapter.content;
    final nextIsDownloaded = shouldPersistContent ? true : chapter.isDownloaded;
    final hasChanges = nextTitle != chapter.title ||
        nextStoredContent != chapter.content ||
        nextIsDownloaded != chapter.isDownloaded;
    if (!hasChanges) {
      return;
    }
    final updated = chapter.copyWith(
      title: nextTitle,
      content: nextStoredContent,
      isDownloaded: nextIsDownloaded,
    );
    if (!widget.isEphemeral) {
      await _chapterRepo.addChapters(<Chapter>[updated]);
    }
    if (!mounted) return;
    setState(() {
      _replaceStageCache.remove(chapter.id);
      _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
      _chapterContentInFlight.remove(chapter.id);
      _chapters[chapterIndex] = updated;
    });
    await _loadChapter(chapterIndex, restoreOffset: true);
  }

  Future<String> _reloadChapterRawContentForEditor({
    required int chapterIndex,
  }) async {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) {
      throw StateError('当前章节不存在');
    }
    final chapter = _chapters[chapterIndex];
    final cleared = chapter.copyWith(
      content: null,
      isDownloaded: false,
    );
    if (!widget.isEphemeral) {
      await _chapterRepo.addChapters(<Chapter>[cleared]);
    }
    if (!mounted) {
      return '';
    }
    setState(() {
      _replaceStageCache.remove(chapter.id);
      _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
      _chapterContentInFlight.remove(chapter.id);
      _chapters[chapterIndex] = cleared;
    });

    late final String resetRawContent;
    try {
      final book = _bookRepo.getBookById(widget.bookId);
      if (book != null && book.isLocal) {
        resetRawContent = await _reloadLocalChapterRawContentForEditor(
          chapter: chapter,
          chapterIndex: chapterIndex,
          book: book,
        );
      } else {
        resetRawContent = await _resolveCurrentChapterRawContentForMenu(
          chapter: cleared,
          chapterIndex: chapterIndex,
          actionTag: 'edit_content_reset',
          fallbackToCurrentContent: false,
          rethrowFetchFailure: true,
        );
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.edit_content_reset.failed',
        message: '重置正文失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'chapterId': chapter.id,
          'chapterIndex': chapterIndex,
          'chapterTitle': chapter.title,
          'sourceUrl': _currentSourceUrl,
        },
      );
      rethrow;
    }
    if (!mounted) {
      return resetRawContent;
    }

    if (resetRawContent.trim().isNotEmpty) {
      final restored = cleared.copyWith(
        content: resetRawContent,
        isDownloaded: true,
      );
      if (!widget.isEphemeral) {
        await _chapterRepo.addChapters(<Chapter>[restored]);
      }
      if (!mounted) {
        return resetRawContent;
      }
      setState(() {
        _replaceStageCache.remove(chapter.id);
        _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
        _chapterContentInFlight.remove(chapter.id);
        _chapters[chapterIndex] = restored;
      });
    }

    try {
      await _loadChapter(chapterIndex, restoreOffset: true);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.edit_content_reset.reload_failed',
        message: '重置正文后刷新章节失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'chapterId': chapter.id,
          'chapterIndex': chapterIndex,
          'chapterTitle': chapter.title,
          'sourceUrl': _currentSourceUrl,
        },
      );
    }
    return resetRawContent;
  }

  Future<String> _reloadLocalChapterRawContentForEditor({
    required Chapter chapter,
    required int chapterIndex,
    required Book book,
  }) async {
    final preferredTxtCharset = _isCurrentBookLocalTxt()
        ? (_readerCharsetService.getBookCharset(widget.bookId) ??
            ReaderCharsetService.defaultCharset)
        : null;
    final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
      preferredTxtCharset: preferredTxtCharset,
      splitLongChapter: _settingsService.getBookSplitLongChapter(widget.bookId),
      txtTocRuleRegex: _settingsService.getBookTxtTocRule(widget.bookId),
    );
    final refreshedChapters = refreshed.chapters;
    if (refreshedChapters.isEmpty) {
      return '';
    }
    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: refreshedChapters,
      currentChapterTitle: chapter.title,
      currentChapterIndex: chapterIndex,
      oldChapterCount: _chapters.length,
    );
    if (targetIndex < 0 || targetIndex >= refreshedChapters.length) {
      return '';
    }
    return refreshedChapters[targetIndex].content ?? '';
  }

  Future<void> _toggleReSegmentFromMenu() async {
    final next = !_reSegment;
    if (!widget.isEphemeral) {
      await _settingsService.saveBookReSegment(widget.bookId, next);
    }
    if (!mounted) return;
    setState(() {
      _reSegment = next;
    });
    if (_chapters.isEmpty) return;
    await _saveProgress();
    final targetIndex = _clampChapterIndexToReadableRange(_currentChapterIndex);
    await _loadChapter(
      targetIndex,
      restoreOffset: true,
    );
  }

  Future<void> _openImageStyleFromMenu() async {
    final selected = await showOptionPickerSheet<String>(
      context: context,
      title: '图片样式',
      currentValue: _imageStyle,
      accentColor: _uiAccent,
      items: _SimpleReaderViewState._legacyImageStyles
          .map(
            (style) => OptionPickerItem<String>(
              value: style,
              label: style,
            ),
          )
          .toList(growable: false),
    );
    if (selected == null) return;
    await _applyImageStyleFromMenu(selected);
  }

  Future<void> _applyImageStyleFromMenu(String style) async {
    final normalized = _normalizeLegacyImageStyle(style);
    if (!widget.isEphemeral) {
      await _settingsService.saveBookImageStyle(widget.bookId, normalized);
    }
    if (!mounted) return;
    setState(() {
      _imageStyle = normalized;
    });

    // 对齐 legado：切换为 SINGLE 时，仅当前书籍强制覆盖翻页动画。
    if (normalized == _SimpleReaderViewState._legacyImageStyleSingle) {
      await _applyBookPageAnimFromMenu(0);
      if (!mounted) return;
    }
    await _loadChapter(_currentChapterIndex, restoreOffset: true);
  }

  String? _resolveBookTxtTocRuleRegex() {
    final regex = _settingsService.getBookTxtTocRule(widget.bookId);
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
    return ReaderTxtTocRuleDialog.show(
      context: context,
      currentRegex: currentRegex,
      options: options,
      accentColor: _uiAccent,
    );
  }

  Future<void> _showTxtTocRuleDialogFromMenu() async {
    if (!_isCurrentBookLocalTxt()) return;
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) return;

    final selectedRegex = await _pickTxtTocRuleRegex(
      currentRegex: _resolveBookTxtTocRuleRegex() ?? '',
    );
    if (selectedRegex == null) return;
    final normalizedRegex = selectedRegex.trim();
    await _settingsService.saveBookTxtTocRule(
      widget.bookId,
      normalizedRegex.isEmpty ? null : normalizedRegex,
    );

    if (!mounted) return;
    setState(() => _isLoadingChapter = true);
    try {
      final charset = _readerCharsetService.getBookCharset(widget.bookId) ??
          ReaderCharsetService.defaultCharset;
      final splitLongChapter =
          _settingsService.getBookSplitLongChapter(widget.bookId);
      await _reparseLocalTxtBookWithCharset(
        book: book,
        charset: charset,
        splitLongChapter: splitLongChapter,
      );
    } catch (e) {
      if (!mounted) return;
      _showToast('LoadTocError:$e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  Future<void> _showCharsetConfigFromMenu() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null || !book.isLocal) {
      return;
    }

    final currentCharset =
        _readerCharsetService.getBookCharset(widget.bookId) ?? '';
    final selected =
        await _showCharsetInputDialog(initialValue: currentCharset);
    if (selected == null) return;
    await _applyBookCharsetSetting(
      book: book,
      charset: selected,
    );
  }

  Future<String?> _showCharsetInputDialog({
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置编码'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: controller,
                placeholder: 'charset',
              ),
              const SizedBox(height: 10),
              Text(
                _SimpleReaderViewState._legacyCharsetOptions.join(' / '),
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 11,
                  color: _uiTextSubtle,
                ),
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
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _applyBookCharsetSetting({
    required Book book,
    required String charset,
  }) async {
    final normalized =
        ReaderCharsetService.normalizeCharset(charset) ?? charset.trim();
    await _readerCharsetService.setBookCharset(widget.bookId, normalized);

    if (!_isCurrentBookLocal()) {
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingChapter = true);
    try {
      if (_isCurrentBookLocalTxt()) {
        final splitLongChapter =
            _settingsService.getBookSplitLongChapter(widget.bookId);
        await _reparseLocalTxtBookWithCharset(
          book: book,
          charset: normalized,
          splitLongChapter: splitLongChapter,
        );
      } else {
        await _reloadLocalCatalogAfterCharsetChanged(book: book);
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('LoadTocError:$e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  Future<void> _reloadLocalCatalogAfterCharsetChanged({
    required Book book,
  }) async {
    final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
      book: book,
    );
    final newChapters = refreshed.chapters;
    if (newChapters.isEmpty) {
      throw StateError('重解析后章节为空');
    }

    final previousRawTitle = _chapters.isEmpty
        ? _currentTitle
        : _chapters[_currentChapterIndex.clamp(0, _chapters.length - 1)].title;
    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: newChapters,
      currentChapterTitle: previousRawTitle,
      currentChapterIndex: _currentChapterIndex,
      oldChapterCount: _chapters.length,
    );

    if (!widget.isEphemeral) {
      await _chapterRepo.clearChaptersForBook(widget.bookId);
      await _chapterRepo.addChapters(newChapters);
      await _bookRepo.updateBook(
        refreshed.book.copyWith(
          totalChapters: newChapters.length,
          latestChapter: newChapters.last.title,
          currentChapter: targetIndex,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _bookAuthor = refreshed.book.author;
      _bookCoverUrl = refreshed.book.coverUrl;
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = newChapters;
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
  }

  Future<void> _reparseLocalTxtBookWithCharset({
    required Book book,
    required String charset,
    required bool splitLongChapter,
  }) async {
    final localPath = (book.localPath ?? book.bookUrl ?? '').trim();
    if (localPath.isEmpty) {
      throw StateError('缺少本地 TXT 文件路径');
    }

    final previousRawTitle = _chapters.isEmpty
        ? _currentTitle
        : _chapters[_currentChapterIndex.clamp(0, _chapters.length - 1)].title;

    final parsed = await TxtParser.reparseFromFile(
      filePath: localPath,
      bookId: widget.bookId,
      bookName: book.title,
      forcedCharset: charset,
      splitLongChapter: splitLongChapter,
      tocRuleRegex: _settingsService.getBookTxtTocRule(widget.bookId),
    );
    final newChapters = parsed.chapters;
    if (newChapters.isEmpty) {
      throw StateError('重解析后章节为空');
    }

    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: newChapters,
      currentChapterTitle: previousRawTitle,
      currentChapterIndex: _currentChapterIndex,
      oldChapterCount: _chapters.length,
    );

    if (!widget.isEphemeral) {
      await _chapterRepo.clearChaptersForBook(widget.bookId);
      await _chapterRepo.addChapters(newChapters);
      await _bookRepo.updateBook(
        book.copyWith(
          totalChapters: newChapters.length,
          latestChapter: newChapters.last.title,
          currentChapter: targetIndex,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = newChapters;
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
  }

  String _reverseContentLikeLegado(String content) {
    if (content.isEmpty) return content;
    final codePoints = content.runes.toList(growable: false);
    if (codePoints.length <= 1) return content;
    return String.fromCharCodes(codePoints.reversed);
  }

  Future<String> _resolveCurrentChapterRawContentForMenu({
    required Chapter chapter,
    required int chapterIndex,
    required String actionTag,
    bool showFetchFailureToast = false,
    bool fallbackToCurrentContent = true,
    bool rethrowFetchFailure = false,
  }) async {
    var rawContent = chapter.content ?? '';
    if (rawContent.trim().isNotEmpty) {
      return rawContent;
    }

    final book = _bookRepo.getBookById(widget.bookId);
    final chapterUrl = (chapter.url ?? '').trim();
    final canFetchFromSource = chapterUrl.isNotEmpty &&
        (book == null || !book.isLocal) &&
        _resolveActiveSourceUrl(book).isNotEmpty;
    if (canFetchFromSource) {
      try {
        rawContent = await _fetchChapterContent(
          chapter: chapter,
          index: chapterIndex,
          book: book,
          showLoading: true,
        );
      } catch (error, stackTrace) {
        ExceptionLogService().record(
          node: 'reader.menu.$actionTag.fetch_content_failed',
          message: '阅读页菜单正文拉取失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'bookId': widget.bookId,
            'bookTitle': widget.bookTitle,
            'chapterId': chapter.id,
            'chapterIndex': chapterIndex,
            'chapterUrl': chapterUrl,
            'actionTag': actionTag,
            'currentSourceUrl': _resolveActiveSourceUrl(book),
          },
        );
        if (rethrowFetchFailure) {
          rethrow;
        }
        if (showFetchFailureToast && mounted) {
          _showToast('获取正文失败，已回退当前显示内容');
        }
      }
    }
    if (rawContent.trim().isNotEmpty) {
      return rawContent;
    }
    if (fallbackToCurrentContent) {
      return _currentContent;
    }
    return '';
  }

  Future<void> _reverseCurrentChapterContentFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return;
    }
    final chapterIndex = _currentChapterIndex;
    final chapter = _chapters[chapterIndex];
    final rawContent = chapter.content ?? '';
    if (rawContent.isEmpty) {
      return;
    }
    final reversed = _reverseContentLikeLegado(rawContent);

    if (!widget.isEphemeral) {
      await _chapterRepo.cacheChapterContent(chapter.id, reversed);
    }

    if (!mounted) return;
    setState(() {
      _replaceStageCache.remove(chapter.id);
      _catalogDisplayTitleCacheByChapterId.remove(chapter.id);
      _chapterContentInFlight.remove(chapter.id);
      _chapters[chapterIndex] = chapter.copyWith(
        content: reversed,
        isDownloaded: true,
      );
    });
    await _loadChapter(chapterIndex, restoreOffset: true);
  }

  Future<void> _openSimulatedReadingFromMenu() async {
    _closeReaderMenuOverlay();
    final input = await _showSimulatedReadingInputDialog();
    if (input == null) return;

    final startRaw = input.startChapter.trim();
    final dailyRaw = input.dailyChapters.trim();
    final startChapter = startRaw.isEmpty ? 0 : int.tryParse(startRaw);
    final dailyChapters =
        dailyRaw.isEmpty ? _chapters.length : int.tryParse(dailyRaw);
    if (startChapter == null) {
      _showToast('起始章节输入无效');
      return;
    }
    if (dailyChapters == null) {
      _showToast('每日章节输入无效');
      return;
    }

    await _settingsService.saveBookSimulatedReadingConfig(
      widget.bookId,
      enabled: input.enabled,
      startChapter: startChapter,
      dailyChapters: dailyChapters,
      startDate: _normalizeDateOnly(input.startDate),
    );

    _replaceStageCache.clear();
    _catalogDisplayTitleCacheByChapterId.clear();
    _chapterContentInFlight.clear();

    final readableChapterCount = _effectiveReadableChapterCount();
    if (readableChapterCount <= 0) {
      if (!mounted) return;
      setState(() {
        _currentChapterIndex = 0;
        _currentTitle = '';
        _currentContent = '';
        _invalidateScrollLayoutSnapshot();
      });
      _syncPageFactoryChapters();
      return;
    }

    final targetIndex =
        _currentChapterIndex.clamp(0, readableChapterCount - 1).toInt();
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
  }

  Future<_ReaderSimulatedReadingInput?>
      _showSimulatedReadingInputDialog() async {
    var enabled = _isSimulatedReadingEnabled();
    var startDate = _simulatedStartDateOrToday();
    final startController = TextEditingController(
      text: _simulatedStartChapterForDialogDefault().toString(),
    );
    final dailyController = TextEditingController(
      text: _simulatedDailyChaptersForDialogDefault().toString(),
    );
    try {
      return await showCupertinoBottomSheetDialog<_ReaderSimulatedReadingInput>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return CupertinoAlertDialog(
                title: const Text('模拟追读'),
                content: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('启用'),
                          const Spacer(),
                          CupertinoSwitch(
                            value: enabled,
                            onChanged: (value) {
                              setDialogState(() {
                                enabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: startController,
                        placeholder: '起始章节',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: dailyController,
                        placeholder: '每日章节',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                      ),
                      const SizedBox(height: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final picked =
                              await _pickSimulatedReadingStartDate(startDate);
                          if (picked == null) return;
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            startDate = picked;
                          });
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '开始日期：${_formatDateOnly(startDate)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
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
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                        _ReaderSimulatedReadingInput(
                          enabled: enabled,
                          startChapter: startController.text,
                          dailyChapters: dailyController.text,
                          startDate: startDate,
                        ),
                      );
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      startController.dispose();
      dailyController.dispose();
    }
  }

  Future<DateTime?> _pickSimulatedReadingStartDate(DateTime initialDate) async {
    var selected = _normalizeDateOnly(initialDate);
    return await showCupertinoBottomSheetDialog<DateTime>(
      context: context,
      builder: (sheetContext) {
        return Container(
          height: 300,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground.resolveFrom(context),
            sheetContext,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selected,
                  maximumDate: DateTime(9999, 12, 31),
                  minimumDate: DateTime(1970, 1, 1),
                  onDateTimeChanged: (value) {
                    selected = _normalizeDateOnly(value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleSameTitleRemovedFromMenu() async {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return;
    }
    final chapter = _chapters[_currentChapterIndex];
    final enabled = _isChapterSameTitleRemovalEnabled(chapter.id);
    final sameTitleRemoved = _isCurrentChapterSameTitleRemoved();
    if (!sameTitleRemoved && enabled) {
      _showToast('未找到可移除的重复标题');
    }
    final nextEnabled = !sameTitleRemoved;
    _chapterSameTitleRemovedById[chapter.id] = nextEnabled;
    if (!widget.isEphemeral) {
      await _settingsService.saveChapterSameTitleRemoved(
        widget.bookId,
        chapter.id,
        nextEnabled,
      );
    }
    await _loadChapter(_currentChapterIndex, restoreOffset: true);
  }

  Future<void> _toggleEpubTagCleanupFromMenu({
    required bool ruby,
  }) async {
    if (!_isCurrentBookEpub()) {
      _showToast('当前书籍不是 EPUB');
      return;
    }
    final next = ruby ? !_delRubyTag : !_delHTag;
    if (!widget.isEphemeral) {
      if (ruby) {
        await _settingsService.saveBookDelRubyTag(widget.bookId, next);
      } else {
        await _settingsService.saveBookDelHTag(widget.bookId, next);
      }
    }
    if (!mounted) return;
    setState(() {
      if (ruby) {
        _delRubyTag = next;
      } else {
        _delHTag = next;
      }
    });
    await _clearLocalCatalogCacheBeforeRefresh();
    await _loadChapter(
      _clampChapterIndexToReadableRange(_currentChapterIndex),
      restoreOffset: true,
    );
  }

  Future<void> _exportBookmarksFromReader({
    required bool markdown,
  }) async {
    final bookmarks = _bookmarkRepo.getBookmarksForBook(widget.bookId);
    final result = markdown
        ? await _bookmarkExportService.exportMarkdown(
            bookTitle: widget.bookTitle,
            bookAuthor: _bookAuthor,
            bookmarks: bookmarks,
          )
        : await _bookmarkExportService.exportJson(
            bookTitle: widget.bookTitle,
            bookAuthor: _bookAuthor,
            bookmarks: bookmarks,
          );
    if (!mounted) return;
    if (result.success) {
      final path = result.outputPath?.trim();
      if (path != null && path.isNotEmpty) {
        _showToast('导出成功：$path');
      } else {
        _showToast(result.message ?? '导出成功');
      }
      return;
    }
    if (result.cancelled) return;
    _showToast(result.message ?? '导出失败');
  }

}
