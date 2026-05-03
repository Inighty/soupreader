import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../controllers/reader_coordinator.dart';
import '../controllers/reader_state.dart';
import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../widgets/auto_pager.dart';
import '../widgets/reader_read_aloud_bar.dart';
import '../widgets/reader_search_overlay.dart';
import '../widgets/reader_status_bar.dart';
import 'reader_dialog_helpers.dart';

/// 滚动模式下的状态栏（顶部 + 底部），分页模式下隐藏。
class ReaderStatusBars extends StatelessWidget {
  const ReaderStatusBars({
    super.key,
    required this.ui,
    required this.settings,
    required this.scroll,
  });

  final UiState ui;
  final SettingsState settings;
  final ScrollModeState scroll;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ui, settings]),
      builder: (context, _) {
        if (ui.showMenu || ui.showSearchMenu || ui.showAutoReadPanel) {
          return const SizedBox.shrink();
        }
        final isScroll =
            settings.settings.pageTurnMode == PageTurnMode.scroll;
        if (!isScroll) return const SizedBox.shrink();

        final readingSettings = settings.settings;
        final theme = settings.themeResolver.currentTheme;

        return ValueListenableBuilder<ScrollTipData>(
          valueListenable: scroll.tipNotifier,
          builder: (context, tip, _) {
            return Stack(
              children: [
                if (readingSettings.shouldShowFooter())
                  ReaderStatusBar(
                    settings: readingSettings,
                    currentTheme: theme,
                    currentTime: tip.currentTime,
                    title: tip.title,
                    bookTitle: tip.bookTitle,
                    bookProgress: tip.bookProgress,
                    chapterProgress: tip.chapterProgress,
                    currentPage: tip.currentPage,
                    totalPages: tip.totalPages,
                  ),
                if (readingSettings.shouldShowHeader(
                  showStatusBar: readingSettings.showStatusBar,
                ))
                  ReaderHeaderBar(
                    settings: readingSettings,
                    currentTheme: theme,
                    currentTime: tip.currentTime,
                    title: tip.title,
                    bookTitle: tip.bookTitle,
                    bookProgress: tip.bookProgress,
                    chapterProgress: tip.chapterProgress,
                    currentPage: tip.currentPage,
                    totalPages: tip.totalPages,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 章内搜索覆盖层。
class ReaderSearchOverlayHost extends StatelessWidget {
  const ReaderSearchOverlayHost({
    super.key,
    required this.coordinator,
    required this.ui,
    required this.chapter,
    required this.settings,
  });

  final ReaderCoordinator coordinator;
  final UiState ui;
  final ChapterState chapter;
  final SettingsState settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ui,
      builder: (context, _) {
        if (!ui.showSearchMenu) return const SizedBox.shrink();
        final theme = settings.themeResolver;
        return ReaderSearchOverlay(
          visible: ui.showSearchMenu,
          chapters: chapter.chapters,
          currentChapterIndex: chapter.currentIndex,
          currentChapterProgress: coordinator.getChapterProgress(),
          isDark: theme.isDark,
          accentColor: theme.accent,
          panelBg: theme.panelBg,
          textStrong: theme.textStrong,
          textNormal: theme.textNormal,
          textSubtle: theme.textSubtle,
          borderColor: theme.border,
          searchHighlightColor: theme.accent.withValues(
            alpha: theme.isDark ? 0.28 : 0.2,
          ),
          searchHighlightTextColor:
              CupertinoColors.label.resolveFrom(context),
          fontFamily: settings.customFontFamily,
          fontFamilyFallback: null,
          loadChapterContent: (index) async {
            if (index < 0 || index >= chapter.chapters.length) return '';
            return chapter.chapters[index].content ?? '';
          },
          processContent: (raw) async => raw,
          navigateToHit: (hit) async {
            await coordinator.loadChapter(
              hit.chapterIndex,
              restoreOffset: true,
            );
          },
          onClose: () => ui.toggleSearchMenu(false),
          onRequestRestoreProgress: () async => true,
        );
      },
    );
  }
}

/// 自动阅读控制面板。
class ReaderAutoReadPanelHost extends StatelessWidget {
  const ReaderAutoReadPanelHost({
    super.key,
    required this.coordinator,
    required this.ui,
  });

  final ReaderCoordinator coordinator;
  final UiState ui;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ui,
      builder: (context, _) {
        if (!ui.showAutoReadPanel) return const SizedBox.shrink();
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AutoReadPanel(
            autoPager: ui.autoPager,
            onClose: () => ui.toggleAutoReadPanel(false),
            onSpeedChanged: (speed) => ui.autoPager.setSpeed(speed),
            onShowMainMenu: () {
              ui.toggleAutoReadPanel(false);
              ui.autoPagerPausedByMenu = true;
              ui.autoPager.pause();
              coordinator.toggleMenu();
            },
            onOpenChapterList: () {
              ui.toggleAutoReadPanel(false);
              ReaderDialogHelpers.showChapterList(
                context: context,
                coordinator: coordinator,
              );
            },
            onStop: () {
              ui.autoPager.stop();
              ui.toggleAutoReadPanel(false);
            },
            onPause: () => ui.autoPager.pause(),
            onResume: () => ui.autoPager.resume(),
          ),
        );
      },
    );
  }
}

/// 朗读控制栏。
class ReaderReadAloudBarHost extends StatelessWidget {
  const ReaderReadAloudBarHost({
    super.key,
    required this.coordinator,
    required this.chapter,
    required this.settings,
  });

  final ReaderCoordinator coordinator;
  final ChapterState chapter;
  final SettingsState settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coordinator.readAloudController,
      builder: (context, _) {
        final snapshot = coordinator.readAloudController.snapshot;
        if (!snapshot.isRunning) return const SizedBox.shrink();

        final theme = settings.themeResolver;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ReaderReadAloudBar(
            snapshot: snapshot,
            speechRate: coordinator.readAloudController.speechRate,
            bgColor: theme.panelBg,
            fgColor: theme.textStrong,
            accentColor: theme.accent,
            onPreviousParagraph: () => unawaited(
                coordinator.readAloudController.previousParagraph()),
            onTogglePauseResume: () => unawaited(
                coordinator.readAloudController.togglePauseResume()),
            onNextParagraph: () =>
                unawaited(coordinator.readAloudController.nextParagraph()),
            onStop: () =>
                unawaited(coordinator.readAloudController.stop()),
            onSetTimer: () {
              // 朗读定时器选择对话框待迁移。
            },
            onOpenChapterList: () {
              ReaderDialogHelpers.showChapterList(
                context: context,
                coordinator: coordinator,
              );
            },
            onSpeechRateChanged: (rate) {
              unawaited(
                  coordinator.readAloudController.updateSpeechRate(rate));
            },
            onPreviousChapter: chapter.currentIndex > 0
                ? coordinator.previousChapter
                : null,
            onNextChapter: chapter.currentIndex < chapter.maxIndex
                ? coordinator.nextChapter
                : null,
          ),
        );
      },
    );
  }
}
