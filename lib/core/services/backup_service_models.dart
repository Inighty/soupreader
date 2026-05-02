class BackupExportResult {
  final bool success;
  final bool cancelled;
  final String? filePath;
  final String? fileName;
  final String? errorMessage;

  const BackupExportResult({
    this.success = false,
    this.cancelled = false,
    this.filePath,
    this.fileName,
    this.errorMessage,
  });
}

class BackupUploadPayload {
  final String fileName;
  final List<int> bytes;

  const BackupUploadPayload({
    required this.fileName,
    required this.bytes,
  });
}

class BackupImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final int sourcesImported;
  final int booksImported;
  final int chaptersImported;
  final int ignoredLocalBooks;
  final List<String> ignoredOptions;

  const BackupImportResult({
    this.success = false,
    this.cancelled = false,
    this.errorMessage,
    this.sourcesImported = 0,
    this.booksImported = 0,
    this.chaptersImported = 0,
    this.ignoredLocalBooks = 0,
    this.ignoredOptions = const <String>[],
  });
}

class LegacyImportResult {
  final bool success;
  final String? errorMessage;
  final int booksImported;
  final int sourcesImported;
  final int replaceRulesImported;

  const LegacyImportResult({
    this.success = false,
    this.errorMessage,
    this.booksImported = 0,
    this.sourcesImported = 0,
    this.replaceRulesImported = 0,
  });
}
