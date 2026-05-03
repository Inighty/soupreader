import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/services/exception_log_service.dart';

/// 关于页用到的「日志 / 堆转储」导出辅助。
///
/// 写入路径以 [backupPath] 为根，子目录分别为 `logs` / `heapDump`。
/// 文件名采用 `soupreader_*_<时间戳>.json` 格式。
class AboutLogExporter {
  AboutLogExporter({
    required this.backupPath,
    required this.appName,
    required this.packageName,
    required this.version,
    required this.exceptionLogService,
  });

  final String backupPath;
  final String appName;
  final String packageName;
  final String version;
  final ExceptionLogService exceptionLogService;

  Future<String> writeLogs() async {
    final logsDir = await _ensureSubDir('logs');
    final fileName = 'soupreader_logs_${_fileTimestamp()}.json';
    final file = File(p.join(logsDir.path, fileName));

    final payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'appName': appName,
      'packageName': packageName,
      'version': version,
      'entries': exceptionLogService.entries
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };

    final content = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  Future<String> writeHeapDump() async {
    final dumpDir = await _ensureSubDir('heapDump');
    final fileName = 'soupreader_heap_dump_${_fileTimestamp()}.json';
    final file = File(p.join(dumpDir.path, fileName));

    final payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'note': 'Flutter 暂不支持原生 HPROF，本文件为运行时堆快照信息。',
      'currentRssBytes': ProcessInfo.currentRss,
      'maxRssBytes': ProcessInfo.maxRss,
      'logCount': exceptionLogService.count,
      'recentLogNodes': exceptionLogService.entries
          .take(20)
          .map((entry) => entry.node)
          .toList(growable: false),
    };

    final content = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  Future<Directory> _ensureSubDir(String name) async {
    final root = Directory(backupPath);
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    final sub = Directory(p.join(root.path, name));
    if (!await sub.exists()) {
      await sub.create(recursive: true);
    }
    return sub;
  }

  static String _fileTimestamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}'
        '${three(now.millisecond)}';
  }
}
