import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_availability/diagnosis_service.dart';

enum SourceCheckStatus {
  pending,
  running,
  ok,
  empty,
  fail,
  skipped,
}

class SourceCheckItem {
  BookSource source;
  SourceCheckStatus status;
  String? message;
  String? requestUrl;
  int elapsedMs;
  int listCount;
  String? debugKey;
  DiagnosisSummary diagnosis;

  SourceCheckItem({
    required this.source,
    this.status = SourceCheckStatus.pending,
    this.message,
    this.requestUrl,
    this.elapsedMs = 0,
    this.listCount = 0,
    this.debugKey,
    this.diagnosis = DiagnosisSummary.noData,
  });
}

class SourceCheckCachedResult {
  const SourceCheckCachedResult({
    required this.status,
    required this.message,
    required this.elapsedMs,
  });

  final SourceCheckStatus status;
  final String? message;
  final int elapsedMs;
}

class SourceCheckTaskConfig {
  const SourceCheckTaskConfig({
    required this.includeDisabled,
    this.sourceUrls,
    this.keywordOverride,
    this.timeoutMs = 180000,
    this.checkSearch = true,
    this.checkDiscovery = true,
    this.checkInfo = true,
    this.checkCategory = true,
    this.checkContent = true,
  });

  final bool includeDisabled;
  final List<String>? sourceUrls;
  final String? keywordOverride;
  final int timeoutMs;
  final bool checkSearch;
  final bool checkDiscovery;
  final bool checkInfo;
  final bool checkCategory;
  final bool checkContent;

  Set<String> normalizedSourceUrls() {
    return (sourceUrls ?? const <String>[])
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  String normalizedKeyword() {
    return (keywordOverride ?? '').trim();
  }

  int normalizedTimeoutMs() {
    return timeoutMs > 0 ? timeoutMs : 180000;
  }

  bool semanticallyEquals(SourceCheckTaskConfig other) {
    if (includeDisabled != other.includeDisabled) return false;
    if (checkSearch != other.checkSearch) return false;
    if (checkDiscovery != other.checkDiscovery) return false;
    if (checkInfo != other.checkInfo) return false;
    if (checkCategory != other.checkCategory) return false;
    if (checkContent != other.checkContent) return false;
    if (normalizedTimeoutMs() != other.normalizedTimeoutMs()) return false;
    if (normalizedKeyword() != other.normalizedKeyword()) return false;
    final currentUrls = normalizedSourceUrls();
    final otherUrls = other.normalizedSourceUrls();
    if (currentUrls.length != otherUrls.length) return false;
    for (final url in currentUrls) {
      if (!otherUrls.contains(url)) return false;
    }
    return true;
  }
}

class SourceCheckTaskSnapshot {
  const SourceCheckTaskSnapshot({
    required this.config,
    required this.running,
    required this.stopRequested,
    required this.startedAt,
    required this.finishedAt,
    required this.items,
  });

  final SourceCheckTaskConfig config;
  final bool running;
  final bool stopRequested;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<SourceCheckItem> items;

  SourceCheckTaskSnapshot copyWith({
    SourceCheckTaskConfig? config,
    bool? running,
    bool? stopRequested,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<SourceCheckItem>? items,
  }) {
    return SourceCheckTaskSnapshot(
      config: config ?? this.config,
      running: running ?? this.running,
      stopRequested: stopRequested ?? this.stopRequested,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      items: items ?? this.items,
    );
  }
}

enum SourceCheckStartType {
  started,
  attachedExisting,
  runningOtherTask,
  emptySource,
}

class SourceCheckStartResult {
  const SourceCheckStartResult({
    required this.type,
    required this.message,
  });

  final SourceCheckStartType type;
  final String message;
}
