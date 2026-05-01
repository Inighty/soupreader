import 'dart:convert';

class SourceLoginWebViewHeaderParser {
  static Map<String, String> buildHeaderMap(
    String? rawHeader, {
    required String defaultUserAgent,
  }) {
    final headers = _parseHeaderMap(rawHeader);
    headers.putIfAbsent('User-Agent', () => defaultUserAgent);
    return headers;
  }

  static Map<String, String> _parseHeaderMap(String? rawHeader) {
    final text = (rawHeader ?? '').trim();
    if (text.isEmpty) return <String, String>{};

    dynamic payload = text;
    for (var i = 0; i < 2; i++) {
      if (payload is! String) break;
      final current = payload.trim();
      if (current.isEmpty) return <String, String>{};
      if (!(current.startsWith('{') && current.endsWith('}')) &&
          !(current.startsWith('"') && current.endsWith('"'))) {
        break;
      }
      try {
        payload = jsonDecode(current);
      } catch (_) {
        break;
      }
    }

    if (payload is Map) {
      final out = <String, String>{};
      payload.forEach((key, value) {
        if (key == null || value == null) return;
        final normalizedKey = key.toString().trim();
        if (normalizedKey.isEmpty) return;
        out[normalizedKey] = value.toString();
      });
      return out;
    }

    if (payload is! String) return <String, String>{};
    final out = <String, String>{};
    final lines = payload.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final index = trimmed.indexOf(':');
      if (index <= 0) continue;
      final key = trimmed.substring(0, index).trim();
      final value = trimmed.substring(index + 1).trim();
      if (key.isEmpty) continue;
      out[key] = value;
    }
    return out;
  }
}
