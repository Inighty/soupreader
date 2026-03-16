import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../search/views/search_book_info_view.dart';
import '../../settings/views/app_help_dialog.dart';
import '../../settings/views/app_log_dialog.dart';
import '../controllers/actions_coordinator.dart';
import '../controllers/reader_coordinator.dart';
import '../controllers/reader_state.dart';
import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_resolver.dart';
import '../services/reader_legacy_menu_helper.dart';
import 'reader_content_editor.dart';
import '../widgets/reader_catalog_sheet.dart';
import '../widgets/reader_image_preview_page.dart';
import '../widgets/reader_more_config_sheet.dart';
import '../widgets/reader_style_quick_sheet.dart';

/// 阅读器对话框 / 底部弹窗的 Helper。
///
/// 所有需要 [BuildContext] 的弹窗操作集中在此文件。
/// 逻辑委托（Coordinator）不持有 Context，这里作为 View ↔ Coordinator 的桥梁。
class ReaderDialogHelpers {
  ReaderDialogHelpers._();

  // ═══════════════════════════════════════════════════════════════════
  // Toast
  // ═══════════════════════════════════════════════════════════════════

  /// 显示提示对话框。
  static void showToast(BuildContext context, String message) {
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

  /// 显示自动消失的复制提示。
  static void showCopyToast(BuildContext context, String message) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(
          const Duration(milliseconds: 1100),
          () {
            if (navigator.mounted && navigator.canPop()) {
              navigator.pop();
            }
          },
        ));
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground
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
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 章节列表
  // ═══════════════════════════════════════════════════════════════════

  /// 打开章节列表底部弹窗。
  static void showChapterList({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) {
    final chapter = coordinator.chapter;
    final image = coordinator.image;
    showCupertinoBottomSheetDialog(
      context: context,
      builder: (popupContext) => ReaderCatalogSheet(
        bookId: coordinator.bookId,
        bookTitle: coordinator.bookTitle,
        bookAuthor: image.bookAuthor,
        coverUrl: image.bookCoverUrl,
        chapters: chapter.chapters,
        currentChapterIndex: chapter.currentIndex,
        bookmarks: coordinator.bookmarkCtrl.bookmarks,
        onClearBookCache: () async {
          // TODO: 实现章节缓存清理
          return const ChapterCacheInfo(bytes: 0, chapters: 0);
        },
        onRefreshCatalog: () =>
            coordinator.actionsCoordinator.refreshCatalogFromSource(),
        onChapterSelected: (index) {
          Navigator.pop(popupContext);
          unawaited(coordinator.loadChapter(index));
        },
        onBookmarkSelected: (bookmark) {
          Navigator.pop(popupContext);
          unawaited(coordinator.loadChapter(
            bookmark.chapterIndex,
            restoreOffset: true,
          ));
        },
        onDeleteBookmark: (bookmark) async {
          await coordinator.bookmarkCtrl.remove(
            bookmark.id,
            bookmark.chapterIndex,
          );
        },
        isLocalTxtBook:
            coordinator.actionsCoordinator.isCurrentBookLocalTxt(),
        initialUseReplace: coordinator.settings.useReplaceRule,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 界面设置
  // ═══════════════════════════════════════════════════════════════════

  /// 打开界面样式快捷设置底部弹窗。
  static void showStyleQuickSheet({
    required BuildContext context,
    required ReadingSettings settings,
    required List<ReadingThemeColors> themes,
    required List<ReadStyleConfig> styleConfigs,
    required ValueChanged<ReadingSettings> onSettingsChanged,
  }) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) => ReaderStyleQuickSheet(
        settings: settings,
        themes: themes,
        styleConfigs: styleConfigs,
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  /// 打开行为设置底部弹窗。
  static void showBehaviorSettings(BuildContext context) {
    showReaderMoreConfigSheet(context);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 图片预览
  // ═══════════════════════════════════════════════════════════════════

  /// 打开图片全屏预览页。
  static void openImagePreview({
    required BuildContext context,
    required String src,
  }) {
    final request = ReaderImageRequestParser.parse(src);
    final imageProvider = const ReaderImageResolver(isWeb: kIsWeb)
        .resolveProvider(request, headers: request.headers);
    if (imageProvider == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReaderImagePreviewPage(
          imageProvider: imageProvider,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // WebDAV 进度
  // ═══════════════════════════════════════════════════════════════════

  /// 上传进度到 WebDAV 并显示结果 Toast。
  static Future<void> pushProgressToWebDav({
    required BuildContext context,
    required ActionsCoordinator actions,
  }) async {
    final result = await actions.pushProgressToWebDav();
    if (!context.mounted) return;
    if (result.skipped) return;
    if (result.success) {
      showToast(context, '上传成功');
    } else if (result.errorMessage != null) {
      showToast(context, result.errorMessage!);
    }
  }

  /// 从 WebDAV 拉取进度，酌情弹窗确认。
  static Future<void> pullProgressFromWebDav({
    required BuildContext context,
    required ActionsCoordinator actions,
  }) async {
    final result = await actions.pullProgressFromWebDav();
    if (!context.mounted) return;
    if (result.errorMessage != null) {
      showToast(context, result.errorMessage!);
      return;
    }
    if (!result.hasData) return;

    if (result.needsConfirmation) {
      final confirmed = await showCupertinoBottomSheetDialog<bool>(
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
      if (!confirmed || !context.mounted) return;
    }

    await actions.applyRemoteProgress(result);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 日夜模式
  // ═══════════════════════════════════════════════════════════════════

  /// 切换日夜主题模式。
  static void toggleDayNightTheme({
    required SettingsState settings,
    required ReaderCoordinator coordinator,
  }) {
    final currentTheme = settings.themeResolver;
    final isDark = currentTheme.isDark;
    final newSettings = settings.settings.copyWith(
      themeIndex: isDark ? 0 : settings.settings.readStyleConfigs.length,
    );
    coordinator.updateSettings(newSettings);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 导航
  // ═══════════════════════════════════════════════════════════════════

  /// 打开书籍详情页。
  static Future<void> openBookInfo({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) async {
    final book = coordinator.bookRepo.getBookById(coordinator.bookId);
    if (book == null) {
      showToast(context, '当前会话未关联书架书籍，无法打开书籍详情');
      return;
    }
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 更多操作菜单
  // ═══════════════════════════════════════════════════════════════════

  /// 打开"更多操作"底部菜单。
  static void showMoreActionsMenu({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) {
    final actions = coordinator.actionsCoordinator;
    final isLocal = actions.isCurrentBookLocal();
    final isEpub = actions.isCurrentBookEpub();
    final menuActions = ReaderLegacyMenuHelper.buildReadMenuActions(
      isOnline: !isLocal,
      isLocalTxt: actions.isCurrentBookLocalTxt(),
      isEpub: isEpub,
      showWebDavProgressActions: actions.hasWebDavProgressConfig(),
    ).where((a) =>
        a != ReaderLegacyReadMenuAction.changeSource &&
        a != ReaderLegacyReadMenuAction.refresh &&
        a != ReaderLegacyReadMenuAction.download &&
        a != ReaderLegacyReadMenuAction.tocRule &&
        a != ReaderLegacyReadMenuAction.setCharset).toList();

    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('阅读操作'),
        actions: menuActions.map((action) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _executeReadMenuAction(
                context: context,
                coordinator: coordinator,
                action: action,
              );
            },
            child: Text(ReaderLegacyMenuHelper.readMenuLabel(action)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  /// 执行菜单操作项。
  static void _executeReadMenuAction({
    required BuildContext context,
    required ReaderCoordinator coordinator,
    required ReaderLegacyReadMenuAction action,
  }) {
    final actions = coordinator.actionsCoordinator;
    switch (action) {
      case ReaderLegacyReadMenuAction.addBookmark:
        _addBookmark(context: context, coordinator: coordinator);
      case ReaderLegacyReadMenuAction.editContent:
        unawaited(_openContentEditor(
          context: context,
          coordinator: coordinator,
        ));
      case ReaderLegacyReadMenuAction.pageAnim:
        _showPageAnimPicker(
          context: context,
          coordinator: coordinator,
        );
      case ReaderLegacyReadMenuAction.getProgress:
        unawaited(pullProgressFromWebDav(
          context: context,
          actions: actions,
        ));
      case ReaderLegacyReadMenuAction.coverProgress:
        unawaited(pushProgressToWebDav(
          context: context,
          actions: actions,
        ));
      case ReaderLegacyReadMenuAction.reverseContent:
        unawaited(actions.reverseCurrentChapterContent());
      case ReaderLegacyReadMenuAction.simulatedReading:
        showToast(context, '模拟阅读功能开发中');
      case ReaderLegacyReadMenuAction.enableReplace:
        unawaited(actions.toggleReplaceRule());
      case ReaderLegacyReadMenuAction.sameTitleRemoved:
        unawaited(actions.toggleSameTitleRemoved());
      case ReaderLegacyReadMenuAction.reSegment:
        unawaited(actions.toggleReSegment());
      case ReaderLegacyReadMenuAction.delRubyTag:
        unawaited(actions.toggleEpubTagCleanup(ruby: true));
      case ReaderLegacyReadMenuAction.delHTag:
        unawaited(actions.toggleEpubTagCleanup(ruby: false));
      case ReaderLegacyReadMenuAction.imageStyle:
        _showImageStylePicker(
          context: context,
          coordinator: coordinator,
        );
      case ReaderLegacyReadMenuAction.updateToc:
        unawaited(_updateToc(
          context: context,
          coordinator: coordinator,
        ));
      case ReaderLegacyReadMenuAction.effectiveReplaces:
        showToast(context, '生效替换规则预览开发中');
      case ReaderLegacyReadMenuAction.log:
        unawaited(_openLogs(context));
      case ReaderLegacyReadMenuAction.help:
        unawaited(_openHelp(context));
      default:
        break;
    }
  }

  /// 添加书签。
  static void _addBookmark({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) {
    final chapter = coordinator.chapter;
    if (chapter.chapters.isEmpty) return;
    final idx = chapter.currentIndex.clamp(0, chapter.maxIndex);
    unawaited(coordinator.bookmarkCtrl.addAtCurrentPosition(
      bookAuthor: coordinator.image.bookAuthor,
      chapterIndex: idx,
      chapterTitle: chapter.chapters[idx].title,
      chapterProgress: coordinator.getChapterProgress(),
      currentContent: chapter.currentContent,
    ));
    showCopyToast(context, '书签已添加');
  }

  /// 打开内容编辑页。
  static Future<void> _openContentEditor({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) async {
    final chapter = coordinator.chapter;
    if (chapter.chapters.isEmpty) return;
    final idx = chapter.currentIndex.clamp(0, chapter.maxIndex);
    final ch = chapter.chapters[idx];

    final payload =
        await Navigator.of(context).push<ReaderContentEditPayload>(
      CupertinoPageRoute<ReaderContentEditPayload>(
        fullscreenDialog: true,
        builder: (_) => ReaderContentEditorPage(
          initialTitle: ch.title,
          initialContent: ch.content ?? '',
        ),
      ),
    );
    if (payload == null || !context.mounted) return;
    await coordinator.actionsCoordinator.applyContentEdit(
      chapterIndex: idx,
      newTitle: payload.title,
      newContent: payload.content,
    );
  }

  /// 翻页动画选择器。
  static void _showPageAnimPicker({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) {
    final currentAnim =
        coordinator.settings.bookPageAnimOverride ?? 0;
    showCupertinoBottomSheetDialog<int>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('翻页动画'),
        actions: [
          for (final entry in _pageAnimOptions.entries)
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(sheetContext, entry.key),
              isDefaultAction: entry.key == currentAnim,
              child: Text(entry.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    ).then((selected) {
      if (selected == null) return;
      unawaited(coordinator.actionsCoordinator
          .applyBookPageAnim(selected));
    });
  }

  static const Map<int, String> _pageAnimOptions = {
    0: '仿真翻页',
    1: '覆盖翻页',
    2: '滑动翻页',
    3: '无动画',
  };

  /// 图片样式选择器。
  static void _showImageStylePicker({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) {
    final styles = ActionsCoordinator.legacyImageStyles;
    final current = coordinator.settings.imageStyle;
    showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('图片样式'),
        actions: styles.map((style) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, style),
            isDefaultAction: style == current,
            child: Text(style),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    ).then((selected) {
      if (selected == null) return;
      unawaited(coordinator.actionsCoordinator
          .applyImageStyle(selected));
    });
  }

  /// 打开日志页面。
  static Future<void> _openLogs(BuildContext context) async {
    await showAppLogDialog(context);
  }

  /// 打开帮助页面。
  static Future<void> _openHelp(BuildContext context) async {
    try {
      final markdownText = await rootBundle.loadString(
        'assets/web/help/md/readMenuHelp.md',
      );
      if (!context.mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!context.mounted) return;
      showToast(context, '帮助文档加载失败：$error');
    }
  }

  /// 更新目录并处理错误。
  static Future<void> _updateToc({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) async {
    coordinator.chapter.update(loading: true);
    try {
      await coordinator.actionsCoordinator.refreshCatalogFromSource();
    } catch (e) {
      if (!context.mounted) return;
      showToast(context, '更新目录失败：$e');
    } finally {
      coordinator.chapter.update(loading: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 导航
  // ═══════════════════════════════════════════════════════════════════

  /// 打开章节链接（浏览器或 WebView）。
  static Future<void> openChapterLink({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) async {
    final chapters = coordinator.chapter.chapters;
    final idx = coordinator.chapter.currentIndex;
    if (chapters.isEmpty || idx < 0 || idx >= chapters.length) {
      showToast(context, '当前章节链接为空');
      return;
    }
    final chapterUrl = (chapters[idx].url ?? '').trim();
    if (chapterUrl.isEmpty) {
      showToast(context, '当前章节链接为空');
      return;
    }
    final uri = Uri.tryParse(chapterUrl);
    if (uri == null || (!uri.hasScheme) ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      showToast(context, '当前章节链接不是有效网页地址');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
