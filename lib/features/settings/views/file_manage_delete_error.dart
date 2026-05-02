import 'dart:io';

/// 删除文件/目录失败的归因。
enum FileDeleteFailureType {
  directoryNotEmpty,
  permissionDenied,
  targetNotFound,
  otherIo,
}

const int _osErrorOperationNotPermitted = 1;
const int _osErrorNotFound = 2;
const int _osErrorPathNotFound = 3;
const int _osErrorAccessDenied = 5;
const int _osErrorPermissionDenied = 13;
const int _osErrorDirectoryNotEmpty = 39;
const int _osErrorDirectoryNotEmptyWin = 145;

/// 根据错误码与消息推断删除失败类型。
FileDeleteFailureType resolveFileDeleteFailureType(FileSystemException error) {
  final osCode = error.osError?.errorCode;
  final mergedMessage =
      '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();

  if (osCode == _osErrorDirectoryNotEmpty ||
      osCode == _osErrorDirectoryNotEmptyWin ||
      mergedMessage.contains('directory not empty') ||
      mergedMessage.contains('not empty') ||
      mergedMessage.contains('目录非空')) {
    return FileDeleteFailureType.directoryNotEmpty;
  }
  if (osCode == _osErrorPermissionDenied ||
      osCode == _osErrorOperationNotPermitted ||
      osCode == _osErrorAccessDenied ||
      mergedMessage.contains('permission denied') ||
      mergedMessage.contains('operation not permitted') ||
      mergedMessage.contains('access is denied') ||
      mergedMessage.contains('权限')) {
    return FileDeleteFailureType.permissionDenied;
  }
  if (osCode == _osErrorNotFound ||
      osCode == _osErrorPathNotFound ||
      mergedMessage.contains('no such file') ||
      mergedMessage.contains('cannot find the file') ||
      mergedMessage.contains('not found') ||
      mergedMessage.contains('不存在')) {
    return FileDeleteFailureType.targetNotFound;
  }
  return FileDeleteFailureType.otherIo;
}

/// 整理 OS 错误码 / 系统消息 / 异常 message 的可读描述。
String buildFileDeleteErrorDetail(FileSystemException error) {
  final osError = error.osError;
  final errorCode = osError?.errorCode;
  final osMessage = osError?.message.trim() ?? '';
  final message = error.message.trim();
  final details = <String>[
    if (errorCode != null) '错误码：$errorCode',
    if (osMessage.isNotEmpty) osMessage,
    if (message.isNotEmpty && message != osMessage) message,
  ];
  return details.join(' | ');
}

/// 把失败类型 + 目标名 + 详情拼成给用户看的提示。
String buildFileDeleteFailureMessage({
  required FileDeleteFailureType type,
  required String displayName,
  String? detail,
}) {
  final baseMessage = switch (type) {
    FileDeleteFailureType.directoryNotEmpty => '删除失败（目录非空）：请先清空目录后再删除',
    FileDeleteFailureType.permissionDenied => '删除失败（权限不足）：当前没有权限删除该项目',
    FileDeleteFailureType.targetNotFound => '删除失败（目标不存在）：文件或目录已不存在',
    FileDeleteFailureType.otherIo => '删除失败（IO 异常）：请稍后重试',
  };
  final hasDetail = detail != null && detail.trim().isNotEmpty;
  return hasDetail
      ? '$baseMessage\n目标：$displayName\n错误详情：${detail.trim()}'
      : '$baseMessage\n目标：$displayName';
}
