import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/utils/file_picker_save_compat.dart';

class SourceDebugExportService {
  Future<bool> exportTextToFile({
    required String text,
    required String fileName,
    String dialogTitle = '导出文本',
  }) async {
    try {
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: dialogTitle,
        fileName: fileName,
        allowedExtensions: const ['txt', 'log'],
        text: text,
      );

      if (outputPath == null) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> exportJsonToFile({
    required String json,
    required String fileName,
    String dialogTitle = '导出调试包',
  }) async {
    try {
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: dialogTitle,
        fileName: fileName,
        allowedExtensions: const ['json'],
        text: json,
      );

      if (outputPath == null) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> exportZipToFile({
    required Map<String, String> files,
    required String fileName,
    String dialogTitle = '导出调试包',
  }) async {
    try {
      final archive = Archive();
      for (final entry in files.entries) {
        final path = entry.key.trim();
        if (path.isEmpty) continue;
        final data = utf8.encode(entry.value);
        archive.addFile(ArchiveFile(path, data.length, data));
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return false;
      final outputPath = await saveFileWithBytesCompat(
        dialogTitle: dialogTitle,
        fileName: fileName,
        allowedExtensions: const ['zip'],
        bytes: Uint8List.fromList(zipData),
      );
      if (outputPath == null) return false;
      return true;
    } catch (_) {
      return false;
    }
  }
}
