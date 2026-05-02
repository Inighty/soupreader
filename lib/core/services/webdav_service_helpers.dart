import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import '../models/app_settings.dart';
import 'webdav_service_models.dart';

const String urlLabel = 'URL';

bool isDirectory({
  required String contentType,
  required String resourceTypeXml,
}) {
  final normalizedType = contentType.trim().toLowerCase();
  if (normalizedType == 'httpd/unix-directory') return true;
  return resourceTypeXml.toLowerCase().contains('collection');
}

String extractTagText(String source, String tag) {
  final exp = RegExp(
    '<(?:\\w+:)?$tag\\b[^>]*>([\\s\\S]*?)<\\/(?:\\w+:)?$tag>',
    caseSensitive: false,
  );
  final raw = exp.firstMatch(source)?.group(1) ?? '';
  return raw.replaceAll(RegExp(r'<[^>]+>'), '').trim();
}

String extractTagInnerXml(String source, String tag) {
  final exp = RegExp(
    '<(?:\\w+:)?$tag\\b[^>]*>([\\s\\S]*?)<\\/(?:\\w+:)?$tag>',
    caseSensitive: false,
  );
  return exp.firstMatch(source)?.group(1)?.trim() ?? '';
}

String decodeXmlText(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .trim();
}

String normalizeUrl(String value) {
  var normalized = value.trim();
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String extractFileName(String decodedHref) {
  final trimmed = decodedHref.trim();
  if (trimmed.isEmpty) return '';
  final clean = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  final slashIndex = clean.lastIndexOf('/');
  if (slashIndex < 0 || slashIndex == clean.length - 1) {
    return clean;
  }
  return clean.substring(slashIndex + 1);
}

String? resolveHref(Uri requestUri, String href) {
  final raw = href.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return uri.toString();
    }
    if (uri.scheme == 'dav') {
      return uri.replace(scheme: 'http').toString();
    }
    if (uri.scheme == 'davs') {
      return uri.replace(scheme: 'https').toString();
    }
  }
  if (raw.startsWith('/')) {
    return '${requestUri.scheme}://${requestUri.authority}$raw';
  }
  return requestUri.resolve(raw).toString();
}

int parseLastModify(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return 0;
  try {
    return HttpDate.parse(value).millisecondsSinceEpoch;
  } catch (_) {
    return 0;
  }
}

Map<String, String> buildAuthHeaders(AppSettings settings) {
  final account = settings.webDavAccount.trim();
  final password = settings.webDavPassword.trim();
  final token = base64Encode(utf8.encode('$account:$password'));
  return <String, String>{
    'Authorization': 'Basic $token',
  };
}

bool isSuccessStatus(int? statusCode) {
  if (statusCode == null) return false;
  return statusCode >= 200 && statusCode < 300;
}

WebDavOperationException buildStatusException({
  required String action,
  required Uri uri,
  required Response<dynamic> response,
}) {
  final status = response.statusCode ?? -1;
  final reason = firstNonEmpty(<String?>[
    response.statusMessage,
    compactBodySnippet(response.data),
  ]);
  final headerHint = importantHeaders(response.headers.map);
  final tail = reason == null ? '' : '，$reason';
  return WebDavOperationException(
    '$action失败（HTTP $status）$tail$headerHint\n$urlLabel: ${uri.toString()}',
  );
}

String formatDioError({
  required String method,
  required Uri uri,
  required DioException error,
}) {
  final response = error.response;
  if (response != null) {
    final status = response.statusCode ?? -1;
    final reason = firstNonEmpty(<String?>[
      response.statusMessage,
      compactBodySnippet(response.data),
    ]);
    final headerHint = importantHeaders(response.headers.map);
    final tail = reason == null ? '' : '，$reason';
    return '$method 请求失败（HTTP $status）$tail$headerHint\n$urlLabel: ${uri.toString()}';
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return '$method 请求超时：${uri.toString()}';
    case DioExceptionType.connectionError:
      return '$method 连接失败：${error.message ?? '网络异常'}';
    case DioExceptionType.badCertificate:
      return '$method 证书校验失败：${uri.toString()}';
    case DioExceptionType.cancel:
      return '$method 请求已取消：${uri.toString()}';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      return '$method 请求异常：${error.message ?? '未知错误'}';
  }
}

String importantHeaders(Map<String, List<String>> headers) {
  const keys = <String>['www-authenticate', 'dav', 'allow', 'content-type'];
  final parts = <String>[];
  for (final key in keys) {
    final values = headers[key];
    if (values == null || values.isEmpty) continue;
    parts.add('$key=${values.join(',')}');
  }
  if (parts.isEmpty) return '';
  return '，关键响应头：${parts.join('; ')}';
}

String? compactBodySnippet(Object? data) {
  if (data == null) return null;
  if (data is List<int>) {
    if (data.isEmpty) return null;
    final text = utf8.decode(data, allowMalformed: true).trim();
    if (text.isEmpty) return null;
    return trimLength(text);
  }
  final text = data.toString().trim();
  if (text.isEmpty) return null;
  return trimLength(text);
}

List<int>? responseBytes(Object? data) {
  if (data == null) return null;
  if (data is List<int>) return data;
  if (data is String) return utf8.encode(data);
  return utf8.encode(data.toString());
}

String normalizeProgressFileNameSegment(String input) {
  var normalized = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return 'unknown';
  return normalized;
}

String trimLength(String text, {int max = 120}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= max) return normalized;
  return '${normalized.substring(0, max)}…';
}

String? firstNonEmpty(List<String?> values) {
  for (final raw in values) {
    final text = raw?.trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

