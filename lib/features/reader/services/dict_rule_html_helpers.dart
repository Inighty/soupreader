import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// 检测响应字节的字符集并解码为字符串。
///
/// 优先使用响应头中的 charset；否则尝试 HTML head 中的 meta；
/// 都没有时按 UTF-8 处理，失败再依次尝试 GBK / latin1。
String decodeHtmlResponseBytes(Uint8List bytes, Headers headers) {
  if (bytes.isEmpty) return '';
  final headerCharset = _tryParseCharsetFromContentType(
    headers.value('content-type') ?? headers.value('Content-Type'),
  );
  final htmlCharset = _tryParseCharsetFromHtmlHead(bytes);
  final effectiveCharset =
      (headerCharset?.isNotEmpty == true ? headerCharset : htmlCharset) ??
          'utf-8';
  final normalized = _normalizeCharset(effectiveCharset);
  try {
    if (normalized == 'gbk') {
      return gbk.decode(bytes, allowMalformed: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    try {
      return gbk.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }
}

String _normalizeCharset(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) return 'utf-8';
  if (normalized == 'utf8') return 'utf-8';
  if (normalized == 'gb2312' ||
      normalized == 'gbk' ||
      normalized == 'gb18030') {
    return 'gbk';
  }
  return normalized;
}

String? _tryParseCharsetFromContentType(String? contentType) {
  final ct = (contentType ?? '').trim();
  if (ct.isEmpty) return null;
  final match = RegExp(
    r'charset\s*=\s*([^;\s]+)',
    caseSensitive: false,
  ).firstMatch(ct);
  if (match == null) return null;
  final value = match.group(1);
  if (value == null || value.trim().isEmpty) return null;
  return _normalizeCharset(value.replaceAll('"', '').replaceAll("'", ''));
}

String? _tryParseCharsetFromHtmlHead(Uint8List bytes) {
  final headLength = bytes.length < 4096 ? bytes.length : 4096;
  final head = latin1.decode(
    bytes.sublist(0, headLength),
    allowInvalid: true,
  );
  final first = RegExp(
    r'''<meta[^>]+charset\s*=\s*['"]?\s*([^'"\s/>]+)''',
    caseSensitive: false,
  ).firstMatch(head);
  if (first != null) {
    final charset = first.group(1);
    if (charset != null && charset.trim().isNotEmpty) {
      return _normalizeCharset(charset);
    }
  }
  final second = RegExp(
    r'''<meta[^>]+http-equiv\s*=\s*['"]content-type['"][^>]+content\s*=\s*['"][^'"]*charset\s*=\s*([^'"\s;]+)''',
    caseSensitive: false,
  ).firstMatch(head);
  if (second != null) {
    final charset = second.group(1);
    if (charset != null && charset.trim().isNotEmpty) {
      return _normalizeCharset(charset);
    }
  }
  return null;
}

/// 判断给定规则文本是否为 jsoup-like JS 脚本。
bool looksLikeJsoupScript(String rule) {
  final lower = rule.toLowerCase();
  return lower.startsWith('@js:') ||
      lower.contains('org.jsoup.jsoup.parse(result)') ||
      lower.contains('jsoup.select(');
}

/// 对 jsoup-like 脚本进行最小化解释执行：支持 `.remove()` 与 `.html()/.text()/.outerHtml()`。
String applyJsoupLikeScript({
  required String sourceHtml,
  required String jsRule,
}) {
  var script = jsRule.trim();
  if (script.toLowerCase().startsWith('@js:')) {
    script = script.substring(4).trim();
  }
  if (script.isEmpty) return sourceHtml;

  final document = html_parser.parse(sourceHtml);

  final removePattern = RegExp(
    r'''jsoup\.select\((['"])(.*?)\1\)\.remove\(\)''',
    caseSensitive: false,
    dotAll: true,
  );
  for (final match in removePattern.allMatches(script)) {
    final rawSelector = match.group(2);
    if (rawSelector == null) continue;
    final selector = _decodeJsString(rawSelector);
    if (selector.isEmpty) continue;
    final targets = _queryElements(document, selector);
    for (final node in targets) {
      node.remove();
    }
  }

  String? extracted;
  final extractPattern = RegExp(
    r'''jsoup\.select\((['"])(.*?)\1\)\.(html|text|outerHtml)\(\)''',
    caseSensitive: false,
    dotAll: true,
  );
  for (final match in extractPattern.allMatches(script)) {
    final rawSelector = match.group(2);
    final operationRaw = match.group(3);
    if (rawSelector == null || operationRaw == null) continue;
    final selector = _decodeJsString(rawSelector);
    if (selector.isEmpty) continue;
    final targets = _queryElements(document, selector);
    if (targets.isEmpty) {
      extracted = '';
      continue;
    }
    final operation = operationRaw.toLowerCase();
    switch (operation) {
      case 'html':
        extracted = targets.map((node) => node.innerHtml).join('\n').trim();
        break;
      case 'text':
        extracted = targets.map((node) => node.text).join('\n').trim();
        break;
      case 'outerhtml':
        extracted = targets.map((node) => node.outerHtml).join('\n').trim();
        break;
    }
  }

  if (extracted != null) return extracted;
  return sourceHtml;
}

List<Element> _queryElements(Document document, String selector) {
  try {
    return document.querySelectorAll(selector);
  } catch (_) {
    return const <Element>[];
  }
}

String _decodeJsString(String raw) {
  return raw
      .replaceAll(r'\"', '"')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\\', '\\')
      .trim();
}
