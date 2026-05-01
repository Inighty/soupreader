import 'package:soupreader/features/source/models/book_source.dart';

class SourceExportFileResult {
  const SourceExportFileResult({
    this.success = false,
    this.cancelled = false,
    this.outputPath,
    this.errorMessage,
  });

  final bool success;
  final bool cancelled;
  final String? outputPath;
  final String? errorMessage;
}

/// 导入结果
class SourceImportResult {
  const SourceImportResult({
    this.success = false,
    this.cancelled = false,
    this.errorMessage,
    this.sources = const <BookSource>[],
    this.importCount = 0,
    this.totalInputCount = 0,
    this.invalidCount = 0,
    this.duplicateCount = 0,
    this.warnings = const <String>[],
    this.sourceRawJsonByUrl = const <String, String>{},
  });

  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final List<BookSource> sources;
  final int importCount;
  final int totalInputCount;
  final int invalidCount;
  final int duplicateCount;
  final List<String> warnings;

  /// 导入阶段保留每个书源的原始 JSON（已按 LegadoJson 归一）。
  /// key = bookSourceUrl
  final Map<String, String> sourceRawJsonByUrl;

  bool get hasWarnings => warnings.isNotEmpty;

  String? rawJsonForSourceUrl(String url) {
    final key = url.trim();
    if (key.isEmpty) return null;
    return sourceRawJsonByUrl[key];
  }

  SourceImportResult copyWithMergedWarnings(List<String> extraWarnings) {
    if (extraWarnings.isEmpty) return this;
    final merged = <String>[
      ...warnings,
      ...extraWarnings.where((item) => item.trim().isNotEmpty),
    ];
    return SourceImportResult(
      success: success,
      cancelled: cancelled,
      errorMessage: errorMessage,
      sources: sources,
      importCount: importCount,
      totalInputCount: totalInputCount,
      invalidCount: invalidCount,
      duplicateCount: duplicateCount,
      warnings: merged,
      sourceRawJsonByUrl: sourceRawJsonByUrl,
    );
  }
}
