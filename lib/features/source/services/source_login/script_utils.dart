import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:soupreader/core/services/cookie_store.dart';

class SourceLoginScriptUtils {
  static String normalizePromiseOutput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    try {
      final decoded = jsonDecode(text);
      if (decoded == null) return '';
      if (decoded is String) return decoded;
    } catch (_) {
      // keep raw result
    }
    return text;
  }

  static String readStringArg(dynamic args, String key) {
    if (args is Map) {
      final value = args[key];
      if (value == null) return '';
      return value.toString();
    }
    return '';
  }

  static num readNumArg(dynamic args, String key) {
    if (args is Map) {
      final value = args[key];
      if (value is num) return value;
      return num.tryParse(value?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static Map<String, String>? parseHeaderPayload(String payload) {
    final raw = payload.trim();
    if (raw.isEmpty) return <String, String>{};
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final out = <String, String>{};
    decoded.forEach((key, value) {
      if (key == null || value == null) return;
      final normalizedKey = key.toString().trim();
      if (normalizedKey.isEmpty) return;
      out[normalizedKey] = value.toString();
    });
    return out;
  }

  static Map<String, String>? parseHeaderOverridePayload(String payload) {
    final raw = payload.trim();
    if (raw.isEmpty) return null;
    return parseHeaderPayload(raw);
  }

  static Future<void> persistCookieHeader({
    required String sourceUrl,
    required Map<String, String> headers,
  }) async {
    String? cookieHeader;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'cookie') {
        cookieHeader = entry.value.trim();
        break;
      }
    }
    if (cookieHeader == null || cookieHeader.isEmpty) return;
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.host.trim().isEmpty) return;

    final cookies = <Cookie>[];
    for (final segment in cookieHeader.split(';')) {
      final pair = segment.trim();
      if (pair.isEmpty) continue;
      final sep = pair.indexOf('=');
      if (sep <= 0) continue;
      final name = pair.substring(0, sep).trim();
      final value = pair.substring(sep + 1).trim();
      if (name.isEmpty) continue;
      final cookie = Cookie(name, value);
      cookie.domain = uri.host;
      cookies.add(cookie);
    }
    if (cookies.isEmpty) return;
    await CookieStore.saveFromResponse(uri, cookies);
  }

  static String randomUuidV4() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}
