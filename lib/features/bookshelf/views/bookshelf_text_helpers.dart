// ignore_for_file: invalid_use_of_protected_member

import '../models/book.dart';
import 'bookshelf_book_status_helpers.dart';
import 'bookshelf_view.dart';

extension BookshelfTextHelpers on BookshelfViewState {
  String buildReadLine(Book book) {
    final total = book.totalChapters;
    if (total <= 0) {
      return book.isReading ? '阅读进度 ${book.progressText}' : '未开始阅读';
    }
    final current = (book.currentChapter + 1).clamp(1, total);
    if (!book.isReading) {
      return '未开始阅读 · 共 $total 章';
    }
    final unreadCount = settingsService.appSettings.bookshelfShowUnread
        ? unreadCountLikeLegado(book)
        : 0;
    if (unreadCount <= 0) {
      return '阅读：$current/$total 章';
    }
    return '阅读：$current/$total 章 · 未读 $unreadCount';
  }

  String buildLatestLine(Book book) {
    final latest = (book.latestChapter ?? '').trim();
    if (latest.isNotEmpty) {
      return '最新：$latest';
    }
    if (book.isLocal) {
      return '本地书籍';
    }
    return '暂无最新章节';
  }

  String? formatReadAgo(DateTime? value) {
    if (value == null) return null;
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}
