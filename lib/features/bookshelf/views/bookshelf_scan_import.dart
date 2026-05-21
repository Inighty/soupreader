// ignore_for_file: invalid_use_of_protected_member

import 'package:path/path.dart' as p;

import '../../import/import_service.dart';
import 'bookshelf_scan_import_dialogs.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfScanImport on BookshelfViewState {
  Future<void> scanImportFolder() async {
    if (isImporting || isSelectingImportFolder || isScanningImportFolder) {
      return;
    }
    setState(() => isScanningImportFolder = true);

    try {
      final scanResult = await importService.scanImportDirectory();
      if (!mounted) return;
      if (!scanResult.success) {
        if (scanResult.errorMessage != null &&
            scanResult.errorMessage!.isNotEmpty) {
          showMessage('智能扫描失败：${scanResult.errorMessage}');
        }
        return;
      }

      if (scanResult.candidates.isEmpty) {
        showMessage('当前文件夹未扫描到可导入的 TXT/EPUB 文件');
        return;
      }

      final selectedFilePaths =
          await showScanImportSelectionDialog(scanResult: scanResult);
      if (!mounted || selectedFilePaths == null || selectedFilePaths.isEmpty) {
        return;
      }

      setState(() => isImporting = true);
      final summary =
          await importService.importLocalBooksByPaths(selectedFilePaths);
      if (!mounted) return;
      setState(() => isImporting = false);

      loadBooks();
      showMessage(buildScanImportSummaryMessage(summary));
    } finally {
      if (mounted) {
        setState(() {
          isScanningImportFolder = false;
          isImporting = false;
        });
      }
    }
  }

  String buildScanImportSummaryMessage(BatchImportResult summary) {
    if (summary.totalCount <= 0) {
      return '未选择可导入文件';
    }

    final lines = <String>[
      '智能扫描导入完成：成功 ${summary.successCount} 项，失败 ${summary.failedCount} 项',
    ];
    if (summary.failures.isNotEmpty) {
      lines.add('');
      lines.add('失败详情（最多 5 条）：');
      for (final failure in summary.failures.take(5)) {
        lines.add('${p.basename(failure.filePath)}：${failure.errorMessage}');
      }
    }
    return lines.join('\n');
  }
}
