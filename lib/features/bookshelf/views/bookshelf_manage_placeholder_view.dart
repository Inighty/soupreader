import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../source/services/source_import_export_service.dart';
import '../services/bookshelf_manage_export_service.dart';

/// 书架管理承载页（对应 legado: menu_bookshelf_manage -> BookshelfManageActivity）。
///
/// 当前已收敛：
/// - `menu_export_all_use_book_source`（导出所有书的书源）
///
/// 其余 `bookshelf_manage.xml / bookshelf_menage_sel.xml` 动作按后续序号推进。
class BookshelfManagePlaceholderView extends StatefulWidget {
  const BookshelfManagePlaceholderView({super.key});

  @override
  State<BookshelfManagePlaceholderView> createState() =>
      _BookshelfManagePlaceholderViewState();
}

class _BookshelfManagePlaceholderViewState
    extends State<BookshelfManagePlaceholderView> {
  late final BookRepository _bookRepository;
  late final SourceRepository _sourceRepository;
  late final SourceImportExportService _sourceImportExportService;
  late final BookshelfManageExportService _exportService;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _bookRepository = BookRepository(db);
    _sourceRepository = SourceRepository(db);
    _sourceImportExportService = SourceImportExportService();
    _exportService = BookshelfManageExportService(
      bookRepository: _bookRepository,
      sourceRepository: _sourceRepository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '书架管理',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(28, 28),
        onPressed: _isExporting ? null : _showMoreMenu,
        child: _isExporting
            ? const CupertinoActivityIndicator(radius: 8)
            : const Icon(CupertinoIcons.ellipsis_circle, size: 22),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: const [
          _PlaceholderCard(
            title: '书架管理（迁移中）',
            message: '已按 legado 迁移“书架管理”入口与页面导航。'
                '当前已完成“导出所有书的书源”；批量删除、允许更新、批量换源等动作将按后续序号逐项迁移。',
          ),
          SizedBox(height: 12),
          _InfoCard(
            label: '当前状态',
            value: '已同义：导出所有书的书源；其余书架管理动作待后续序号收敛',
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                unawaited(_exportAllUsedBookSources());
              },
              child: const Text('导出所有书的书源'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _exportAllUsedBookSources() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });
    try {
      final sources = _exportService.collectAllUsedBookSources();
      final result = await _sourceImportExportService.exportToFile(
        sources,
        defaultFileName: 'bookSource.json',
      );
      if (!mounted) return;
      if (result.cancelled) return;
      if (!result.success) {
        _showMessage(result.errorMessage ?? '导出失败');
        return;
      }
      final outputPath = (result.outputPath ?? '').trim();
      if (outputPath.isEmpty) {
        _showMessage('导出成功');
        return;
      }
      await _showExportPathDialog(outputPath);
    } catch (error, stackTrace) {
      debugPrint('BookshelfManageExportAllUseBookSourceError: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showMessage('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
    if (path.isEmpty) {
      _showMessage('导出成功');
      return;
    }
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('导出成功'),
          content: Text('\n导出路径：\n$path'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _showMessage('已复制导出路径');
              },
              child: const Text('复制路径'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('提示'),
          content: Text('\n$message'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好'),
            ),
          ],
        );
      },
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
