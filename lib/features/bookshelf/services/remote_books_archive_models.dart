/// 压缩包内部可导入候选条目。
class RemoteBooksArchiveCandidate {
  final String fileName;
  final int sizeInBytes;
  final String extension;

  const RemoteBooksArchiveCandidate({
    required this.fileName,
    required this.sizeInBytes,
    required this.extension,
  });
}

/// 下载 + 解析压缩包后的结果（用于 UI 决策：提示/选择/继续导入）。
class RemoteBooksArchiveOpenResult {
  final bool success;
  final bool fromCache;
  final String? localArchivePath;
  final List<RemoteBooksArchiveCandidate> candidates;
  final String? warning;
  final String? errorMessage;

  const RemoteBooksArchiveOpenResult({
    required this.success,
    required this.fromCache,
    required this.localArchivePath,
    required this.candidates,
    this.warning,
    this.errorMessage,
  });

  factory RemoteBooksArchiveOpenResult.ok({
    required bool fromCache,
    required String localArchivePath,
    required List<RemoteBooksArchiveCandidate> candidates,
    String? warning,
  }) {
    return RemoteBooksArchiveOpenResult(
      success: true,
      fromCache: fromCache,
      localArchivePath: localArchivePath,
      candidates: candidates,
      warning: warning,
    );
  }

  factory RemoteBooksArchiveOpenResult.error(String message) {
    return RemoteBooksArchiveOpenResult(
      success: false,
      fromCache: false,
      localArchivePath: null,
      candidates: const <RemoteBooksArchiveCandidate>[],
      errorMessage: message,
    );
  }
}
