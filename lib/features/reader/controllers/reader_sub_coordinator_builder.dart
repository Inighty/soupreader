import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import '../../bookshelf/services/bookshelf_catalog_update_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../services/reader_charset_service.dart';
import 'actions_coordinator.dart';
import 'image_coordinator.dart';
import 'input_coordinator.dart';
import 'reader_bookmark_controller.dart';
import 'reader_read_aloud_controller.dart';
import 'reader_settings_controller.dart';
import 'reader_state.dart';
import 'scroll_coordinator.dart';
import 'source_switch_coordinator.dart';

typedef LoadChapterCallback = Future<void> Function(
  int index, {
  bool restoreOffset,
  double? targetChapterProgress,
});

/// 子 coordinator 初始化的产物：5 个子 coordinator + scrollCoordinator 引用。
class ReaderSubCoordinatorBundle {
  final ActionsCoordinator actions;
  final ScrollCoordinator scroll;
  final InputCoordinator input;
  final ImageCoordinator image;
  final SourceSwitchCoordinator? sourceSwitch;

  const ReaderSubCoordinatorBundle({
    required this.actions,
    required this.scroll,
    required this.input,
    required this.image,
    required this.sourceSwitch,
  });
}

/// 集中构建阅读器的 5 个子 coordinator，避免主 coordinator 文件过长。
ReaderSubCoordinatorBundle buildReaderSubCoordinators({
  required String bookId,
  required String bookTitle,
  required bool isEphemeral,
  required ChapterState chapter,
  required UiState ui,
  required SettingsState settings,
  required ScrollModeState scroll,
  required PagedModeState paged,
  required ImageCacheState image,
  required ReaderReadAloudController readAloudCtrl,
  required ReaderBookmarkController bookmarkCtrl,
  required ReaderSettingsController settingsCtrl,
  required BookRepository bookRepo,
  required ChapterRepository chapterRepo,
  required SourceRepository sourceRepo,
  required SettingsService settingsService,
  required WebDavService webDavService,
  required BookshelfCatalogUpdateService catalogUpdateService,
  required RuleParserEngine ruleEngine,
  required LoadChapterCallback onLoadChapter,
  required VoidCallback onToggleMenu,
  required VoidCallback onNextChapter,
  required VoidCallback onPreviousChapter,
  required double Function() getChapterProgress,
  required double Function() getBookProgress,
  required String Function() getCurrentTime,
  required Future<ScrollSegment> Function(int chapterIndex,
      {bool showLoading}) buildSegment,
  required Future<void> Function() onSaveProgress,
}) {
  final actions = ActionsCoordinator(
    bookId: bookId,
    bookTitle: bookTitle,
    isEphemeral: isEphemeral,
    chapter: chapter,
    settings: settings,
    image: image,
    bookRepo: bookRepo,
    chapterRepo: chapterRepo,
    sourceRepo: sourceRepo,
    settingsService: settingsService,
    webDavService: webDavService,
    charsetService: ReaderCharsetService(),
    catalogUpdateService: catalogUpdateService,
    ruleEngine: ruleEngine,
    onLoadChapter: (index, {
      bool restoreOffset = false,
      double? targetChapterProgress,
    }) =>
        onLoadChapter(
          index,
          restoreOffset: restoreOffset,
          targetChapterProgress: targetChapterProgress,
        ),
    onShowToast: ui.showToast,
    getChapterProgress: getChapterProgress,
    getBookProgress: getBookProgress,
  );

  final scrollCoordinator = ScrollCoordinator(
    scroll: scroll,
    chapter: chapter,
    settings: settings,
    buildSegment: buildSegment,
    onChapterChanged: () => bookmarkCtrl.updateStatus(chapter.currentIndex),
    onSaveProgress: onSaveProgress,
    getBookProgress: getBookProgress,
    getCurrentTime: getCurrentTime,
  );

  final input = InputCoordinator(
    chapter: chapter,
    ui: ui,
    settings: settings,
    paged: paged,
    scroll: scroll,
    onToggleMenu: onToggleMenu,
    onShowAutoReadPanel: () => ui.toggleAutoReadPanel(true),
    onNextChapter: onNextChapter,
    onPreviousChapter: onPreviousChapter,
    onScrollPage: ({required bool up}) => scrollCoordinator.scrollPage(up: up),
    onShowToast: ui.showToast,
    onAddBookmark: () {
      unawaited(bookmarkCtrl.addAtCurrentPosition(
        bookAuthor: image.bookAuthor,
        chapterIndex: chapter.currentIndex,
        chapterTitle: chapter.currentTitle,
        chapterProgress: getChapterProgress(),
        currentContent: chapter.currentContent,
      ));
    },
    onShowChapterList: () => ui.toggleMenu(false),
    onSearchContent: () {
      ui.toggleMenu(false);
      ui.toggleSearchMenu(true);
    },
    onEditContent: () => ui.toggleMenu(false),
    onToggleReplaceRule: () => unawaited(actions.toggleReplaceRule()),
    onSyncProgress: () => unawaited(actions.pullProgressFromWebDav()),
    onReadAloudPrev: () => unawaited(readAloudCtrl.previousParagraph()),
    onReadAloudNext: () => unawaited(readAloudCtrl.nextParagraph()),
    onReadAloudToggle: () => unawaited(readAloudCtrl.togglePauseResume()),
    onScreenOffTimerStart: () =>
        settingsCtrl.screenOffTimerStart(settings.settings),
    isAutoPagerRunning: () => ui.autoPager.isRunning,
    clickActions: ClickAction.defaultZoneConfig,
  );

  final imageCoordinator = ImageCoordinator(
    bookId: bookId,
    isEphemeral: isEphemeral,
    image: image,
    settingsService: settingsService,
    ruleEngine: ruleEngine,
    resolveCurrentSource: () {
      final url = (image.sourceUrl ?? '').trim();
      if (url.isEmpty) return null;
      return sourceRepo.getSourceByUrl(url);
    },
    recentFetchDuration: () => chapter.recentFetchDuration,
  );

  SourceSwitchCoordinator? sourceSwitch;
  if (!isEphemeral) {
    sourceSwitch = SourceSwitchCoordinator(
      bookId: bookId,
      chapter: chapter,
      image: image,
      sourceRepo: sourceRepo,
      ruleEngine: ruleEngine,
      settingsService: settingsService,
      onSourceSwitched: (newSourceUrl) async {
        chapter.chapters = chapterRepo.getChaptersForBook(bookId);
        chapter.notify();
      },
    );
  }

  return ReaderSubCoordinatorBundle(
    actions: actions,
    scroll: scrollCoordinator,
    input: input,
    image: imageCoordinator,
    sourceSwitch: sourceSwitch,
  );
}
