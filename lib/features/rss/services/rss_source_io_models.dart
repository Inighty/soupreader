import '../models/rss_source.dart';

/// RSS 订阅源导出到文件的结果。
class RssSourceExportFileResult {
  const RssSourceExportFileResult({
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

/// RSS 订阅源导入的结果（兼容 cancelled 与 warnings 多种状态）。
class RssSourceImportResult {
  const RssSourceImportResult({
    this.success = false,
    this.cancelled = false,
    this.errorMessage,
    this.sources = const <RssSource>[],
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
  final List<RssSource> sources;
  final int importCount;
  final int totalInputCount;
  final int invalidCount;
  final int duplicateCount;
  final List<String> warnings;
  final Map<String, String> sourceRawJsonByUrl;

  bool get hasWarnings => warnings.isNotEmpty;

  String? rawJsonForSourceUrl(String url) {
    final key = url.trim();
    if (key.isEmpty) return null;
    return sourceRawJsonByUrl[key];
  }

  RssSourceImportResult copyWithMergedWarnings(List<String> extraWarnings) {
    if (extraWarnings.isEmpty) return this;
    final merged = <String>[
      ...warnings,
      ...extraWarnings.where((item) => item.trim().isNotEmpty),
    ];
    return RssSourceImportResult(
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
