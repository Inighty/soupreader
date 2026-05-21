// ignore_for_file: invalid_use_of_protected_member

import '../../../core/models/app_settings.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_group_store_engine.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfLayoutOptions on BookshelfViewState {
  String layoutLabel(int index) {
    switch (normalizeLayoutIndex(index)) {
      case 0:
        return '列表';
      case 1:
        return '三列网格';
      case 2:
        return '四列网格';
      case 3:
        return '五列网格';
      case 4:
        return '六列网格';
      default:
        return '列表';
    }
  }

  String legacySortLabel(int index) {
    switch (normalizeSortIndex(index)) {
      case 0:
        return '最近阅读';
      case 1:
        return '最近更新';
      case 2:
        return '书名';
      case 3:
        return '手动';
      case 4:
        return '综合';
      case 5:
        return '作者';
      default:
        return '最近阅读';
    }
  }

  Future<void> applyLayoutConfig({
    required int groupStyle,
    required bool showUnread,
    required bool showLastUpdateTime,
    required bool showWaitUpCount,
    required bool showFastScroller,
    required int layoutIndex,
    required int sortIndex,
  }) async {
    final normalizedGroupStyle = groupStyle.clamp(0, 1);
    final normalizedLayout = normalizeLayoutIndex(layoutIndex);
    final normalizedSort = normalizeSortIndex(sortIndex);
    final nextSettings = settingsService.appSettings.copyWith(
      bookshelfGroupStyle: normalizedGroupStyle,
      bookshelfShowUnread: showUnread,
      bookshelfShowLastUpdateTime: showLastUpdateTime,
      bookshelfShowWaitUpCount: showWaitUpCount,
      bookshelfShowFastScroller: showFastScroller,
      bookshelfLayoutIndex: normalizedLayout,
      bookshelfViewMode: bookshelfViewModeFromLayoutIndex(normalizedLayout),
      bookshelfSortIndex: normalizedSort,
      bookshelfSortMode: bookshelfSortModeFromLegacyIndex(normalizedSort),
    );
    await settingsService.saveAppSettings(nextSettings);
    if (!mounted) return;
    setState(() {
      isGridView = normalizedLayout > 0;
      gridCrossAxisCount = gridColumnsForLayoutIndex(normalizedLayout);
      if (normalizedGroupStyle != 1) {
        selectedGroupId = BookshelfBookGroup.idRoot;
      }
    });
    await reloadBookGroupContext(showError: true);
    loadBooks();
  }
}
