import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../controllers/reader_coordinator.dart';
import '../controllers/reader_state.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_menus.dart';
import 'reader_dialog_helpers.dart';
import 'source_switch_dialogs.dart';

/// 阅读页菜单覆盖层（顶部 + 底部菜单）。
///
/// 监听 `ui` / `chapter` / `settings` 状态：当 `ui.showMenu` 关闭时直接渲染空。
class ReaderMenuOverlay extends StatelessWidget {
  const ReaderMenuOverlay({
    super.key,
    required this.coordinator,
    required this.chapter,
    required this.ui,
    required this.settings,
    required this.paged,
    required this.image,
    required this.bookTitle,
    required this.menuFadeAnimation,
    required this.topMenuSlideAnimation,
    required this.bottomMenuSlideAnimation,
  });

  final ReaderCoordinator coordinator;
  final ChapterState chapter;
  final UiState ui;
  final SettingsState settings;
  final PagedModeState paged;
  final ImageCacheState image;
  final String bookTitle;
  final Animation<double> menuFadeAnimation;
  final Animation<Offset> topMenuSlideAnimation;
  final Animation<Offset> bottomMenuSlideAnimation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ui, chapter, settings]),
      builder: (context, _) {
        if (!ui.showMenu) return const SizedBox.shrink();
        final theme = settings.themeResolver;
        final isLocal = coordinator.actionsCoordinator.isCurrentBookLocal();
        final isLocalTxt =
            coordinator.actionsCoordinator.isCurrentBookLocalTxt();

        return Stack(
          children: [
            ReaderTopMenu(
              onBack: () => Navigator.maybePop(context),
              bookTitle: bookTitle,
              chapterTitle: chapter.currentTitle,
              sourceName: image.sourceName,
              currentTheme: theme.currentTheme,
              onOpenBookInfo: () {
                coordinator.closeMenu();
                unawaited(ReaderDialogHelpers.openBookInfo(
                  context: context,
                  coordinator: coordinator,
                ));
              },
              onOpenChapterLink: () {
                coordinator.closeMenu();
                unawaited(ReaderDialogHelpers.openChapterLink(
                  context: context,
                  coordinator: coordinator,
                ));
              },
              onToggleChapterLinkOpenMode: () {
                // 暂不支持 WebView/浏览器切换。
              },
              onChangeSource: () {
                coordinator.closeMenu();
                unawaited(SourceSwitchDialogs.showSourceSwitchEntry(
                  context: context,
                  coordinator: coordinator,
                ));
              },
              onRefresh: () {
                coordinator.closeMenu();
                unawaited(coordinator.loadChapter(chapter.currentIndex));
              },
              onShowSourceActions: () {
                coordinator.closeMenu();
                unawaited(SourceSwitchDialogs.showSourceSwitchEntry(
                  context: context,
                  coordinator: coordinator,
                ));
              },
              onShowMoreMenu: () {
                coordinator.closeMenu();
                ReaderDialogHelpers.showMoreActionsMenu(
                  context: context,
                  coordinator: coordinator,
                );
              },
              showChangeSourceAction: !isLocal,
              showRefreshAction: !isLocal,
              showDownloadAction: !isLocal,
              showTocRuleAction: isLocalTxt,
              showSetCharsetAction: isLocal,
              showSourceAction: !isLocal,
              showChapterLink: !isLocal,
              showTitleAddition: settings.settings.showReadTitleAddition,
              readBarStyleFollowPage: false,
              menuFadeAnimation: menuFadeAnimation,
              menuSlideAnimation: topMenuSlideAnimation,
            ),
            ReaderBottomMenuNew(
              currentChapterIndex: chapter.currentIndex,
              totalChapters: chapter.readableCount,
              currentPageIndex: paged.pageFactory.currentPageIndex,
              totalPages: paged.pageFactory.totalPages.clamp(1, 999999),
              settings: settings.settings,
              currentTheme: theme.currentTheme,
              onChapterChanged: (index) =>
                  unawaited(coordinator.loadChapter(index)),
              onSeekChapterProgress: (progress) {
                unawaited(coordinator.loadChapter(
                  progress,
                  restoreOffset: true,
                ));
              },
              onSeekPageProgress: (page) {
                paged.pageFactory.jumpToPage(page);
              },
              onSettingsChanged: (newSettings) {
                coordinator.updateSettings(newSettings);
              },
              onShowChapterList: () {
                coordinator.closeMenu();
                ReaderDialogHelpers.showChapterList(
                  context: context,
                  coordinator: coordinator,
                );
              },
              onShowReadAloud: () {
                coordinator.closeMenu();
                unawaited(coordinator.readAloudController.toggleReadAloud(
                  chapterIndex: chapter.currentIndex,
                  chapterTitle: chapter.currentTitle,
                  content: chapter.currentContent,
                ));
              },
              onShowInterfaceSettings: () {
                final routeContext = Navigator.of(context).context;
                coordinator.closeMenu();
                ReaderDialogHelpers.showStyleQuickSheet(
                  context: routeContext,
                  settings: settings.settings,
                  themes: settings.themeResolver.activeStyles,
                  styleConfigs: settings.settings.readStyleConfigs,
                  onSettingsChanged: coordinator.updateSettings,
                );
              },
              onShowBehaviorSettings: () {
                final routeContext = Navigator.of(context).context;
                coordinator.closeMenu();
                ReaderDialogHelpers.showBehaviorSettings(routeContext);
              },
              onToggleAutoPage: () {
                coordinator.closeMenu();
                unawaited(coordinator.toggleAutoPage());
              },
              onSearchContent: () {
                coordinator.closeMenu();
                ui.toggleSearchMenu(true);
              },
              onToggleReplaceRule: () {
                coordinator.closeMenu();
                unawaited(coordinator.actionsCoordinator.toggleReplaceRule());
              },
              onToggleNightMode: () {
                ReaderDialogHelpers.toggleDayNightTheme(
                  settings: settings,
                  coordinator: coordinator,
                );
              },
              showReadAloud: true,
              readBarStyleFollowPage: false,
              readAloudRunning:
                  coordinator.readAloudController.snapshot.isRunning,
              readAloudPaused:
                  coordinator.readAloudController.snapshot.isPaused,
              autoPageRunning: ui.autoPager.isRunning,
              isNightMode: settings.themeResolver.isDark,
              menuFadeAnimation: menuFadeAnimation,
              menuSlideAnimation: bottomMenuSlideAnimation,
            ),
          ],
        );
      },
    );
  }
}
