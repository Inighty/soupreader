import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineRequestLifecycleSupport {
  RuleParserEngineRequestLifecycleSupport(this._ctx);

  final RuleParserContext _ctx;

  Map<String, ConcurrentRecord> get _concurrentRecordMap =>
      _ctx.concurrentRecordMap;
  Map<String, String> get _defaultHeaders => _ctx.defaultHeaders;
  RegExp get _httpHeaderTokenRegex => _ctx.httpHeaderTokenRegex;
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);

  ConcurrentRateSpec? parseConcurrentRateSpec(String? concurrentRateRaw) {
    final raw = (concurrentRateRaw ?? '').trim();
    if (raw.isEmpty || raw == '0') return null;

    final slashIndex = raw.indexOf('/');
    if (slashIndex <= 0) {
      final intervalMs = int.tryParse(raw);
      return intervalMs == null || intervalMs <= 0
          ? null
          : ConcurrentRateSpec.interval(raw: raw, intervalMs: intervalMs);
    }

    final count = int.tryParse(raw.substring(0, slashIndex).trim());
    final windowMs = int.tryParse(raw.substring(slashIndex + 1).trim());
    if (count == null || count <= 0 || windowMs == null || windowMs <= 0) {
      return null;
    }
    return ConcurrentRateSpec.window(
      raw: raw,
      maxCount: count,
      windowMs: windowMs,
    );
  }

  ConcurrentAcquireStep tryAcquireConcurrentRate({
    required String sourceKey,
    required ConcurrentRateSpec spec,
  }) {
    final key = sourceKey.trim();
    if (key.isEmpty) {
      return ConcurrentAcquireStep(
        record: null,
        waitMs: 0,
        decision: '${spec.modeLabel}（sourceKey 为空，跳过限制）',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final record = _concurrentRecordMap[key] ??
        ConcurrentRecord(
          isWindowMode: spec.isWindowMode,
          timeMs: now,
          frequency: 1,
        );
    _concurrentRecordMap[key] = record;
    if (record.timeMs == now && record.frequency == 1) {
      return ConcurrentAcquireStep(
        record: record,
        waitMs: 0,
        decision: spec.modeLabel,
      );
    }

    if (!record.isWindowMode) {
      final intervalMs = spec.intervalMs;
      if (intervalMs == null || intervalMs <= 0) {
        return const ConcurrentAcquireStep(
          record: null,
          waitMs: 0,
          decision: '并发率格式非法，跳过限制',
        );
      }
      if (record.frequency > 0) {
        return ConcurrentAcquireStep(
          record: record,
          waitMs: intervalMs,
          decision: spec.modeLabel,
        );
      }
      final nextTime = record.timeMs + intervalMs;
      if (now >= nextTime) {
        record
          ..timeMs = now
          ..frequency = 1;
        return ConcurrentAcquireStep(
          record: record,
          waitMs: 0,
          decision: spec.modeLabel,
        );
      }
      return ConcurrentAcquireStep(
        record: record,
        waitMs: nextTime - now,
        decision: spec.modeLabel,
      );
    }

    final maxCount = spec.maxCount;
    final windowMs = spec.windowMs;
    if (maxCount == null || maxCount <= 0 || windowMs == null || windowMs <= 0) {
      return const ConcurrentAcquireStep(
        record: null,
        waitMs: 0,
        decision: '并发率格式非法，跳过限制',
      );
    }

    final nextTime = record.timeMs + windowMs;
    if (now >= nextTime) {
      record
        ..timeMs = now
        ..frequency = 1;
      return ConcurrentAcquireStep(
        record: record,
        waitMs: 0,
        decision: spec.modeLabel,
      );
    }

    if (record.frequency > maxCount) {
      return ConcurrentAcquireStep(
        record: record,
        waitMs: nextTime - now,
        decision: spec.modeLabel,
      );
    }

    record.frequency += 1;
    return ConcurrentAcquireStep(
      record: record,
      waitMs: 0,
      decision: spec.modeLabel,
    );
  }

  Future<ConcurrentAcquireResult> acquireConcurrentRatePermit({
    required String? sourceKey,
    required String? concurrentRate,
  }) async {
    final spec = parseConcurrentRateSpec(concurrentRate);
    if (spec == null) {
      return ConcurrentAcquireResult(
        record: null,
        waitMs: 0,
        decision: '未启用并发率限制',
      );
    }

    var totalWaitMs = 0;
    while (true) {
      final step = tryAcquireConcurrentRate(
        sourceKey: sourceKey ?? '',
        spec: spec,
      );
      if (step.waitMs <= 0) {
        return ConcurrentAcquireResult(
          record: step.record,
          waitMs: totalWaitMs,
          decision: step.decision,
        );
      }
      totalWaitMs += step.waitMs;
      await Future<void>.delayed(Duration(milliseconds: step.waitMs));
    }
  }

  void releaseConcurrentRatePermit(ConcurrentRecord? record) {
    if (record == null || record.isWindowMode || record.frequency <= 0) return;
    record.frequency -= 1;
  }

  Map<String, String> buildEffectiveRequestHeaders(
    String url, {
    required Map<String, String> customHeaders,
  }) {
    final headers = <String, String>{}..addAll(_defaultHeaders);
    customHeaders.forEach((key, value) {
      final trimmedKey = key.trim();
      if (trimmedKey.isEmpty || !_httpHeaderTokenRegex.hasMatch(trimmedKey)) {
        return;
      }
      headers[trimmedKey] = value;
    });
    _applyAutoOriginHeaders(headers, url);
    return headers;
  }

  void applyPreferredOriginHeaders(
    Map<String, String> headers,
    String? originText,
  ) {
    final raw = (originText ?? '').trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return;
    _applyOriginHeadersForUri(headers, uri);
  }

  String formatRequestHeadersForLog(Map<String, String> headers) {
    if (headers.isEmpty) return '—';

    String redactIfSensitive(String key, String value) {
      final lower = key.toLowerCase();
      if (lower == 'cookie' || lower == 'authorization') {
        if (value.length <= 160) return value;
        return '${value.substring(0, 120)}…${value.substring(value.length - 40)} (len=${value.length})';
      }
      return value.length <= 220 ? value : '${value.substring(0, 220)}…';
    }

    const preferredOrder = <String>[
      'User-Agent',
      'Accept',
      'Accept-Language',
      'Referer',
      'Origin',
      'Cookie',
    ];
    final entries = headers.entries.toList(growable: false);
    final takenLower = <String>{};
    final lines = <String>[];

    String? getByName(String name) {
      final lower = name.toLowerCase();
      for (final entry in entries) {
        if (entry.key.toLowerCase() == lower) {
          return '${entry.key}: ${redactIfSensitive(entry.key, entry.value)}';
        }
      }
      return null;
    }

    for (final key in preferredOrder) {
      final line = getByName(key);
      if (line != null) {
        lines.add(line);
        takenLower.add(key.toLowerCase());
      }
    }

    final rest = entries
        .where((entry) => !takenLower.contains(entry.key.toLowerCase()))
        .toList(growable: false)
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    for (final entry in rest) {
      lines.add('${entry.key}: ${redactIfSensitive(entry.key, entry.value)}');
    }
    return lines.length <= 18
        ? lines.join('\n')
        : '${lines.take(18).join('\n')}\n…（${lines.length - 18} 行已省略）';
  }

  ResolvedBookListRule? resolveBookListRuleForStage(
    BookSource source, {
    required bool isSearch,
  }) {
    if (isSearch) {
      final searchRule = source.ruleSearch;
      return searchRule == null
          ? null
          : ResolvedBookListRule(
              rule: searchRule,
              usedSearchRuleAsExploreFallback: false,
            );
    }

    final exploreRule = source.ruleExplore;
    if (exploreRule != null && (exploreRule.bookList ?? '').trim().isNotEmpty) {
      return ResolvedBookListRule(
        rule: exploreRule,
        usedSearchRuleAsExploreFallback: false,
      );
    }

    final searchRule = source.ruleSearch;
    if (searchRule != null) {
      return ResolvedBookListRule(
        rule: searchRule,
        usedSearchRuleAsExploreFallback: true,
      );
    }

    return exploreRule == null
        ? null
        : ResolvedBookListRule(
            rule: exploreRule,
            usedSearchRuleAsExploreFallback: false,
          );
  }

  String resolveBookInfoTocUrlLikeLegado({
    required String rawValue,
    required String requestUrl,
    required String redirectUrl,
  }) {
    final request = requestUrl.trim();
    final redirect = redirectUrl.trim().isNotEmpty ? redirectUrl.trim() : request;
    final trimmed = rawValue.trim();
    return trimmed.isEmpty ? request : _absoluteUrl(redirect, trimmed).trim();
  }

  String importantResponseHeaders(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    final normalized = <String, String>{};
    headers.forEach((key, value) => normalized[key.toLowerCase()] = value);
    const keys = <String>[
      'content-type',
      'location',
      'set-cookie',
      'server',
      'via',
      'x-powered-by',
      'cf-ray',
      'cf-cache-status',
      'x-cache',
      'x-served-by',
    ];
    final parts = <String>[];
    for (final key in keys) {
      final value = normalized[key];
      if (value == null || value.trim().isEmpty) continue;
      parts.add('$key=${value.length <= 200 ? value : '${value.substring(0, 200)}…'}');
    }
    return parts.join('; ');
  }

  void _applyAutoOriginHeaders(Map<String, String> headers, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return;
    _applyOriginHeadersForUri(headers, uri);
  }

  void _applyOriginHeadersForUri(Map<String, String> headers, Uri uri) {
    final isDefaultPort = (uri.scheme == 'http' && uri.port == 80) ||
        (uri.scheme == 'https' && uri.port == 443);
    final origin = isDefaultPort || !uri.hasPort
        ? '${uri.scheme}://${uri.host}'
        : '${uri.scheme}://${uri.host}:${uri.port}';

    bool hasKey(String key) {
      final lower = key.toLowerCase();
      return headers.keys.any((item) => item.toLowerCase() == lower);
    }

    if (!hasKey('Origin')) headers['Origin'] = origin;
    if (!hasKey('Referer')) headers['Referer'] = '$origin/';
  }
}
