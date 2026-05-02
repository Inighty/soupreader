import 'dart:convert';

import 'package:dio/dio.dart';

const int kRssSourceImportMaxDepth = 3;

/// 是否为合法 http/https URL（带 host）。
bool isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

/// 去除前导 BOM 与首尾空白，便于 JSON.decode。
String sanitizeJsonInput(String raw) {
  var normalized = raw.trim();
  if (normalized.startsWith('﻿')) {
    normalized = normalized.substring(1);
  }
  return normalized;
}

/// 解码可能嵌套了一层 JSON 字符串的值（最多递归 [kRssSourceImportMaxDepth] 层）。
dynamic decodeNestedJsonValue(dynamic value, {int depth = 0}) {
  if (depth >= kRssSourceImportMaxDepth) return value;
  if (value is String) {
    final text = sanitizeJsonInput(value);
    if (text.isEmpty) return value;
    final first = text[0];
    if (first != '{' && first != '[' && first != '"') {
      return value;
    }
    try {
      final decoded = json.decode(text);
      return decodeNestedJsonValue(decoded, depth: depth + 1);
    } catch (_) {
      return value;
    }
  }
  return value;
}

/// 从 decoded JSON 中提取 sourceUrls 数组（兼容字符串/数组/嵌套等多种形式）。
List<String>? extractSourceUrlsFromDecoded(dynamic decoded) {
  if (decoded is! Map) return null;
  if (!decoded.containsKey('sourceUrls')) return null;

  final urls = <String>[];
  void addUrl(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return;
    urls.add(text);
  }

  final raw = decodeNestedJsonValue(decoded['sourceUrls']);
  if (raw is List) {
    for (final item in raw) {
      addUrl(item);
    }
  } else if (raw is String) {
    final normalized = sanitizeJsonInput(raw);
    if (normalized.startsWith('[')) {
      final nested = decodeNestedJsonValue(normalized);
      if (nested is List) {
        for (final item in nested) {
          addUrl(item);
        }
      } else {
        addUrl(normalized);
      }
    } else {
      final parts = normalized.split(RegExp(r'[\n,]'));
      for (final part in parts) {
        addUrl(part);
      }
    }
  } else {
    addUrl(raw);
  }

  return urls;
}

/// 跟随重定向后的提示信息（用于 warnings）。
String? buildRedirectHint({required Uri requested, required Uri? resolved}) {
  if (resolved == null) return null;
  final from = requested.toString().trim();
  final to = resolved.toString().trim();
  if (from.isEmpty || to.isEmpty || from == to) return null;
  return '已跟随重定向：$from -> $to';
}

/// 简单识别浏览器 CORS 错误。
bool isLikelyCorsError(String text) {
  final lower = text.toLowerCase();
  return lower.contains('xmlhttprequest') ||
      lower.contains('cors') ||
      lower.contains('cross-origin') ||
      lower.contains('access-control-allow-origin');
}

/// 根据 [DioException] 类型/消息生成中文错误提示。
String describeRssNetworkError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '网络请求失败：连接超时';
      case DioExceptionType.sendTimeout:
        return '网络请求失败：发送超时';
      case DioExceptionType.receiveTimeout:
        return '网络请求失败：接收超时';
      case DioExceptionType.badCertificate:
        return '网络请求失败：证书异常';
      case DioExceptionType.cancel:
        return '网络请求已取消';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status != null) {
          return '网络请求失败（HTTP $status）';
        }
        break;
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        break;
    }
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return '网络请求失败: $message';
    }
  }
  return '网络请求失败: $error';
}
