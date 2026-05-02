import 'dart:io';

/// 文件管理列表项：可能是真实条目或返回上级（父目录）入口。
class FileManageListEntry {
  final FileSystemEntity entity;
  final bool isParentEntry;

  const FileManageListEntry._({
    required this.entity,
    required this.isParentEntry,
  });

  factory FileManageListEntry.entity(FileSystemEntity entity) {
    return FileManageListEntry._(entity: entity, isParentEntry: false);
  }

  factory FileManageListEntry.parent(Directory current) {
    return FileManageListEntry._(entity: current, isParentEntry: true);
  }
}

/// 比较函数：目录在前，文件在后；同类按名称（大小写不敏感）排序。
int compareFileEntity(FileSystemEntity a, FileSystemEntity b) {
  final aIsFile = a is File;
  final bIsFile = b is File;
  if (aIsFile != bIsFile) {
    return aIsFile ? 1 : -1;
  }
  final aName = entityBaseName(a).toLowerCase();
  final bName = entityBaseName(b).toLowerCase();
  return aName.compareTo(bName);
}

/// 取条目最后一段名（兼容 / 与 \\）。
String entityBaseName(FileSystemEntity entity) {
  final normalized = entity.path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  if (index < 0 || index + 1 >= normalized.length) return normalized;
  return normalized.substring(index + 1);
}

/// 取展示名（剥空白；空则回退到完整路径）。
String entityDisplayName(FileSystemEntity entity) {
  final name = entityBaseName(entity).trim();
  return name.isEmpty ? entity.path : name;
}

String joinFilePath(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) {
    return '$parent$child';
  }
  return '$parent${Platform.pathSeparator}$child';
}

String normalizeFilePath(String path) {
  var normalized = path.replaceAll('\\', '/');
  while (normalized.endsWith('/') && normalized.length > 1) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

bool isChildPath({required String parentPath, required String childPath}) {
  final parent = normalizeFilePath(parentPath);
  final child = normalizeFilePath(childPath);
  if (child == parent) return false;
  if (parent == '/') {
    return child.startsWith('/') && child.length > 1;
  }
  return child.startsWith('$parent/');
}

/// 校验文件夹名合法性，非法返回错误提示，合法返回 null。
String? validateFolderName(String name) {
  if (name == '.' || name == '..') return '文件夹名非法';
  if (name.contains('/') || name.contains('\\')) return '文件夹名非法';
  if (RegExp(r'[\x00-\x1F]').hasMatch(name)) return '文件夹名非法';
  if (RegExp(r'[:*?"<>|]').hasMatch(name)) return '文件夹名非法';
  return null;
}

/// 格式化字节数为可读字符串。
String formatFileBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = -1;
  while (value >= 1024 && unitIndex + 1 < units.length) {
    value /= 1024;
    unitIndex++;
  }
  if (unitIndex < 0) return '${bytes}B';
  final fixed =
      value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$fixed${units[unitIndex]}';
}
