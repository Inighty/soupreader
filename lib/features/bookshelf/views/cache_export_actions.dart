import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/services/exception_log_service.dart';
import '../services/cache_export_task_service.dart';
import 'cache_export_dialogs.dart';

/// 处理「导出文件夹」按钮：选目录并保存到设置。
Future<void> handleCacheExportFolderTap(
  CacheExportTaskService exportService,
) async {
  final saved = exportService.getSavedExportDirectory();
  final selected = await FilePicker.platform.getDirectoryPath(
    dialogTitle: '选择导出文件夹',
    initialDirectory: saved,
  );
  final normalized = selected?.trim() ?? '';
  if (normalized.isEmpty) return;
  try {
    await exportService.saveExportDirectory(normalized);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'bookshelf.cache.export_folder.save_failed',
      message: '保存导出目录失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{'directoryPath': normalized},
    );
  }
}

/// 处理「导出文件名」按钮：弹窗编辑并保存。
Future<void> handleCacheExportFileNameTap({
  required BuildContext context,
  required CacheExportTaskService exportService,
}) async {
  final result = await showCacheExportFileNameDialog(
    context: context,
    initialValue: exportService.getBookExportFileName() ?? '',
  );
  if (result == null) return;
  try {
    await exportService.saveBookExportFileName(result);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'bookshelf.cache.export_file_name.save_failed',
      message: '保存导出文件名规则失败',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// 处理「导出编码」按钮：弹窗编辑并保存；返回成功后的最新值。
///
/// 调用方拿到返回值后通常会 setState 更新缓存的 charset。
Future<String?> handleCacheExportCharsetTap({
  required BuildContext context,
  required CacheExportTaskService exportService,
}) async {
  final result = await showCacheExportCharsetDialog(
    context: context,
    initialValue: exportService.getExportCharset(),
    legacyOptions: CacheExportTaskService.legacyExportCharsetOptions,
  );
  if (result == null) return null;
  try {
    await exportService.saveExportCharset(result);
    return exportService.getExportCharset();
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'bookshelf.cache.export_charset.save_failed',
      message: '保存导出编码失败',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// 解析「导出目录」：优先使用已保存目录；不可写时弹出选择器。
Future<String?> resolveCacheExportDirectory(
  CacheExportTaskService exportService,
) async {
  final saved = exportService.getSavedExportDirectory();
  if (saved != null && await exportService.isWritableDirectory(saved)) {
    return saved;
  }

  final selected = await FilePicker.platform.getDirectoryPath(
    dialogTitle: '选择导出文件夹',
    initialDirectory: saved,
  );
  final normalized = selected?.trim() ?? '';
  if (normalized.isEmpty) return null;
  if (!await exportService.isWritableDirectory(normalized)) return null;
  await exportService.saveExportDirectory(normalized);
  return normalized;
}
