// ignore_for_file: invalid_use_of_protected_member

import 'dart:math' as math;

import '../models/book.dart';
import 'bookshelf_view.dart';

extension BookshelfBookStatusHelpers on BookshelfViewState {
  int unreadCountLikeLegado(Book book) {
    final total = book.totalChapters;
    if (total <= 0) return 0;
    final current = book.currentChapter.clamp(0, total - 1);
    return math.max(total - current - 1, 0);
  }

  bool isUpdating(Book book) {
    if (book.isLocal) return false;
    return updatingBookIds.contains(book.id);
  }
}
