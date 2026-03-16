import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/reading_settings.dart';
import '../services/reader_key_paging_helper.dart';
import 'reader_state.dart';

/// 用户输入（点击 / 键盘 / 鼠标滚轮）的纯逻辑委托。
///
/// 不持有 BuildContext——仅对输入事件做解析后调用回调。
class InputCoordinator {
  InputCoordinator({
    required this.chapter,
    required this.ui,
    required this.settings,
    required this.paged,
    required this.scroll,
    required this.onToggleMenu,
    required this.onShowAutoReadPanel,
    required this.onNextChapter,
    required this.onPreviousChapter,
    required this.onScrollPage,
    required this.onShowToast,
    required this.onAddBookmark,
    required this.onShowChapterList,
    required this.onSearchContent,
    required this.onEditContent,
    required this.onToggleReplaceRule,
    required this.onSyncProgress,
    required this.onReadAloudPrev,
    required this.onReadAloudNext,
    required this.onReadAloudToggle,
    required this.onScreenOffTimerStart,
    required this.isAutoPagerRunning,
    required this.clickActions,
  });

  final ChapterState chapter;
  final UiState ui;
  final SettingsState settings;
  final PagedModeState paged;
  final ScrollModeState scroll;

  // ── 回调 ──
  final VoidCallback onToggleMenu;
  final VoidCallback onShowAutoReadPanel;
  final VoidCallback onNextChapter;
  final VoidCallback onPreviousChapter;
  final Future<void> Function({required bool up}) onScrollPage;
  final void Function(String message) onShowToast;
  final VoidCallback onAddBookmark;
  final VoidCallback onShowChapterList;
  final VoidCallback onSearchContent;
  final VoidCallback onEditContent;
  final VoidCallback onToggleReplaceRule;
  final VoidCallback onSyncProgress;
  final VoidCallback onReadAloudPrev;
  final VoidCallback onReadAloudNext;
  final VoidCallback onReadAloudToggle;
  final VoidCallback onScreenOffTimerStart;
  final bool Function() isAutoPagerRunning;
  final Map<String, int> clickActions;

  // ═══════════════════════════════════════════════════════════════════
  // 点击处理
  // ═══════════════════════════════════════════════════════════════════

  /// 处理阅读区域点击事件。
  void handleTap(Offset localPosition, Size screenSize) {
    onScreenOffTimerStart();

    if (ui.showSearchMenu) {
      ui.toggleSearchMenu(false);
      return;
    }
    if (ui.showAutoReadPanel) {
      ui.toggleAutoReadPanel(false);
      return;
    }
    if (ui.showMenu) {
      ui.toggleMenu(false);
      return;
    }
    final action = resolveClickAction(localPosition, screenSize);
    handleClickAction(action);
  }

  /// 根据点击位置和 3×3 九宫格计算动作代号。
  int resolveClickAction(Offset position, Size size) {
    final col = (position.dx / size.width * 3).floor().clamp(0, 2);
    final row = (position.dy / size.height * 3).floor().clamp(0, 2);
    const zones = [
      ['tl', 'tc', 'tr'],
      ['ml', 'mc', 'mr'],
      ['bl', 'bc', 'br'],
    ];
    final zone = zones[row][col];
    return clickActions[zone] ?? ClickAction.showMenu;
  }

  /// 执行动作代号对应的操作。
  void handleClickAction(int action) {
    onScreenOffTimerStart();
    switch (action) {
      case ClickAction.off:
        break;
      case ClickAction.showMenu:
        if (isAutoPagerRunning()) {
          onShowAutoReadPanel();
        } else {
          onToggleMenu();
        }
      case ClickAction.nextPage:
        handlePageStep(next: true);
      case ClickAction.prevPage:
        handlePageStep(next: false);
      case ClickAction.nextChapter:
        onNextChapter();
      case ClickAction.prevChapter:
        onPreviousChapter();
      case ClickAction.addBookmark:
        onAddBookmark();
      case ClickAction.openChapterList:
        onShowChapterList();
      case ClickAction.searchContent:
        onSearchContent();
      case ClickAction.editContent:
        onEditContent();
      case ClickAction.toggleReplaceRule:
        onToggleReplaceRule();
      case ClickAction.syncBookProgress:
        onSyncProgress();
      case ClickAction.readAloudPrevParagraph:
        onReadAloudPrev();
      case ClickAction.readAloudNextParagraph:
        onReadAloudNext();
      case ClickAction.readAloudPauseResume:
        onReadAloudToggle();
      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 键盘事件
  // ═══════════════════════════════════════════════════════════════════

  /// 处理键盘事件（音量键翻页 / 自定义按键翻页）。
  void handleKeyEvent(
    KeyEvent event, {
    required bool readAloudPlaying,
  }) {
    if (ui.showMenu || ui.showSearchMenu || ui.showAutoReadPanel) {
      return;
    }
    final isRepeat = event is KeyRepeatEvent;
    final isKeyDown = event is KeyDownEvent || isRepeat;
    if (!isKeyDown) return;

    final readingSettings = settings.settings;
    if (isRepeat && !readingSettings.keyPageOnLongPress) return;

    final key = event.logicalKey;
    if (ReaderKeyPagingHelper.shouldBlockVolumePagingDuringReadAloud(
      key: key,
      readAloudPlaying: readAloudPlaying,
      volumeKeyPageOnPlayEnabled: readingSettings.volumeKeyPageOnPlay,
    )) {
      return;
    }
    onScreenOffTimerStart();

    final action = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: key,
      volumeKeyPageEnabled: readingSettings.volumeKeyPage,
      customPrevKeys: readingSettings.prevKeys,
      customNextKeys: readingSettings.nextKeys,
    );
    switch (action) {
      case ReaderKeyPagingAction.next:
        handlePageStep(next: true);
      case ReaderKeyPagingAction.prev:
        handlePageStep(next: false);
      case ReaderKeyPagingAction.none:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 翻页
  // ═══════════════════════════════════════════════════════════════════

  /// 翻一页（上 / 下）。
  ///
  /// 滚动模式走 [onScrollPage]；分页模式走 PageFactory。
  void handlePageStep({required bool next}) {
    onScreenOffTimerStart();
    if (settings.settings.pageTurnMode == PageTurnMode.scroll) {
      unawaited(onScrollPage(up: !next));
      return;
    }
    if (paged.pagedController.isAttached) {
      final moved = next
          ? paged.pagedController.turnNextPage()
          : paged.pagedController.turnPrevPage();
      if (!moved) {
        onShowToast(next ? '已到最后一页' : '已到第一页');
      }
      return;
    }
    final readingSettings = settings.settings;
    final moved = readingSettings.doublePage
        ? (next
            ? paged.pageFactory.moveToNextDouble()
            : paged.pageFactory.moveToPrevDouble())
        : (next
            ? paged.pageFactory.moveToNext()
            : paged.pageFactory.moveToPrev());
    if (!moved) {
      onShowToast(next ? '已到最后一页' : '已到第一页');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 自动翻页 tick
  // ═══════════════════════════════════════════════════════════════════

  /// 自动翻页器每一跳的回调。
  void handleAutoPagerTick({
    required bool hasNextChapter,
    required VoidCallback onStopAtBoundary,
  }) {
    if (settings.settings.pageTurnMode == PageTurnMode.scroll) {
      if (scroll.controller.hasClients) {
        final position = scroll.controller.position;
        final atBottom =
            scroll.controller.offset >= position.maxScrollExtent - 1;
        if (atBottom && !hasNextChapter) {
          onStopAtBoundary();
          return;
        }
      }
      unawaited(onScrollPage(up: false));
      return;
    }

    final moved = paged.pagedController.isAttached
        ? paged.pagedController.turnNextPage()
        : (settings.settings.doublePage
            ? paged.pageFactory.moveToNextDouble()
            : paged.pageFactory.moveToNext());
    if (!moved) {
      onStopAtBoundary();
    }
  }
}
