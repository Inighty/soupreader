// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../core/models/app_settings.dart';
import '../models/book.dart';
import 'bookshelf_view.dart';

extension BookshelfSortLayoutEngine on BookshelfViewState {
  void onExternalReselectSignal() {
    final version = widget.reselectSignal?.value;
    if (version == null) return;
    if (lastExternalReselectVersion == version) return;
    lastExternalReselectVersion = version;
    scrollToTop();
  }

  void scrollToTop() {
    if (!scrollController.hasClients) return;
    // 与 legado 一致：E-Ink 模式不做平滑动画，避免刷新残影。
    if (settingsService.appSettings.appearanceMode == AppAppearanceMode.eInk) {
      scrollController.jumpTo(0);
      return;
    }
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void loadBooks() {
    setState(() {
      books = List<Book>.from(bookRepo.getAllBooks());
      sortBooks(settingsService.appSettings.bookshelfSortIndex);
    });
  }

  int normalizeLayoutIndex(int index) {
    return index.clamp(0, 4);
  }

  int normalizeSortIndex(int index) {
    return index.clamp(0, 5);
  }

  int gridColumnsForLayoutIndex(int index) {
    final normalized = normalizeLayoutIndex(index);
    if (normalized == 0) return 3;
    return normalized + 2;
  }

  void sortBooks(int sortIndex) {
    sortBookList(books, sortIndex);
  }

  void sortBookList(List<Book> books, int sortIndex) {
    int compareDateTimeDesc(DateTime? a, DateTime? b) {
      final aTime = a ?? DateTime(2000);
      final bTime = b ?? DateTime(2000);
      return bTime.compareTo(aTime);
    }

    final normalized = normalizeSortIndex(sortIndex);
    if (normalized == 3) {
      // legado“手动排序”在当前阶段无独立 order 字段，保持数据库原顺序。
      return;
    }

    books.sort((a, b) {
      switch (normalized) {
        case 0:
          return compareDateTimeDesc(
            a.lastReadTime ?? a.addedTime,
            b.lastReadTime ?? b.addedTime,
          );
        case 1:
          return compareDateTimeDesc(a.addedTime, b.addedTime);
        case 2:
          return a.title.compareTo(b.title);
        case 4:
          return compareDateTimeDesc(
            maxDateTime(a.lastReadTime, a.addedTime),
            maxDateTime(b.lastReadTime, b.addedTime),
          );
        case 5:
          return a.author.compareTo(b.author);
        default:
          return 0;
      }
    });
  }

  DateTime? maxDateTime(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
