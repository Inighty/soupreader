import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_codec_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_types.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_url_support.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineCoverSupport {
  RuleParserEngineCoverSupport(this._ctx);

  final RuleParserContext _ctx;

  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
  String _evalJsMaybeString({
    required String js,
    String? jsLib,
    Map<String, Object?> bindings = const {},
  }) =>
      _ctx.jsSupport
          .evalJsMaybeString(js: js, jsLib: jsLib, bindings: bindings);
  Future<void> _mergeSourceLoginHeaders(
    Map<String, String> headers,
    String? sourceKey,
  ) =>
      _ctx.fetchSupport.mergeSourceLoginHeaders(headers, sourceKey);
  Map<String, String> _buildEffectiveRequestHeaders(
    String url, {
    required Map<String, String> customHeaders,
  }) =>
      _ctx.requestLifecycleSupport
          .buildEffectiveRequestHeaders(url, customHeaders: customHeaders);
  void _applyPreferredOriginHeaders(
    Map<String, String> headers,
    String? originText,
  ) =>
      _ctx.requestLifecycleSupport
          .applyPreferredOriginHeaders(headers, originText);
  Future<ConcurrentAcquireResult> _acquireConcurrentRatePermit({
    required String? sourceKey,
    required String? concurrentRate,
  }) =>
      _ctx.requestLifecycleSupport.acquireConcurrentRatePermit(
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
      );
  void _releaseConcurrentRatePermit(ConcurrentRecord? record) =>
      _ctx.requestLifecycleSupport.releaseConcurrentRatePermit(record);
  Dio _selectDio({bool? enabledCookieJar}) =>
      _ctx.selectDio(enabledCookieJar: enabledCookieJar);
  RuleParserEngineRequestUrlSupport get _requestUrlSupport =>
      _ctx.requestUrlSupport;
  RuleParserEngineRequestCodecSupport get _requestCodecSupport =>
      _ctx.requestCodecSupport;

  Future<Uint8List?> fetchCoverBytes({
    required BookSource source,
    required String imageUrl,
  }) async {
    final rawImageUrl = imageUrl.trim();
    if (rawImageUrl.isEmpty) return null;

    final requestUrl = _absoluteUrl(source.bookSourceUrl, rawImageUrl);
    final parsedHeaders = _requestUrlSupport.parseRequestHeaders(
      source.header,
      jsLib: source.jsLib,
    );
    final parsedUrl = _requestUrlSupport.parseLegadoStyleUrl(requestUrl);
    final mergedCustomHeaders = <String, String>{}
      ..addAll(parsedHeaders.headers);
    await _mergeSourceLoginHeaders(mergedCustomHeaders, source.bookSourceUrl);
    mergedCustomHeaders
        .addAll(parsedUrl.option?.headers ?? const <String, String>{});

    var finalUrl = parsedUrl.url;
    if (parsedUrl.option?.js != null &&
        parsedUrl.option!.js!.trim().isNotEmpty) {
      final patched = _requestUrlSupport.applyLegadoUrlOptionJs(
        js: parsedUrl.option!.js!.trim(),
        url: finalUrl,
        headerMap: mergedCustomHeaders,
      );
      if (patched != null) {
        finalUrl = patched.url;
        mergedCustomHeaders
          ..clear()
          ..addAll(patched.headers);
      }
    }

    _applyPreferredOriginHeaders(mergedCustomHeaders, parsedUrl.option?.origin);
    final requestHeaders = _buildEffectiveRequestHeaders(
      finalUrl,
      customHeaders: mergedCustomHeaders,
    );
    final normalized = _requestCodecSupport.normalizeRequestPayload(
      finalUrl,
      parsedUrl.option,
      requestHeaders,
    );
    final timeout = source.respondTime > 0
        ? Duration(milliseconds: source.respondTime)
        : const Duration(seconds: 15);
    final options = Options(
      method: normalized.method,
      connectTimeout: timeout,
      sendTimeout: timeout,
      receiveTimeout: timeout,
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
      headers: requestHeaders,
    );

    final permit = await _acquireConcurrentRatePermit(
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    late ({Response<List<int>> response, int retryCount}) requestResult;
    try {
      requestResult = await _requestCodecSupport.requestBytesWithRetry(
        dio: _selectDio(enabledCookieJar: source.enabledCookieJar),
        url: normalized.url,
        options: options,
        method: normalized.method,
        body: normalized.body,
        retry: normalized.retry,
      );
    } finally {
      _releaseConcurrentRatePermit(permit.record);
    }

    final response = requestResult.response;
    if ((response.statusCode ?? 0) >= 400) return null;
    final bytes = Uint8List.fromList(response.data ?? const <int>[]);
    if (bytes.isEmpty) return null;
    return _applyCoverDecodeJs(
      source: source,
      src: response.realUri.toString(),
      bytes: bytes,
    );
  }

  Uint8List? _applyCoverDecodeJs({
    required BookSource source,
    required String src,
    required Uint8List bytes,
  }) {
    final ruleJs = (source.coverDecodeJs ?? '').trim();
    if (ruleJs.isEmpty) return bytes;

    final output = _evalJsMaybeString(
      js: ruleJs,
      jsLib: source.jsLib,
      bindings: <String, Object?>{
        'src': src,
        'result': base64Encode(bytes),
      },
    ).trim();
    if (output.isEmpty) return null;
    return _parseDecodedImageBytes(output);
  }

  Uint8List? _parseDecodedImageBytes(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final dataUrlPrefix = RegExp(r'^data:[^;]+;base64,', caseSensitive: false);
    final dataUrlMatch = dataUrlPrefix.firstMatch(text);
    if (dataUrlMatch != null) {
      return _decodeBase64Bytes(text.substring(dataUrlMatch.end));
    }

    final base64Bytes = _decodeBase64Bytes(text);
    if (base64Bytes != null && base64Bytes.isNotEmpty) return base64Bytes;
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        final bytes = <int>[];
        for (final item in decoded) {
          if (item is! num) return null;
          bytes.add(item.toInt().clamp(0, 255));
        }
        return bytes.isEmpty ? null : Uint8List.fromList(bytes);
      }
    } catch (_) {}
    return null;
  }

  Uint8List? _decodeBase64Bytes(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    text = text.replaceAll(RegExp(r'\s+'), '');
    text = text.replaceAll('-', '+').replaceAll('_', '/');
    final rem = text.length % 4;
    if (rem != 0) {
      text = text.padRight(text.length + (4 - rem), '=');
    }
    try {
      return Uint8List.fromList(base64Decode(text));
    } catch (_) {
      return null;
    }
  }
}
