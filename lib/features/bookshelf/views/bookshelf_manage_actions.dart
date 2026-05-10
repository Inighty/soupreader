import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book_source.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../source/services/source_import/export_service.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
import '../services/bookshelf_manage_batch_change_source_service.dart';
import '../services/bookshelf_manage_export_service.dart';
import 'bookshelf_manage_dialogs.dart';
import 'bookshelf_manage_helpers.dart';
import 'bookshelf_manage_local_files.dart';
import 'bookshelf_manage_widgets.dart';

/// 「分组菜单」选择结果。
class BookshelfManageGroupMenuOutcome {
  const BookshelfManageGroupMenuOutcome({
    this.openGroupManage = false,
    this.selectedGroupId,
  });

  final bool openGroupManage;
  final int? selectedGroupId;
}

/// 弹出分组菜单。返回 [BookshelfManageGroupMenuOutcome]。
Future<BookshelfManageGroupMenuOutcome> showBookshelfManageGroupChooser({
  required BuildContext context,
  required List<BookshelfBookGroup> groups,
  required int currentGroupId,
}) async {
  final options = groups.toList(growable: false)
    ..sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
  final result = await showBookshelfManageGroupMenu(
    context: context,
    groups: options,
    currentGroupId: currentGroupId,
  );
  return BookshelfManageGroupMenuOutcome(
    openGroupManage: result.openGroupManage,
    selectedGroupId: result.selectedGroupId,
  );
}

/// 弹出「分组」多选对话框，返回所选 group bits（0 / null 表示用户取消）。
Future<int?> pickBookshelfManageGroupBits({
  required BuildContext context,
  required List<BookshelfBookGroup> groups,
  required void Function(String message) onMessage,
}) async {
  final selectableGroups =
      groups.where((group) => group.groupId >= 0).toList(growable: false)
        ..sort((a, b) {
          final byOrder = a.order.compareTo(b.order);
          if (byOrder != 0) return byOrder;
          return a.groupId.compareTo(b.groupId);
        });
  if (selectableGroups.isEmpty) {
    onMessage('暂无可选分组，请先在分组管理中添加');
    return null;
  }
  if (!context.mounted) return null;
  return showCupertinoBottomSheetDialog<int>(
    context: context,
    builder: (_) => BookshelfManageGroupSelectDialog(
      groups: selectableGroups,
      initialGroupBits: 0,
    ),
  );
}

/// 「批量清理缓存」结果，供调用方决定是否提示成功 / 错误。
class BookshelfManageClearCacheResult {
  const BookshelfManageClearCacheResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

/// 批量清理已选书籍的下载缓存。
Future<BookshelfManageClearCacheResult> clearBookshelfManageBookCache({
  required ChapterRepository chapterRepository,
  required ExceptionLogService exceptionLogService,
  required List<Book> selectedBooks,
}) async {
  try {
    await chapterRepository.clearDownloadedCacheForBooks(
      selectedBooks.map((book) => book.id),
    );
    return const BookshelfManageClearCacheResult(success: true);
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'bookshelf_manage.menu_clear_cache',
      message: '书架管理批量清理缓存失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'selectedCount': selectedBooks.length,
        'bookIds': selectedBooks.map((book) => book.id).toList(),
      },
    );
    return BookshelfManageClearCacheResult(
      success: false,
      errorMessage:
          '清理缓存出错\n${compactBookshelfManageReason(error.toString())}',
    );
  }
}

/// 批量启用 / 禁用更新。失败时返回错误文案，成功时返回 null。
Future<String?> setBookshelfManageCanUpdate({
  required SettingsService settingsService,
  required ExceptionLogService exceptionLogService,
  required List<Book> selectedBooks,
  required bool canUpdate,
  required String node,
  required String actionLabel,
}) async {
  try {
    await settingsService.saveBooksCanUpdate(
      selectedBooks.map((book) => book.id),
      canUpdate,
    );
    return null;
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: node,
      message: '书架管理${actionLabel}批量设置失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'selectedCount': selectedBooks.length,
        'bookIds': selectedBooks.map((book) => book.id).toList(),
        'canUpdate': canUpdate,
      },
    );
    return '$actionLabel出错\n${compactBookshelfManageReason(error.toString())}';
  }
}

/// 弹出书源选择页，由用户挑选目标书源。
Future<BookSource?> pickBookshelfManageTargetSource({
  required BuildContext context,
  required SourceRepository sourceRepository,
  required SettingsService settingsService,
  required void Function(String message) onMessage,
}) async {
  final enabledSources = sourceRepository
      .getAllSources()
      .where((source) => source.enabled)
      .toList(growable: false);
  if (enabledSources.isEmpty) {
    onMessage('当前没有可用书源');
    return null;
  }
  enabledSources.sort((a, b) {
    final orderCompare = a.customOrder.compareTo(b.customOrder);
    if (orderCompare != 0) return orderCompare;
    return a.bookSourceName.compareTo(b.bookSourceName);
  });

  if (!context.mounted) return null;
  return Navigator.of(context, rootNavigator: true).push<BookSource>(
    CupertinoPageRoute<BookSource>(
      builder: (_) => BookshelfManageSourcePickerView(
        sources: enabledSources,
        initialDelaySeconds: settingsService.getBatchChangeSourceDelay(),
        onDelayChanged: (seconds) =>
            settingsService.saveBatchChangeSourceDelay(seconds),
      ),
    ),
  );
}

/// 执行批量换源（带进度对话框 + 取消按钮）。
Future<void> executeBookshelfManageBatchChangeSource({
  required BuildContext context,
  required BookshelfManageBatchChangeSourceService service,
  required ExceptionLogService exceptionLogService,
  required List<Book> books,
  required BookSource targetSource,
  required void Function(String message) onMessage,
}) async {
  final progressText = ValueNotifier<String>('批量换源');
  final cancelToken = CancelToken();
  var dialogVisible = true;

  final dialogFuture = showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return ValueListenableBuilder<String>(
        valueListenable: progressText,
        builder: (_, text, __) {
          return CupertinoAlertDialog(
            title: const Text('批量换源'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 8),
                  Text(text),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  if (!cancelToken.isCancelled) {
                    cancelToken.cancel('用户取消批量换源');
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('取消'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() => dialogVisible = false);

  try {
    await service.changeSource(
      books: books,
      targetSource: targetSource,
      cancelToken: cancelToken,
      onProgress: (progress) => progressText.value = progress.progressText,
    );
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'bookshelf_manage.menu_change_source.run',
      message: '批量换源执行失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'selectedCount': books.length,
        'targetSourceUrl': targetSource.bookSourceUrl,
        'targetSourceName': targetSource.bookSourceName,
      },
    );
    onMessage('批量换源失败：$error');
  } finally {
    if (dialogVisible && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
    progressText.dispose();
  }
}

/// 删除选中书籍（包含「删除源文件」分支）。返回成功删除的 bookId 集合。
Future<Set<String>> deleteBookshelfManageSelectedBooks({
  required BookRepository bookRepository,
  required ExceptionLogService exceptionLogService,
  required List<Book> selectedBooks,
  required bool deleteOriginal,
  required void Function(String firstFailureReason) onFailureReport,
}) async {
  final deletedBookIds = <String>{};
  final deleteFailedReasons = <String>[];
  for (final book in selectedBooks) {
    try {
      await bookRepository.deleteBook(book.id);
      deletedBookIds.add(book.id);
      if (book.isLocal) {
        await deleteBookshelfManageLocalBookArtifacts(
          book: book,
          deleteOriginal: deleteOriginal,
          exceptionLogService: exceptionLogService,
        );
      }
    } catch (error, stackTrace) {
      deleteFailedReasons.add(error.toString());
      exceptionLogService.record(
        node: 'bookshelf_manage.menu_del_selection.delete_book',
        message: '书架管理删除所选书籍失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'bookId': book.id,
          'bookTitle': book.title,
          'deleteOriginal': deleteOriginal,
        },
      );
    }
  }
  if (deleteFailedReasons.isNotEmpty) {
    onFailureReport(compactBookshelfManageReason(deleteFailedReasons.first));
  }
  return deletedBookIds;
}

/// 把 [selectedBooks] 加入到 `selectedGroupBits` 表示的分组里，返回新的 membership 表。
Future<Map<String, int>> addBookshelfManageBooksToGroup({
  required DatabaseService database,
  required ExceptionLogService exceptionLogService,
  required Map<String, int> currentMembership,
  required List<Book> selectedBooks,
  required int selectedGroupBits,
  required void Function(String message) onError,
}) async {
  final next = Map<String, int>.from(currentMembership);
  for (final book in selectedBooks) {
    final currentBits = next[book.id] ?? 0;
    next[book.id] = currentBits | selectedGroupBits;
  }
  try {
    await database.putSetting(bookshelfManageGroupMembershipKey, next);
    return next;
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'bookshelf_manage.menu_add_to_group',
      message: '书架管理加入分组失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'selectedCount': selectedBooks.length,
        'bookIds': selectedBooks.map((book) => book.id).toList(),
        'selectedGroupBits': selectedGroupBits,
      },
    );
    onError('加入分组出错\n${compactBookshelfManageReason(error.toString())}');
    return currentMembership;
  }
}

/// 导出全部已被使用的书源到本地文件。
Future<void> exportAllUsedBookshelfManageBookSources({
  required BuildContext context,
  required BookshelfManageExportService exportService,
  required SourceImportExportService sourceImportExportService,
  required void Function(String message) onMessage,
}) async {
  try {
    final sources = exportService.collectAllUsedBookSources();
    final result = await sourceImportExportService.exportToFile(
      sources,
      defaultFileName: 'bookSource.json',
    );
    if (!context.mounted) return;
    if (result.cancelled) return;
    if (!result.success) {
      onMessage(result.errorMessage ?? '导出失败');
      return;
    }
    final outputPath = (result.outputPath ?? '').trim();
    if (outputPath.isEmpty) {
      unawaited(showAppToast(context, message: '导出成功'));
      return;
    }
    await showBookshelfManageExportPathDialog(
      context: context,
      outputPath: outputPath,
      onToast: (msg) =>
          context.mounted ? unawaited(showAppToast(context, message: msg)) : null,
    );
  } catch (error, stackTrace) {
    debugPrint('BookshelfManageExportAllUseBookSourceError: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (!context.mounted) return;
    onMessage('导出失败：$error');
  }
}
