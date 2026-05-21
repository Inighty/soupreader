// ignore_for_file: invalid_use_of_protected_member

import '../services/bookshelf_catalog_update_service.dart';
import 'bookshelf_display_engine.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfCatalogActions on BookshelfViewState {
  String buildCatalogUpdateSummaryMessage(
      BookshelfCatalogUpdateSummary summary) {
    final lines = <String>[];
    if (summary.updateCandidateCount <= 0) {
      return '当前书架没有可更新的网络书籍';
    }

    lines.add(
      '目录更新完成：成功 ${summary.successCount} 本，失败 ${summary.failedCount} 本'
      '${summary.skippedCount > 0 ? '，跳过 ${summary.skippedCount} 本' : ''}',
    );
    if (summary.failedDetails.isNotEmpty) {
      lines.add('');
      lines.add('失败详情（最多 5 条）：');
      lines.addAll(summary.failedDetails.take(5));
    }
    return lines.join('\n');
  }

  Future<void> updateBookshelfCatalog() async {
    if (isImporting || isUpdatingCatalog) return;

    final snapshot = displayBooks();
    final remoteCandidates =
        snapshot.where((book) => !book.isLocal).toList(growable: false);
    if (remoteCandidates.isEmpty) {
      showMessage('当前书架没有可更新的网络书籍');
      return;
    }
    final candidates = remoteCandidates
        .where((book) => settingsService.getBookCanUpdate(book.id))
        .toList(growable: false);
    if (candidates.isEmpty) {
      showMessage('当前书架没有可更新的网络书籍（可能已关闭“允许更新”）');
      return;
    }

    if (!mounted) return;
    setState(() {
      isUpdatingCatalog = true;
      updatingBookIds.clear();
    });

    try {
      final summary = await catalogUpdater.updateBooks(
        candidates,
        onBookUpdatingChanged: (bookId, updating) {
          if (!mounted) return;
          setState(() {
            if (updating) {
              updatingBookIds.add(bookId);
            } else {
              updatingBookIds.remove(bookId);
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        isUpdatingCatalog = false;
        updatingBookIds.clear();
      });
      loadBooks();
      showMessage(buildCatalogUpdateSummaryMessage(summary));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isUpdatingCatalog = false;
        updatingBookIds.clear();
      });
      showMessage('更新目录失败：$e');
    }
  }
}
