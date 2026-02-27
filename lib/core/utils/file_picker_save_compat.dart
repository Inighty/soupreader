import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 统一封装 `FilePicker.saveFile` 的跨平台行为。
///
/// Android/iOS 需要显式提供 bytes；桌面端仍以路径写入为主。
/// 这里统一传入 bytes，并在可写本地路径上做兜底写入，保证各端行为一致。
Future<String?> saveFileWithBytesCompat({
  required String dialogTitle,
  required String fileName,
  required List<String> allowedExtensions,
  required Uint8List bytes,
  FileType type = FileType.custom,
}) async {
  final outputPath = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    allowedExtensions: allowedExtensions,
    type: type,
    bytes: bytes,
  );
  if (outputPath == null || outputPath.trim().isEmpty) {
    return null;
  }
  final normalizedPath = outputPath.trim();
  await writeBytesToLocalPathIfNeeded(
    outputPath: normalizedPath,
    bytes: bytes,
  );
  return normalizedPath;
}

Future<String?> saveFileWithTextCompat({
  required String dialogTitle,
  required String fileName,
  required List<String> allowedExtensions,
  required String text,
  Encoding encoding = utf8,
  FileType type = FileType.custom,
}) {
  final bytes = Uint8List.fromList(encoding.encode(text));
  return saveFileWithBytesCompat(
    dialogTitle: dialogTitle,
    fileName: fileName,
    allowedExtensions: allowedExtensions,
    bytes: bytes,
    type: type,
  );
}

Future<void> writeBytesToLocalPathIfNeeded({
  required String outputPath,
  required List<int> bytes,
}) async {
  final normalized = outputPath.trim();
  if (normalized.isEmpty) return;
  final isWindowsDrivePath = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(normalized);
  final payload = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  if (isWindowsDrivePath) {
    try {
      await File(normalized).writeAsBytes(payload, flush: true);
    } catch (_) {
      // 忽略本地兜底写入失败，避免覆盖插件已完成写入的成功结果。
    }
    return;
  }
  final uri = Uri.tryParse(normalized);
  final scheme = uri?.scheme.toLowerCase();

  // content:// 等非本地文件路径由插件侧写入，Dart File 无法直接写。
  if (scheme != null && scheme.isNotEmpty && scheme != 'file') {
    return;
  }

  final file = scheme == 'file' ? File.fromUri(uri!) : File(normalized);
  try {
    await file.writeAsBytes(payload, flush: true);
  } catch (_) {
    // 忽略本地兜底写入失败，避免覆盖插件已完成写入的成功结果。
  }
}
