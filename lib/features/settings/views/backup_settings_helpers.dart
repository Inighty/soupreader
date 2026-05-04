import '../../../core/services/webdav_service.dart';

String briefBackupValue(String value, {String fallback = '未设置'}) {
  final text = value.trim();
  if (text.isEmpty) return fallback;
  if (text.length <= 22) return text;
  return '${text.substring(0, 22)}…';
}

String maskBackupSecret(String value) {
  final text = value.trim();
  if (text.isEmpty) return '未设置';
  return '已设置（${text.length} 位）';
}

String formatBackupFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatBackupDateTime(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

String backupEntrySummary(WebDavRemoteEntry entry) {
  final size = formatBackupFileSize(entry.size);
  final time = entry.lastModify > 0
      ? formatBackupDateTime(entry.lastModify)
      : '时间未知';
  return '$time · $size';
}

String normalizeBackupErrorMessage(Object error) {
  final raw = error.toString().trim();
  if (raw.isEmpty) return '未知错误';
  const prefixes = <String>[
    'Exception:',
    'WebDavOperationException:',
  ];
  for (final prefix in prefixes) {
    if (raw.startsWith(prefix)) {
      final message = raw.substring(prefix.length).trim();
      if (message.isNotEmpty) return message;
    }
  }
  return raw;
}
