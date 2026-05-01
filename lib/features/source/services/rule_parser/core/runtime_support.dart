import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineRuntimeSupport {
  RuleParserEngineRuntimeSupport(this._ctx);

  final RuleParserContext _ctx;

  Map<String, String> get _runtimeVariables => _ctx.runtimeVariables;
  Map<String, String> get _bookInfoTocHtmlCache => _ctx.bookInfoTocHtmlCache;
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);

  List<String> splitPossibleListValues(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const <String>[];
    final parts = trimmed
        .split(RegExp(r'[\r\n]+|,|，|;|；'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? <String>[trimmed] : parts;
  }

  String normalizeUrlVisitKey(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return trimmed;
    }
    return uri.replace(fragment: '').toString();
  }

  void cacheBookInfoTocHtml({
    required String tocUrl,
    required String html,
  }) {
    final key = normalizeUrlVisitKey(tocUrl);
    final value = html.trim();
    if (key.isEmpty || value.isEmpty || value.length > 2 * 1024 * 1024) {
      return;
    }

    _bookInfoTocHtmlCache[key] = value;
    while (_bookInfoTocHtmlCache.length > 8) {
      _bookInfoTocHtmlCache.remove(_bookInfoTocHtmlCache.keys.first);
    }
  }

  String? getCachedBookInfoTocHtml(String tocUrl) {
    final key = normalizeUrlVisitKey(tocUrl);
    return key.isEmpty ? null : _bookInfoTocHtmlCache[key];
  }

  String? buildNextChapterUrlKey({
    required String chapterEntryUrl,
    String? nextChapterUrl,
  }) {
    final raw = (nextChapterUrl ?? '').trim();
    if (raw.isEmpty) return null;
    final absolute = _absoluteUrl(chapterEntryUrl, raw);
    final key = normalizeUrlVisitKey(absolute);
    return key.isEmpty ? null : key;
  }

  bool markVisitedUrl(Set<String> visitedUrlKeys, String url) {
    final key = normalizeUrlVisitKey(url);
    if (key.isEmpty || visitedUrlKeys.contains(key)) return false;
    visitedUrlKeys.add(key);
    return true;
  }

  List<String> collectNextUrlCandidates(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    Set<String>? queuedUrlKeys,
    String? blockedUrlKey,
  }) {
    if (candidates.isEmpty) return const <String>[];

    final currentKey = normalizeUrlVisitKey(currentUrl);
    final seenInBatch = <String>{};
    final out = <String>[];

    for (final candidate in candidates) {
      final raw = candidate.trim();
      if (raw.isEmpty) continue;
      final absolute = _absoluteUrl(currentUrl, raw);
      final key = normalizeUrlVisitKey(absolute);
      if (key.isEmpty ||
          !seenInBatch.add(key) ||
          key == currentKey ||
          (blockedUrlKey != null &&
              blockedUrlKey.isNotEmpty &&
              key == blockedUrlKey) ||
          visitedUrlKeys.contains(key) ||
          (queuedUrlKeys != null && queuedUrlKeys.contains(key))) {
        continue;
      }
      out.add(absolute);
    }
    return out;
  }

  ({List<String> urls, List<String> debugLines, bool hasBlockedCandidate})
      collectNextUrlCandidatesWithDebug(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    Set<String>? queuedUrlKeys,
    String? blockedUrlKey,
    int maxLogItems = 20,
  }) {
    if (candidates.isEmpty) {
      return (
        urls: const <String>[],
        debugLines: const <String>['候选为空'],
        hasBlockedCandidate: false,
      );
    }

    final currentKey = normalizeUrlVisitKey(currentUrl);
    final seenInBatch = <String>{};
    final out = <String>[];
    final lines = <String>[];
    var hasBlockedCandidate = false;
    var omitted = 0;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final raw = candidate.trim();
      String reason;
      String? absolute;

      if (raw.isEmpty) {
        reason = '跳过：空值';
      } else {
        absolute = _absoluteUrl(currentUrl, raw);
        final key = normalizeUrlVisitKey(absolute);
        if (key.isEmpty) {
          reason = '跳过：无效链接';
        } else if (!seenInBatch.add(key)) {
          reason = '跳过：本批重复';
        } else if (key == currentKey) {
          reason = '跳过：当前页';
        } else if (blockedUrlKey != null &&
            blockedUrlKey.isNotEmpty &&
            key == blockedUrlKey) {
          hasBlockedCandidate = true;
          reason = '跳过：命中下一章';
        } else if (visitedUrlKeys.contains(key)) {
          reason = '跳过：已访问';
        } else if (queuedUrlKeys != null && queuedUrlKeys.contains(key)) {
          reason = '跳过：已在队列';
        } else {
          out.add(absolute);
          reason = '入队';
        }
      }

      if (i < maxLogItems) {
        final src = raw.isEmpty ? '(空)' : raw;
        final dst = absolute == null ? '' : ' => $absolute';
        lines.add('[$i] $src$dst | $reason');
      } else {
        omitted++;
      }
    }

    if (omitted > 0) {
      lines.add('…其余 $omitted 条候选省略');
    }
    lines.add(
      '汇总：新增 ${out.length} 条；已访问 ${visitedUrlKeys.length} 条；'
      '待处理队列 ${(queuedUrlKeys ?? const <String>{}).length} 条',
    );
    return (
      urls: out,
      debugLines: lines,
      hasBlockedCandidate: hasBlockedCandidate,
    );
  }

  String? pickNextUrlCandidate(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    String? blockedUrlKey,
  }) {
    final list = collectNextUrlCandidates(
      candidates,
      currentUrl: currentUrl,
      visitedUrlKeys: visitedUrlKeys,
      blockedUrlKey: blockedUrlKey,
    );
    return list.isEmpty ? null : list.first;
  }

  String normalizeVariableKey(String key) => key.trim();

  String getRuntimeVariable(String key) {
    final normalized = normalizeVariableKey(key);
    return normalized.isEmpty ? '' : (_runtimeVariables[normalized] ?? '');
  }

  void putRuntimeVariable(String key, String value) {
    final normalized = normalizeVariableKey(key);
    if (normalized.isEmpty) return;
    _runtimeVariables[normalized] = value;
  }

  void clearRuntimeVariables() {
    _runtimeVariables.clear();
    _bookInfoTocHtmlCache.clear();
  }

  bool isSensitiveVariableKey(String key) {
    final lower = key.trim().toLowerCase();
    if (lower.isEmpty) return false;
    const tags = <String>[
      'token',
      'cookie',
      'auth',
      'password',
      'passwd',
      'pwd',
      'secret',
      'session',
      'sid',
      'apikey',
      'api_key',
      'authorization',
      'refresh',
    ];
    return tags.any(lower.contains);
  }

  String maskRuntimeVariableValue(String value, {required bool strong}) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (strong) {
      if (text.length <= 4) return '*' * text.length;
      return '${'*' * (text.length - 2)}${text.substring(text.length - 2)}';
    }
    if (text.length <= 2) return '*' * text.length;
    if (text.length <= 8) return '${text.substring(0, 1)}${'*' * (text.length - 1)}';
    return '${text.substring(0, 2)}${'*' * (text.length - 4)}${text.substring(text.length - 2)}';
  }

  Map<String, String> runtimeVariableSnapshot({required bool desensitize}) {
    if (_runtimeVariables.isEmpty) return const <String, String>{};
    final out = <String, String>{};
    final entries = _runtimeVariables.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      out[key] = !desensitize
          ? entry.value
          : maskRuntimeVariableValue(
              entry.value,
              strong: isSensitiveVariableKey(key),
            );
    }
    return out;
  }

  String replaceGetTokens(String input) {
    if (input.isEmpty || !input.contains('@get:{')) return input;
    return input.replaceAllMapped(
      RegExp(r'@get:\{([^{}]+)\}'),
      (match) => getRuntimeVariable(match.group(1)?.trim() ?? ''),
    );
  }

  bool isPureGetTokenRule(String rawRule) =>
      RegExp(r'^@get:\{[^{}]+\}$').hasMatch(rawRule.trim());

  bool isPureTemplateTokenRule(String rawRule) {
    final trimmed = rawRule.trim();
    return trimmed.length >= 4 &&
        trimmed.startsWith('{{') &&
        trimmed.endsWith('}}') &&
        trimmed.indexOf('{{') == 0 &&
        trimmed.lastIndexOf('}}') == trimmed.length - 2;
  }

  bool isLiteralRuleCandidate(String rawRule) {
    if (rawRule.trim().isEmpty) return false;
    return isPureGetTokenRule(rawRule) || isPureTemplateTokenRule(rawRule);
  }

  bool isRuleTruthy(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    final lowered = value.toLowerCase();
    if (lowered == 'null') return false;
    return !RegExp(r'^(false|no|not|0)$', caseSensitive: false).hasMatch(value);
  }
}
