import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/entities/bookmark_entity.dart';
import '../../../core/database/repositories/bookmark_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../services/reader_bookmark_export_service.dart';

/// 所有书签（对齐 legado `AllBookmarkActivity`）
class AllBookmarkView extends StatefulWidget {
  const AllBookmarkView({super.key});

  @override
  State<AllBookmarkView> createState() => _AllBookmarkViewState();
}

class _AllBookmarkViewState extends State<AllBookmarkView> {
  final BookmarkRepository _bookmarkRepo = BookmarkRepository();
  final ReaderBookmarkExportService _bookmarkExportService =
      ReaderBookmarkExportService();

  List<BookmarkEntity> _bookmarks = <BookmarkEntity>[];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBookmarks());
  }

  Future<void> _loadBookmarks() async {
    try {
      await _bookmarkRepo.init();
      final list = _bookmarkRepo.getAllBookmarksByLegacyOrder();
      if (!mounted) return;
      setState(() {
        _bookmarks = list;
        _loading = false;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'all_bookmark.init',
        message: '所有书签初始化失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _showToast('加载书签失败：$error');
    }
  }

  Future<void> _runExport({required bool markdown}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bookmarks = _bookmarkRepo.getAllBookmarksByLegacyOrder();
      final result = markdown
          ? await _bookmarkExportService.exportAllMarkdown(
              bookmarks: bookmarks,
            )
          : await _bookmarkExportService.exportAllJson(
              bookmarks: bookmarks,
            );
      if (!mounted) return;
      if (result.cancelled) {
        return;
      }
      if (!result.success) {
        ExceptionLogService().record(
          node: markdown
              ? 'all_bookmark.menu_export_md'
              : 'all_bookmark.menu_export',
          message: result.message ?? '导出失败',
          context: <String, dynamic>{
            'bookmarkCount': bookmarks.length,
            'format': markdown ? 'md' : 'json',
          },
        );
      }
      final message = result.success
          ? (result.message?.trim().isNotEmpty == true
              ? result.message!
              : '导出成功')
          : (result.message?.trim().isNotEmpty == true
              ? result.message!
              : '导出失败');
      _showToast(message);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: markdown
            ? 'all_bookmark.menu_export_md'
            : 'all_bookmark.menu_export',
        message: '导出失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'format': markdown ? 'md' : 'json',
        },
      );
      if (!mounted) return;
      _showToast('导出失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _exporting = false);
    }
  }

  void _showTopActions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              unawaited(_runExport(markdown: false));
            },
            child: Text(_exporting ? '导出中...' : '导出'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              unawaited(_runExport(markdown: true));
            },
            child: Text(_exporting ? '导出中...' : '导出(MD)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1000), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.6,
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '所有书签',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 28,
        onPressed: _showTopActions,
        child: _exporting
            ? const CupertinoActivityIndicator(radius: 10)
            : const Icon(CupertinoIcons.ellipsis_circle, size: 22),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 13),
      );
    }
    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.bookmark,
              size: 64,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(height: 14),
            Text(
              '暂无书签',
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        final chapter = bookmark.chapterTitle.trim().isEmpty
            ? '第 ${bookmark.chapterIndex + 1} 章'
            : bookmark.chapterTitle.trim();
        final excerpt =
            bookmark.content.trim().isEmpty ? '（无）' : bookmark.content.trim();
        return CupertinoListTile.notched(
          title: Text(chapter),
          subtitle: Text(
            '${bookmark.bookName} · ${bookmark.bookAuthor}\n$excerpt',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          additionalInfo: Text(_formatTime(bookmark.createdTime)),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
