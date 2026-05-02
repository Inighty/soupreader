/// 远程书籍批量导入失败的单条记录。
class RemoteBooksImportFailure {
  final String fileName;
  final String remoteUrl;
  final String message;

  const RemoteBooksImportFailure({
    required this.fileName,
    required this.remoteUrl,
    required this.message,
  });
}

/// 远程书籍批量导入的总结：总数 / 成功数 / 失败列表。
class RemoteBooksImportSummary {
  final int total;
  final int success;
  final List<RemoteBooksImportFailure> failures;

  const RemoteBooksImportSummary({
    required this.total,
    required this.success,
    required this.failures,
  });

  int get failed => failures.length;

  String get summaryText {
    return '共 $total 本：成功 $success，失败 $failed';
  }
}
