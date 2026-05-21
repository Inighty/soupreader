// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_local_import.dart';
import 'bookshelf_display_engine.dart';
import 'bookshelf_grid_widgets.dart';
import 'bookshelf_group_bar_widgets.dart';
import 'bookshelf_list_widgets.dart';
import 'bookshelf_navigation.dart';
import 'bookshelf_view.dart';

extension BookshelfBodyWidgets on BookshelfViewState {
  int waitUpCount(List<Book> books) {
    return books.where((book) {
      if (book.isLocal) return false;
      return settingsService.getBookCanUpdate(book.id);
    }).length;
  }

  Widget? buildBookshelfMiddleTitle() {
    final settings = settingsService.appSettings;
    final pageTitle = currentBookshelfTitle();

    Widget buildTitleWidget() {
      if (isStyle2Enabled && selectedGroupId != BookshelfBookGroup.idRoot) {
        return Text(pageTitle);
      }
      if (!settings.bookshelfShowWaitUpCount) {
        return Text(pageTitle);
      }
      final count = waitUpCount(displayBooks());
      if (count <= 0) {
        return Text(pageTitle);
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pageTitle),
          const SizedBox(width: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!isStyle2Enabled) {
      if (!settings.bookshelfShowWaitUpCount) return null;
      final count = waitUpCount(displayBooks());
      if (count <= 0) return null;
      return buildTitleWidget();
    }

    // style2：标题可点击，带下拉箭头。
    return GestureDetector(
      onTap: openGroupSwitchSheet,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildTitleWidget(),
          const SizedBox(width: 3),
          Icon(
            CupertinoIcons.chevron_down,
            size: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ],
      ),
    );
  }

  Widget buildInitErrorPage() {
    return AppCupertinoPageScaffold(
      title: '书架',
      useSliverNavigationBar: true,
      sliverScrollController: scrollController,
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => SliverSafeArea(
        top: true,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: buildInitError(),
        ),
      ),
    );
  }

  Widget buildBodySliver() {
    if (initError != null) {
      return SliverSafeArea(
        top: true,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: buildInitError(),
        ),
      );
    }
    final visibleItems = displayItems();
    final contentSliver = visibleItems.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: buildEmptyState(),
          )
        : buildBookList(visibleItems);
    if (isStyle2Enabled) {
      return SliverSafeArea(
        top: true,
        bottom: true,
        sliver: contentSliver,
      );
    }
    return SliverSafeArea(
      top: true,
      bottom: true,
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: buildStyle1GroupBar(),
          ),
          contentSliver,
        ],
      ),
    );
  }

  Widget buildInitError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 40),
            const SizedBox(height: 12),
            Text(
              initError ?? '初始化失败',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 90),
      title: '书架空空如也',
      message: '先导入一本本地书，或从搜索添加网络书籍',
      action: CupertinoButton.filled(
        onPressed: importLocalBook,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc,
              size: 17,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 6),
            Text(
              '导入本地书籍',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBookList(List<Object> displayItems) {
    if (isGridView) {
      return buildGridSliver(displayItems);
    } else {
      return buildListSliver(displayItems);
    }
  }

  Widget wrapWithFastScroller(Widget child) {
    if (initError != null || displayItems().isEmpty) return child;
    if (!settingsService.appSettings.bookshelfShowFastScroller) {
      return child;
    }
    return CupertinoScrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: child,
    );
  }
}
