import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../settings/views/app_help_dialog.dart';
import '../../settings/views/app_log_dialog.dart';
import '../controllers/actions_coordinator.dart';
import '../controllers/reader_coordinator.dart';
import '../services/reader_legacy_menu_helper.dart';
import 'reader_content_editor.dart';
import 'reader_dialog_helpers.dart';

/// 阅读器"更多操作"底部菜单及其分支动作。
///
/// 从 [ReaderDialogHelpers] 抽出，避免主 helper 类过大。
class ReaderMoreActionsDialog {
  ReaderMoreActionsDialog._();

  /// 打开"更多操作"底部菜单。
  static void show({
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
              _execute(
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
  static void _execute({
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
        unawaited(ReaderDialogHelpers.pullProgressFromWebDav(
          context: context,
          actions: actions,
        ));
      case ReaderLegacyReadMenuAction.coverProgress:
        unawaited(ReaderDialogHelpers.pushProgressToWebDav(
          context: context,
          actions: actions,
        ));
      case ReaderLegacyReadMenuAction.reverseContent:
        unawaited(actions.reverseCurrentChapterContent());
      case ReaderLegacyReadMenuAction.simulatedReading:
        ReaderDialogHelpers.showToast(context, '模拟阅读功能开发中');
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
        ReaderDialogHelpers.showToast(context, '生效替换规则预览开发中');
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
    ReaderDialogHelpers.showCopyToast(context, '书签已添加');
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
      ReaderDialogHelpers.showToast(context, '帮助文档加载失败：$error');
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
      ReaderDialogHelpers.showToast(context, '更新目录失败：$e');
    } finally {
      coordinator.chapter.update(loading: false);
    }
  }
}
