import 'dart:convert';

class ConcurrentRateSpec {
  final String raw;
  final bool isWindowMode;
  final int? intervalMs;
  final int? maxCount;
  final int? windowMs;

  const ConcurrentRateSpec.interval({
    required this.raw,
    required this.intervalMs,
  })  : isWindowMode = false,
        maxCount = null,
        windowMs = null;

  const ConcurrentRateSpec.window({
    required this.raw,
    required this.maxCount,
    required this.windowMs,
  })  : isWindowMode = true,
        intervalMs = null;

  String get modeLabel {
    if (!isWindowMode) {
      return '间隔模式 ${intervalMs ?? 0}ms';
    }
    return '窗口模式 ${maxCount ?? 0}/${windowMs ?? 0}ms';
  }
}

class ConcurrentRecord {
  final bool isWindowMode;
  int timeMs;
  int frequency;

  ConcurrentRecord({
    required this.isWindowMode,
    required this.timeMs,
    required this.frequency,
  });
}

class ConcurrentAcquireStep {
  final ConcurrentRecord? record;
  final int waitMs;
  final String decision;

  const ConcurrentAcquireStep({
    required this.record,
    required this.waitMs,
    required this.decision,
  });
}

class ConcurrentAcquireResult {
  final ConcurrentRecord? record;
  final int waitMs;
  final String decision;

  const ConcurrentAcquireResult({
    required this.record,
    required this.waitMs,
    required this.decision,
  });
}

class LegadoUrlParsed {
  final String url;
  final LegadoUrlOption? option;

  const LegadoUrlParsed({
    required this.url,
    required this.option,
  });
}

class LegadoUrlOption {
  final String? method;
  final String? body;
  final String? charset;
  final int? retry;
  final Map<String, String> headers;
  final String? origin;
  final String? js;

  const LegadoUrlOption({
    required this.method,
    required this.body,
    required this.charset,
    required this.retry,
    required this.headers,
    required this.origin,
    required this.js,
  });

  factory LegadoUrlOption.fromJson(Map<String, dynamic> json) {
    String? getString(String key) {
      final value = json[key];
      if (value == null) return null;
      final trimmed = value.toString().trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    Map<String, String> parseHeaders(dynamic raw) {
      final out = <String, String>{};
      if (raw == null) return out;
      if (raw is Map) {
        raw.forEach((key, value) {
          if (key == null || value == null) return;
          final normalizedKey = key.toString().trim();
          if (normalizedKey.isEmpty) return;
          out[normalizedKey] = value.toString();
        });
        return out;
      }
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return out;
        // 对标 legado：UrlOption.headers 允许为 JSON 字符串
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              decoded.forEach((key, value) {
                if (key == null || value == null) return;
                final normalizedKey = key.toString().trim();
                if (normalizedKey.isEmpty) return;
                out[normalizedKey] = value.toString();
              });
              return out;
            }
          } catch (_) {
            // fallthrough
          }
        }
        // 兼容编辑器里每行 key:value 的形式
        for (final line in trimmed.split('\n')) {
          final normalizedLine = line.trim();
          if (normalizedLine.isEmpty) continue;
          final idx = normalizedLine.indexOf(':');
          if (idx <= 0) continue;
          final key = normalizedLine.substring(0, idx).trim();
          final value = normalizedLine.substring(idx + 1).trim();
          if (key.isEmpty) continue;
          out[key] = value;
        }
        return out;
      }
      // 兜底：toString 后尝试 JSON
      final trimmed = raw.toString().trim();
      if (trimmed.isEmpty) return out;
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              if (key == null || value == null) return;
              final normalizedKey = key.toString().trim();
              if (normalizedKey.isEmpty) return;
              out[normalizedKey] = value.toString();
            });
          }
        } catch (_) {
          // ignore
        }
      }
      return out;
    }

    String? parseBody(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) {
        final trimmed = raw.trimRight();
        return trimmed.isEmpty ? null : raw;
      }
      try {
        return jsonEncode(raw);
      } catch (_) {
        final text = raw.toString();
        return text.trim().isEmpty ? null : text;
      }
    }

    int? parseRetry(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      final text = raw.toString().trim();
      if (text.isEmpty) return null;
      return int.tryParse(text);
    }

    final headers = parseHeaders(
      json.containsKey('headers') ? json['headers'] : json['header'],
    );

    return LegadoUrlOption(
      method: getString('method'),
      body: parseBody(json['body']),
      charset: getString('charset'),
      retry: parseRetry(json['retry']),
      headers: headers,
      origin: getString('origin'),
      js: getString('js'),
    );
  }
}

class UrlJsPatchResult {
  final bool ok;
  final String url;
  final Map<String, String> headers;
  final String? error;

  const UrlJsPatchResult({
    required this.ok,
    required this.url,
    required this.headers,
    required this.error,
  });
}

class RequestRetryFailure {
  final Object error;
  final int retryCount;

  const RequestRetryFailure({
    required this.error,
    required this.retryCount,
  });

  @override
  String toString() =>
      'RequestRetryFailure(retryCount=$retryCount, error=$error)';
}

class DecodedText {
  final String text;
  final String charset;
  final String charsetSource;
  final String charsetDecision;

  const DecodedText({
    required this.text,
    required this.charset,
    required this.charsetSource,
    required this.charsetDecision,
  });
}

class ParsedHeaders {
  final Map<String, String> headers;
  final String? warning;

  const ParsedHeaders({
    required this.headers,
    required this.warning,
  });

  static const empty = ParsedHeaders(headers: {}, warning: null);

  @override
  String toString() => 'headers=$headers warning=$warning';
}
