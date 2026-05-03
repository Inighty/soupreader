import '../../core/models/book.dart';

class ImportDirectorySelectionResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final String? directoryPath;

  ImportDirectorySelectionResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.directoryPath,
  });

  factory ImportDirectorySelectionResult.success({
    required String directoryPath,
  }) {
    return ImportDirectorySelectionResult._(
      success: true,
      directoryPath: directoryPath,
    );
  }

  factory ImportDirectorySelectionResult.cancelled() {
    return ImportDirectorySelectionResult._(success: false, cancelled: true);
  }

  factory ImportDirectorySelectionResult.error(String message) {
    return ImportDirectorySelectionResult._(
      success: false,
      errorMessage: message,
    );
  }
}

class ImportDirectoryCreateResult {
  final bool success;
  final String? errorMessage;
  final String? directoryPath;

  ImportDirectoryCreateResult._({
    required this.success,
    this.errorMessage,
    this.directoryPath,
  });

  factory ImportDirectoryCreateResult.success({
    required String directoryPath,
  }) {
    return ImportDirectoryCreateResult._(
      success: true,
      directoryPath: directoryPath,
    );
  }

  factory ImportDirectoryCreateResult.error(String message) {
    return ImportDirectoryCreateResult._(
      success: false,
      errorMessage: message,
    );
  }
}

class ImportScanCandidate {
  final String filePath;
  final String fileName;
  final int sizeInBytes;
  final DateTime modifiedAt;

  const ImportScanCandidate({
    required this.filePath,
    required this.fileName,
    required this.sizeInBytes,
    required this.modifiedAt,
  });
}

class ImportScanResult {
  final bool success;
  final String? errorMessage;
  final String? rootDirectoryPath;
  final List<ImportScanCandidate> candidates;

  const ImportScanResult._({
    required this.success,
    this.errorMessage,
    this.rootDirectoryPath,
    this.candidates = const <ImportScanCandidate>[],
  });

  factory ImportScanResult.success({
    required String rootDirectoryPath,
    required List<ImportScanCandidate> candidates,
  }) {
    return ImportScanResult._(
      success: true,
      rootDirectoryPath: rootDirectoryPath,
      candidates: candidates,
    );
  }

  factory ImportScanResult.error(String message) {
    return ImportScanResult._(
      success: false,
      errorMessage: message,
    );
  }
}

class BatchImportFailure {
  final String filePath;
  final String errorMessage;

  const BatchImportFailure({
    required this.filePath,
    required this.errorMessage,
  });
}

class BatchImportResult {
  final int totalCount;
  final int successCount;
  final List<Book> importedBooks;
  final List<BatchImportFailure> failures;

  const BatchImportResult({
    required this.totalCount,
    required this.successCount,
    required this.importedBooks,
    required this.failures,
  });

  int get failedCount => failures.length;
}

class BatchDeleteFailure {
  final String filePath;
  final String errorMessage;

  const BatchDeleteFailure({
    required this.filePath,
    required this.errorMessage,
  });
}

class BatchDeleteResult {
  final int totalCount;
  final int deletedCount;
  final List<BatchDeleteFailure> failures;

  const BatchDeleteResult({
    required this.totalCount,
    required this.deletedCount,
    required this.failures,
  });

  int get failedCount => failures.length;
}

class ImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final Book? book;
  final int chapterCount;

  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.book,
    this.chapterCount = 0,
  });

  factory ImportResult.success({
    required Book book,
    required int chapterCount,
  }) {
    return ImportResult._(
      success: true,
      book: book,
      chapterCount: chapterCount,
    );
  }

  factory ImportResult.cancelled() {
    return ImportResult._(success: false, cancelled: true);
  }

  factory ImportResult.error(String message) {
    return ImportResult._(success: false, errorMessage: message);
  }
}
