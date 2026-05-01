import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';

import 'package:soupreader/features/source/services/rule_parser/request/request_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineRequestCodecSupport {
  RuleParserEngineRequestCodecSupport(this._ctx);

  final RuleParserContext _ctx;

  dynamic _tryDecodeJsonValue(String text) => _ctx.tryDecodeJsonValue(text);

  String? getHeaderIgnoreCase(Map<String, String> headers, String key) {
    final lower = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }

  ({
    String url,
    String method,
    String? body,
    int retry,
    String methodDecision,
    String retryDecision,
    String requestCharsetDecision,
    String bodyEncoding,
    String bodyDecision,
  }) normalizeRequestPayload(
    String url,
    LegadoUrlOption? option,
    Map<String, String> requestHeaders,
  ) {
    final methodRaw = (option?.method ?? '').trim();
    var method = methodRaw.toUpperCase();
    if (method.isEmpty) method = 'GET';

    final methodDecision = methodRaw.isEmpty
        ? '未配置 method，使用默认 GET'
        : '使用 urlOption.method=$method';

    final retry = option?.retry ?? 0;
    final normalizedRetry = retry < 0 ? 0 : retry;
    final retryDecision = retry < 0
        ? 'urlOption.retry=$retry（非法负值），已按 0 处理'
        : 'urlOption.retry=$normalizedRetry';

    final optionCharset = option?.charset;
    final normalizedOptionCharset = _normalizeCharset(optionCharset ?? '');

    final requestCharsetDecision = normalizedOptionCharset.isEmpty
        ? '未指定 charset，URL/表单按原值（默认 UTF-8）处理'
        : normalizedOptionCharset == 'escape'
            ? '请求参数按 escape 编码'
            : '请求参数按 $normalizedOptionCharset 编码';

    var finalUrl = _encodeUrlQueryByCharset(url, optionCharset);
    var body = option?.body;
    var bodyEncoding = 'none';
    var bodyDecision =
        _isBodyMethod(method) ? '请求体为空' : '$method 非 body 方法，不发送请求体';

    if (_isBodyMethod(method) && body != null && body.isNotEmpty) {
      final contentType = getHeaderIgnoreCase(requestHeaders, 'Content-Type');
      final lowerContentType = (contentType ?? '').toLowerCase();
      final hasContentType = (contentType ?? '').trim().isNotEmpty;
      final formContentType = lowerContentType.contains(
        'application/x-www-form-urlencoded',
      );
      final structuredBody =
          _looksLikeJsonText(body) || _looksLikeXmlText(body);

      if (formContentType || (!hasContentType && !structuredBody)) {
        bodyEncoding = 'form';
        bodyDecision = formContentType
            ? 'Content-Type 指定 x-www-form-urlencoded，按表单编码 body'
            : '未指定 Content-Type 且 body 非 JSON/XML，按表单编码 body';
        body = _encodeParamsText(body, optionCharset, isQuery: false);
        if (!hasContentType) {
          final normalizedCharset = _normalizeCharset(optionCharset ?? '');
          requestHeaders['Content-Type'] =
              'application/x-www-form-urlencoded; charset=${_charsetLabelForContentType(normalizedCharset)}';
          bodyDecision = '$bodyDecision，并自动补齐 Content-Type';
        }
      } else if (_looksLikeJsonText(body)) {
        bodyEncoding = 'json';
        bodyDecision = hasContentType
            ? '识别为 JSON，保留原始 body（Content-Type 已给出）'
            : '识别为 JSON，保留原始 body';
      } else {
        bodyEncoding = 'raw';
        bodyDecision =
            hasContentType ? '保留原始 body（由 Content-Type 指示）' : '保留原始 body';
      }
    }

    return (
      url: finalUrl,
      method: method,
      body: body,
      retry: normalizedRetry,
      methodDecision: methodDecision,
      retryDecision: retryDecision,
      requestCharsetDecision: requestCharsetDecision,
      bodyEncoding: bodyEncoding,
      bodyDecision: bodyDecision,
    );
  }

  Future<({Response<List<int>> response, int retryCount})> requestBytesWithRetry({
    required Dio dio,
    required String url,
    required Options options,
    required String method,
    required String? body,
    required int retry,
    CancelToken? cancelToken,
  }) async {
    final maxAttempt = retry < 0 ? 0 : retry;
    Object? lastError;

    for (var attempt = 0; attempt <= maxAttempt; attempt++) {
      try {
        final response = await dio.request<List<int>>(
          url,
          data: _isBodyMethod(method) ? (body ?? '') : null,
          cancelToken: cancelToken,
          options: options,
        );
        return (response: response, retryCount: attempt);
      } catch (error) {
        lastError = error;
        final canRetry =
            attempt < maxAttempt && _isRetryableRequestError(error);
        if (!canRetry) {
          throw RequestRetryFailure(error: error, retryCount: attempt);
        }
      }
    }

    throw RequestRetryFailure(
      error: lastError ?? StateError('request failed without explicit error'),
      retryCount: maxAttempt,
    );
  }

  DecodedText decodeResponseBytes({
    required Uint8List bytes,
    required Map<String, String> responseHeaders,
    String? optionCharset,
  }) {
    final forced = optionCharset != null && optionCharset.trim().isNotEmpty
        ? _normalizeCharset(optionCharset)
        : '';
    final headerCharset = _tryParseCharsetFromContentType(
      responseHeaders['content-type'] ?? responseHeaders['Content-Type'],
    );
    final htmlCharset = _tryParseCharsetFromHtmlHead(bytes);

    final charsetSource = forced.isNotEmpty
        ? 'urlOption.charset'
        : (headerCharset?.isNotEmpty == true)
            ? '响应头 Content-Type'
            : (htmlCharset?.isNotEmpty == true)
                ? 'HTML meta'
                : '默认回退';

    final charset = (forced.isNotEmpty
            ? forced
            : (headerCharset?.isNotEmpty == true ? headerCharset! : ''))
        .trim();

    final effective = charset.isNotEmpty ? charset : (htmlCharset ?? 'utf-8');
    final normalized = _normalizeCharset(effective);
    final decisionPrefix =
        '来源=$charsetSource，option=${forced.isEmpty ? '-' : forced}，header=${headerCharset ?? '-'}，meta=${htmlCharset ?? '-'}，effective=${normalized.isEmpty ? 'utf-8' : normalized}';

    try {
      if (normalized == 'gbk') {
        return DecodedText(
          text: gbk.decode(bytes, allowMalformed: true),
          charset: 'gbk',
          charsetSource: charsetSource,
          charsetDecision: '$decisionPrefix，decoder=gbk',
        );
      }
      if (normalized == 'utf-8') {
        return DecodedText(
          text: utf8.decode(bytes, allowMalformed: true),
          charset: 'utf-8',
          charsetSource: charsetSource,
          charsetDecision: '$decisionPrefix，decoder=utf-8',
        );
      }
      return DecodedText(
        text: utf8.decode(bytes, allowMalformed: true),
        charset: normalized,
        charsetSource: charsetSource,
        charsetDecision: '$decisionPrefix，decoder=utf-8(容错)',
      );
    } catch (_) {
      return DecodedText(
        text: latin1.decode(bytes, allowInvalid: true),
        charset: normalized.isEmpty ? 'latin1' : normalized,
        charsetSource: charsetSource,
        charsetDecision: '$decisionPrefix，decoder=latin1(回退)',
      );
    }
  }

  String _normalizeCharset(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    if (normalized == 'utf8' || normalized == 'utf_8') return 'utf-8';
    if (normalized == 'gb2312' ||
        normalized == 'gbk' ||
        normalized == 'gb18030') {
      return 'gbk';
    }
    return normalized;
  }

  bool _containsPercentTriplet(String text) {
    if (text.length < 3) return false;
    for (var i = 0; i <= text.length - 3; i++) {
      if (text.codeUnitAt(i) != 0x25) continue;
      final a = text.codeUnitAt(i + 1);
      final b = text.codeUnitAt(i + 2);
      final aHex =
          (a >= 48 && a <= 57) || (a >= 65 && a <= 70) || (a >= 97 && a <= 102);
      final bHex =
          (b >= 48 && b <= 57) || (b >= 65 && b <= 70) || (b >= 97 && b <= 102);
      if (aHex && bHex) return true;
    }
    return false;
  }

  String _percentEncodeBytes(
    List<int> bytes, {
    required bool spaceAsPlus,
  }) {
    const hex = '0123456789ABCDEF';
    final out = StringBuffer();

    for (final b in bytes) {
      final byte = b & 0xFF;
      final isAlphaNum = (byte >= 0x30 && byte <= 0x39) ||
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A);
      final isUnreserved = isAlphaNum ||
          byte == 0x2D ||
          byte == 0x5F ||
          byte == 0x2E ||
          byte == 0x7E;
      if (isUnreserved) {
        out.writeCharCode(byte);
        continue;
      }
      if (spaceAsPlus && byte == 0x20) {
        out.write('+');
        continue;
      }
      out.write('%');
      out.write(hex[(byte >> 4) & 0x0F]);
      out.write(hex[byte & 0x0F]);
    }

    return out.toString();
  }

  String _decodeMaybePercentEncoded(
    String token, {
    required bool formStyle,
  }) {
    if (token.isEmpty) return token;
    final hasEncoded = _containsPercentTriplet(token);
    final hasFormPlus = formStyle && token.contains('+');
    if (!hasEncoded && !hasFormPlus) return token;

    var input = token;
    if (formStyle && input.contains('+')) {
      input = input.replaceAll('+', '%20');
    }
    try {
      return Uri.decodeComponent(input);
    } catch (_) {
      return token;
    }
  }

  String _legacyEscape(String source) {
    if (source.isEmpty) return source;
    final out = StringBuffer();
    for (final code in source.codeUnits) {
      final isDigit = code >= 48 && code <= 57;
      final isUpper = code >= 65 && code <= 90;
      final isLower = code >= 97 && code <= 122;
      if (isDigit || isUpper || isLower) {
        out.writeCharCode(code);
        continue;
      }

      if (code < 16) {
        out.write('%0${code.toRadixString(16)}');
      } else if (code < 256) {
        out.write('%${code.toRadixString(16)}');
      } else {
        out.write('%u${code.toRadixString(16)}');
      }
    }
    return out.toString();
  }

  String _encodeParamToken(
    String token, {
    required String normalizedCharset,
    required bool checkEncoded,
    required bool isQuery,
  }) {
    if (token.isEmpty) return token;

    if (checkEncoded) {
      final already = _containsPercentTriplet(token) || (!isQuery && token.contains('+'));
      if (already) return token;
    }

    var source = token;
    if (!checkEncoded) {
      source = _decodeMaybePercentEncoded(token, formStyle: !isQuery);
    }

    if (normalizedCharset == 'escape') {
      return _legacyEscape(source);
    }

    final bytes =
        normalizedCharset == 'gbk' ? gbk.encode(source) : utf8.encode(source);
    return _percentEncodeBytes(bytes, spaceAsPlus: !isQuery);
  }

  String _encodeParamsText(
    String params,
    String? optionCharset, {
    required bool isQuery,
  }) {
    final text = params.trim();
    if (text.isEmpty) return '';

    final normalizedCharset = _normalizeCharset(optionCharset ?? '');
    final checkEncoded = normalizedCharset.isEmpty;

    final out = <String>[];
    for (final part in text.split('&')) {
      if (part.isEmpty) {
        out.add('');
        continue;
      }
      final idx = part.indexOf('=');
      if (idx < 0) {
        out.add(
          _encodeParamToken(
            part,
            normalizedCharset: normalizedCharset,
            checkEncoded: checkEncoded,
            isQuery: isQuery,
          ),
        );
        continue;
      }

      final key = part.substring(0, idx);
      final value = part.substring(idx + 1);
      final encodedKey = _encodeParamToken(
        key,
        normalizedCharset: normalizedCharset,
        checkEncoded: checkEncoded,
        isQuery: isQuery,
      );
      final encodedValue = _encodeParamToken(
        value,
        normalizedCharset: normalizedCharset,
        checkEncoded: checkEncoded,
        isQuery: isQuery,
      );
      out.add('$encodedKey=$encodedValue');
    }

    return out.join('&');
  }

  String _encodeUrlQueryByCharset(String url, String? optionCharset) {
    if (url.trim().isEmpty) return url;
    final hashIndex = url.indexOf('#');
    final beforeFragment = hashIndex >= 0 ? url.substring(0, hashIndex) : url;
    final fragment = hashIndex >= 0 ? url.substring(hashIndex) : '';

    final queryIndex = beforeFragment.indexOf('?');
    if (queryIndex < 0) return url;
    if (queryIndex >= beforeFragment.length - 1) {
      return '$beforeFragment$fragment';
    }

    final base = beforeFragment.substring(0, queryIndex);
    final query = beforeFragment.substring(queryIndex + 1);
    final encodedQuery = _encodeParamsText(
      query,
      optionCharset,
      isQuery: true,
    );
    return '$base?$encodedQuery$fragment';
  }

  bool _isBodyMethod(String method) {
    return method == 'POST' || method == 'PUT' || method == 'PATCH';
  }

  bool _looksLikeJsonText(String text) {
    final trimmed = text.trimLeft();
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return false;
    return _tryDecodeJsonValue(trimmed) != null;
  }

  bool _looksLikeXmlText(String text) {
    return text.trimLeft().startsWith('<');
  }

  String _charsetLabelForContentType(String normalizedCharset) {
    if (normalizedCharset.isEmpty || normalizedCharset == 'escape') {
      return 'UTF-8';
    }
    if (normalizedCharset == 'gbk') return 'GBK';
    return normalizedCharset.toUpperCase();
  }

  bool _isRetryableRequestError(Object error) {
    if (error is! DioException) return false;
    return error.type != DioExceptionType.cancel &&
        error.type != DioExceptionType.badResponse;
  }

  String? _tryParseCharsetFromContentType(String? contentType) {
    final trimmed = (contentType ?? '').trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(
      r'charset\s*=\s*([^;\s]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final value = match?.group(1);
    if (value == null) return null;
    return _normalizeCharset(value.replaceAll('"', '').replaceAll("'", ''));
  }

  String? _tryParseCharsetFromHtmlHead(Uint8List bytes) {
    final headLen = bytes.length < 4096 ? bytes.length : 4096;
    final head = latin1.decode(bytes.sublist(0, headLen), allowInvalid: true);
    final metaCharset = RegExp(
      r'''<meta[^>]+charset\s*=\s*['"]?\s*([^'"\s/>]+)''',
      caseSensitive: false,
    ).firstMatch(head)?.group(1);
    if (metaCharset != null && metaCharset.trim().isNotEmpty) {
      return _normalizeCharset(metaCharset);
    }

    final contentTypeCharset = RegExp(
      r'''<meta[^>]+http-equiv\s*=\s*['"]content-type['"][^>]+content\s*=\s*['"][^'"]*charset\s*=\s*([^'"\s;]+)''',
      caseSensitive: false,
    ).firstMatch(head)?.group(1);
    if (contentTypeCharset != null && contentTypeCharset.trim().isNotEmpty) {
      return _normalizeCharset(contentTypeCharset);
    }
    return null;
  }
}
