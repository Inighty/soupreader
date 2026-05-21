import 'package:flutter/cupertino.dart';

import '../controllers/reader_coordinator.dart';
import '../controllers/reader_state.dart';
import '../models/reading_settings.dart';
import '../widgets/paged_reader_widget.dart';
import 'reader_dialog_helpers.dart';

/// 阅读器主体内容（分页 / 滚动两种模式自动切换）。
class ReaderContent extends StatelessWidget {
  const ReaderContent({
    super.key,
    required this.coordinator,
    required this.chapter,
    required this.settings,
    required this.scroll,
    required this.paged,
    required this.ui,
    required this.bookTitle,
    required this.pagedContentKey,
  });

  final ReaderCoordinator coordinator;
  final ChapterState chapter;
  final SettingsState settings;
  final ScrollModeState scroll;
  final PagedModeState paged;
  final UiState ui;
  final String bookTitle;
  final GlobalKey pagedContentKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([chapter, settings]),
      builder: (context, _) {
        final isScroll =
            settings.settings.pageTurnMode == PageTurnMode.scroll;
        if (isScroll) {
          return _ReaderScrollContent(
            chapter: chapter,
            settings: settings,
            scroll: scroll,
          );
        }
        return _ReaderPagedContent(
          coordinator: coordinator,
          chapter: chapter,
          settings: settings,
          paged: paged,
          ui: ui,
          bookTitle: bookTitle,
          pagedContentKey: pagedContentKey,
        );
      },
    );
  }
}

class _ReaderPagedContent extends StatelessWidget {
  const _ReaderPagedContent({
    required this.coordinator,
    required this.chapter,
    required this.settings,
    required this.paged,
    required this.ui,
    required this.bookTitle,
    required this.pagedContentKey,
  });

  final ReaderCoordinator coordinator;
  final ChapterState chapter;
  final SettingsState settings;
  final PagedModeState paged;
  final UiState ui;
  final String bookTitle;
  final GlobalKey pagedContentKey;

  @override
  Widget build(BuildContext context) {
    final theme = settings.themeResolver;
    final readingSettings = settings.settings;
    // 渲染层 TextStyle 必须与分页 (ReaderPageAgent.paginateContent) 使用的
    // TextStyle 字段完全一致，否则相同段文本在两边会计算出不同的换行/行数，
    // 导致页面边界与渲染行数错位 —— 表现为翻页时正文断续、有遗漏。
    return KeyedSubtree(
      key: pagedContentKey,
      child: PagedReaderWidget(
        pageFactory: paged.pageFactory,
        pageTurnMode: readingSettings.pageTurnMode,
        textStyle: TextStyle(
          fontSize: readingSettings.fontSize,
          height: readingSettings.lineHeight,
          letterSpacing: readingSettings.letterSpacing,
          color: theme.currentTheme.text,
          fontFamily: theme.fontFamily,
          fontFamilyFallback: theme.fontFamilyFallback,
          fontWeight: theme.fontWeight,
          decoration: theme.textDecoration,
        ),
        backgroundColor: theme.backgroundColor,
        backgroundUiImage: settings.bgUiImage,
        padding: EdgeInsets.fromLTRB(
          readingSettings.paddingLeft,
          readingSettings.paddingTop,
          readingSettings.paddingRight,
          readingSettings.paddingBottom,
        ),
        settings: readingSettings,
        paddingDisplayCutouts: readingSettings.paddingDisplayCutouts,
        bookTitle: bookTitle,
        clickActions: ClickAction.defaultZoneConfig,
        // PagedReaderWidget 内层 GestureDetector 会吃掉外层的 onTapUp，
        // 必须在这里连接 onTap，否则菜单区域点击事件被丢弃。
        onTap: () {
          final size = MediaQuery.sizeOf(context);
          coordinator.inputCoordinator.handleTap(
            Offset(size.width / 2, size.height / 2),
            size,
          );
        },
        onAction: (action) {
          coordinator.inputCoordinator.handleClickAction(action);
        },
        legacyImageStyle: settings.imageStyle,
        onImageSizeResolved: (src, size) {
          coordinator.imageCoordinator
              .handlePagedImageSizeResolved(src, size);
        },
        onImageSizeCacheUpdated: () {
          paged.pendingImageRepagination = true;
        },
        onImageTap: (src) {
          ReaderDialogHelpers.openImagePreview(context: context, src: src);
        },
        controller: paged.pagedController,
        animDuration: readingSettings.pageAnimDuration,
        pageDirection: readingSettings.pageDirection,
        pageTouchSlop: readingSettings.pageTouchSlop,
        enableGestures: !ui.showMenu,
      ),
    );
  }
}

class _ReaderScrollContent extends StatelessWidget {
  const _ReaderScrollContent({
    required this.chapter,
    required this.settings,
    required this.scroll,
  });

  final ChapterState chapter;
  final SettingsState settings;
  final ScrollModeState scroll;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: scroll.segmentsVersion,
      builder: (context, _, __) {
        if (scroll.segments.isEmpty) {
          return Center(
            child: Text(
              chapter.currentTitle,
              style: TextStyle(
                color: settings.themeResolver.currentTheme.text,
              ),
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // ScrollCoordinator 通过 tick 机制处理，此处仅占位。
            return false;
          },
          child: ListView.builder(
            key: scroll.viewportKey,
            controller: scroll.controller,
            itemCount: scroll.segments.length,
            itemBuilder: (context, index) {
              final segment = scroll.segments[index];
              return Container(
                key: scroll.segmentKeys.putIfAbsent(
                  segment.chapterIndex,
                  () => GlobalKey(
                    debugLabel: 'seg_${segment.chapterIndex}',
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: settings.settings.paddingLeft,
                  vertical: 16,
                ),
                child: Text(
                  segment.content,
                  style: TextStyle(
                    fontSize: settings.settings.fontSize,
                    height: settings.settings.lineHeight,
                    letterSpacing: settings.settings.letterSpacing,
                    color: settings.themeResolver.currentTheme.text,
                    fontFamily: settings.themeResolver.fontFamily,
                    fontFamilyFallback: settings.themeResolver.fontFamilyFallback,
                    fontWeight: settings.themeResolver.fontWeight,
                    decoration: settings.themeResolver.textDecoration,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
