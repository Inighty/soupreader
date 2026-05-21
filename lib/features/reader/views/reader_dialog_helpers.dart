import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/colors.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../search/views/search_book_info_view.dart';
import '../controllers/actions_coordinator.dart';
import '../controllers/reader_coordinator.dart';
import '../controllers/reader_state.dart';
import '../models/reading_settings.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_resolver.dart';
import '../widgets/reader_catalog_sheet.dart';
import '../widgets/reader_image_preview_page.dart';
import '../widgets/reader_info_bar_quick_sheet.dart';
import '../widgets/reader_more_config_sheet.dart';
import '../widgets/reader_padding_config_dialog.dart';
import '../widgets/reader_style_quick_sheet.dart';
import 'reader_dialog_more_actions.dart';

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
    VoidCallback? onOpenPaddingSettings,
    VoidCallback? onOpenTipSettings,
  }) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) => ReaderStyleQuickSheet(
        settings: settings,
        themes: themes,
        styleConfigs: styleConfigs,
        onSettingsChanged: onSettingsChanged,
        onOpenPaddingSettings: onOpenPaddingSettings,
        onOpenTipSettings: onOpenTipSettings,
      ),
    );
  }

  /// 打开「边距」快捷设置（页眉/正文/页脚边距 + 分割线）。
  static Future<void> showPaddingQuickSheet({
    required BuildContext context,
    required ReadingSettings settings,
    required ValueChanged<ReadingSettings> onSettingsChanged,
    required bool isDarkMode,
  }) {
    return showReaderPaddingConfigDialog(
      context,
      settings: settings,
      onSettingsChanged: onSettingsChanged,
      isDarkMode: isDarkMode,
    );
  }

  /// 打开「信息栏」快捷设置（页眉/页脚显示 + 状态栏元素开关）。
  static void showInfoBarQuickSheet({
    required BuildContext context,
    required ReadingSettings settings,
    required ValueChanged<ReadingSettings> onSettingsChanged,
  }) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) => ReaderInfoBarQuickSheet(
        settings: settings,
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
    ReaderMoreActionsDialog.show(context: context, coordinator: coordinator);
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
