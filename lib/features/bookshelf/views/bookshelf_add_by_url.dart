// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfAddByUrl on BookshelfViewState {
  Future<void> addBooksByUrl(String rawInput) async {
    if (isImporting || isUpdatingCatalog || isAddingByUrl) return;

    final urls = rawInput
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) return;

    if (!mounted) return;
    setState(() => isAddingByUrl = true);
    cancelAddByUrlRequested = false;

    final progress = ValueNotifier<int>(0);
    var progressDialogClosed = false;
    Future<void>? progressDialogFuture;
    if (mounted) {
      progressDialogFuture = showCupertinoBottomSheetDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, count, __) {
              return CupertinoAlertDialog(
                title: Text('添加中... ($count)'),
                content: const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: CupertinoActivityIndicator(),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () {
                      cancelAddByUrlRequested = true;
                      progressDialogClosed = true;
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('取消'),
                  ),
                ],
              );
            },
          );
        },
      ).then((_) {
        progressDialogClosed = true;
      });
    }

    var successCount = 0;
    final existingBookUrls = bookRepo
        .getAllBooks()
        .map((book) => (book.bookUrl ?? '').trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    final enabledSources = sourceRepo
        .getAllSources()
        .where((source) => source.enabled)
        .toList(growable: false);

    try {
      for (final bookUrl in urls) {
        if (cancelAddByUrlRequested) break;

        if (existingBookUrls.contains(bookUrl)) {
          successCount++;
          progress.value = successCount;
          continue;
        }

        final source = resolveSourceForBookUrl(bookUrl, enabledSources);
        if (source == null) continue;

        final result = await bookAddService.addFromSearchResult(
          SearchResult(
            name: '',
            author: '',
            coverUrl: '',
            intro: '',
            lastChapter: '',
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          ),
        );
        if (result.success || result.alreadyExists) {
          successCount++;
          progress.value = successCount;
          existingBookUrls.add(bookUrl);
        }
      }
    } finally {
      if (mounted && !progressDialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (progressDialogFuture != null) {
        await progressDialogFuture;
      }
      progress.dispose();
      if (mounted) {
        setState(() => isAddingByUrl = false);
      }
    }

    if (!mounted) return;
    if (cancelAddByUrlRequested) {
      loadBooks();
      return;
    }
    if (successCount > 0) {
      loadBooks();
      showMessage('成功');
    } else {
      showMessage('添加网址失败');
    }
  }

  // --- from bookshelf_view_manage.dart ---
  Future<void> showAddBookByUrlDialog() async {
    final controller = TextEditingController();
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('添加书籍网址'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'url',
              autofocus: true,
              maxLines: 4,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final input = controller.text;
                Navigator.pop(dialogContext);
                unawaited(addBooksByUrl(input));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  String? extractBaseUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    final portSegment = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$portSegment';
  }

  BookSource? resolveSourceForBookUrl(
    String bookUrl,
    List<BookSource> enabledSources,
  ) {
    final baseUrl = extractBaseUrl(bookUrl);
    if (baseUrl == null) return null;

    final exactSource = sourceRepo.getSourceByUrl(baseUrl);
    if (exactSource != null && exactSource.enabled) {
      return exactSource;
    }

    for (final source in enabledSources) {
      final rawPattern = (source.bookUrlPattern ?? '').trim();
      if (rawPattern.isEmpty || rawPattern.toUpperCase() == 'NONE') {
        continue;
      }
      try {
        if (RegExp(rawPattern).hasMatch(bookUrl)) {
          return source;
        }
      } catch (_) {
        // 与 legado 一致：单个异常规则不中断整体匹配流程。
      }
    }
    return null;
  }
}
