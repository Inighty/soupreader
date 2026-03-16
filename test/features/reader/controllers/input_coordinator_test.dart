import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/controllers/input_coordinator.dart';
import 'package:soupreader/features/reader/controllers/reader_state.dart';
import 'package:soupreader/features/reader/models/reading_settings.dart';

void main() {
  late ChapterState chapter;
  late UiState ui;
  late SettingsState settings;
  late PagedModeState paged;
  late ScrollModeState scroll;
  late List<String> callLog;
  late InputCoordinator coordinator;

  setUp(() {
    chapter = ChapterState();
    ui = UiState();
    settings = SettingsState();
    paged = PagedModeState();
    scroll = ScrollModeState();
    callLog = [];

    coordinator = InputCoordinator(
      chapter: chapter,
      ui: ui,
      settings: settings,
      paged: paged,
      scroll: scroll,
      onToggleMenu: () => callLog.add('toggleMenu'),
      onShowAutoReadPanel: () => callLog.add('showAutoReadPanel'),
      onNextChapter: () => callLog.add('nextChapter'),
      onPreviousChapter: () => callLog.add('previousChapter'),
      onScrollPage: ({required bool up}) async {
        callLog.add('scrollPage:up=$up');
      },
      onShowToast: (msg) => callLog.add('toast:$msg'),
      onAddBookmark: () => callLog.add('addBookmark'),
      onShowChapterList: () => callLog.add('showChapterList'),
      onSearchContent: () => callLog.add('searchContent'),
      onEditContent: () => callLog.add('editContent'),
      onToggleReplaceRule: () => callLog.add('toggleReplaceRule'),
      onSyncProgress: () => callLog.add('syncProgress'),
      onReadAloudPrev: () => callLog.add('readAloudPrev'),
      onReadAloudNext: () => callLog.add('readAloudNext'),
      onReadAloudToggle: () => callLog.add('readAloudToggle'),
      onScreenOffTimerStart: () => callLog.add('screenOff'),
      isAutoPagerRunning: () => false,
      clickActions: ClickAction.defaultZoneConfig,
    );
  });

  tearDown(() {
    scroll.dispose();
  });

  group('InputCoordinator', () {
    group('resolveClickAction', () {
      test('center tap maps to showMenu', () {
        const screenSize = Size(300, 600);
        // Center of screen: (150, 300) → col=1, row=1 → 'mc'
        final action = coordinator.resolveClickAction(
          const Offset(150, 300),
          screenSize,
        );
        expect(action, ClickAction.showMenu);
      });

      test('top-left tap maps to prevPage', () {
        const screenSize = Size(300, 600);
        // Top-left: (30, 30) → col=0, row=0 → 'tl'
        final action = coordinator.resolveClickAction(
          const Offset(30, 30),
          screenSize,
        );
        expect(action, ClickAction.prevPage);
      });

      test('bottom-right tap maps to nextPage', () {
        const screenSize = Size(300, 600);
        // Bottom-right: (280, 580) → col=2, row=2 → 'br'
        final action = coordinator.resolveClickAction(
          const Offset(280, 580),
          screenSize,
        );
        expect(action, ClickAction.nextPage);
      });

      test('middle-right tap maps to nextPage', () {
        const screenSize = Size(300, 600);
        // Middle-right: (280, 300) → col=2, row=1 → 'mr'
        final action = coordinator.resolveClickAction(
          const Offset(280, 300),
          screenSize,
        );
        expect(action, ClickAction.nextPage);
      });

      test('middle-left tap maps to prevPage', () {
        const screenSize = Size(300, 600);
        // Middle-left: (30, 300) → col=0, row=1 → 'ml'
        final action = coordinator.resolveClickAction(
          const Offset(30, 300),
          screenSize,
        );
        expect(action, ClickAction.prevPage);
      });
    });

    group('handleTap', () {
      test('closes search menu when showing', () {
        ui.toggleSearchMenu(true);
        coordinator.handleTap(
          const Offset(150, 300),
          const Size(300, 600),
        );
        expect(ui.showSearchMenu, isFalse);
        expect(callLog, contains('screenOff'));
        expect(callLog, isNot(contains('toggleMenu')));
      });

      test('closes auto read panel when showing', () {
        ui.toggleAutoReadPanel(true);
        coordinator.handleTap(
          const Offset(150, 300),
          const Size(300, 600),
        );
        expect(ui.showAutoReadPanel, isFalse);
      });

      test('closes menu when showing', () {
        ui.toggleMenu(true);
        coordinator.handleTap(
          const Offset(150, 300),
          const Size(300, 600),
        );
        expect(ui.showMenu, isFalse);
      });

      test('dispatches center tap to toggleMenu', () {
        coordinator.handleTap(
          const Offset(150, 300),
          const Size(300, 600),
        );
        expect(callLog, contains('toggleMenu'));
      });
    });

    group('handleClickAction', () {
      test('nextPage calls handlePageStep', () {
        // For paged mode (default), handlePageStep will try
        // paged controller but nothing is attached, so it falls
        // through to pageFactory which also has no pages → toast.
        coordinator.handleClickAction(ClickAction.nextPage);
        expect(callLog, contains('screenOff'));
        // In non-scroll mode without attached controller, it
        // attempts moveToNext on the factory → shows toast.
        expect(callLog, contains('toast:已到最后一页'));
      });

      test('prevChapter calls onPreviousChapter', () {
        coordinator.handleClickAction(ClickAction.prevChapter);
        expect(callLog, contains('previousChapter'));
      });

      test('nextChapter calls onNextChapter', () {
        coordinator.handleClickAction(ClickAction.nextChapter);
        expect(callLog, contains('nextChapter'));
      });

      test('addBookmark calls onAddBookmark', () {
        coordinator.handleClickAction(ClickAction.addBookmark);
        expect(callLog, contains('addBookmark'));
      });

      test('off does nothing', () {
        callLog.clear();
        coordinator.handleClickAction(ClickAction.off);
        // Only screenOff should be called
        expect(callLog, ['screenOff']);
      });

      test('syncBookProgress calls onSyncProgress', () {
        coordinator.handleClickAction(ClickAction.syncBookProgress);
        expect(callLog, contains('syncProgress'));
      });
    });

    group('handlePageStep', () {
      test('scroll mode delegates to onScrollPage', () {
        settings.update(
          const ReadingSettings(pageTurnMode: PageTurnMode.scroll),
        );
        coordinator.handlePageStep(next: true);
        expect(callLog, contains('scrollPage:up=false'));
      });

      test('scroll mode delegates up to onScrollPage', () {
        settings.update(
          const ReadingSettings(pageTurnMode: PageTurnMode.scroll),
        );
        coordinator.handlePageStep(next: false);
        expect(callLog, contains('scrollPage:up=true'));
      });
    });

    group('handleAutoPagerTick', () {
      test('calls onStopAtBoundary when no next page', () {
        var stopped = false;
        coordinator.handleAutoPagerTick(
          hasNextChapter: false,
          onStopAtBoundary: () => stopped = true,
        );
        // In paged mode without pages, moveToNext returns false
        expect(stopped, isTrue);
      });
    });
  });
}
