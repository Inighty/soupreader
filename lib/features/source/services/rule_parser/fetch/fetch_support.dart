import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/fetch/fetch_debug_failure.dart';
import 'package:soupreader/core/services/source_login_store.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_codec_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_types.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_url_support.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineFetchSupport {
  RuleParserEngineFetchSupport(this._ctx);

  final RuleParserContext _ctx;

  RuleParserEngineRequestUrlSupport get _requestUrlSupport =>
      _ctx.requestUrlSupport;
  RuleParserEngineRequestCodecSupport get _requestCodecSupport =>
      _ctx.requestCodecSupport;
  String _applyStageResponseJs({
    required String responseText,
    required String? jsRule,
    required String currentUrl,
    String? jsLib,
    String stageLabel = '',
    void Function(String message)? onLog,
  }) =>
      _ctx.jsSupport.applyStageResponseJs(
        responseText: responseText,
        jsRule: jsRule,
        currentUrl: currentUrl,
        jsLib: jsLib,
        stageLabel: stageLabel,
        onLog: onLog,
      );
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
  Future<List<Cookie>> _loadCookiesForUrl(String url) =>
      _ctx.loadCookiesForUrl(url);
  RuleParserEngineFetchDebugFailureSupport get _fetchDebugFailureSupport =>
      _ctx.fetchDebugFailureSupport;

  Future<void> mergeSourceLoginHeaders(
    Map<String, String> headers,
    String? sourceKey,
  ) async {
    final key = (sourceKey ?? '').trim();
    if (key.isEmpty) return;

    final loginHeaders = await SourceLoginStore.getLoginHeaderMap(key);
    if (loginHeaders == null || loginHeaders.isEmpty) return;
    headers.addAll(loginHeaders);
  }

  Future<String?> fetch(
    String url, {
    String? header,
    String? jsLib,
    String? loginCheckJs,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
    CancelToken? cancelToken,
    void Function(String finalUrl)? onFinalUrl,
    void Function(bool isRedirect)? onIsRedirect,
  }) async {
    try {
      final parsedHeaders = _requestUrlSupport.parseRequestHeaders(
        header,
        jsLib: jsLib,
      );
      final parsedUrl = _requestUrlSupport.parseLegadoStyleUrl(url);
      final mergedCustomHeaders = <String, String>{}
        ..addAll(parsedHeaders.headers);
      await mergeSourceLoginHeaders(mergedCustomHeaders, sourceKey);
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
      final method = normalized.method;
      final body = normalized.body;
      final retry = normalized.retry;
      finalUrl = normalized.url;

      final timeout = (timeoutMs != null && timeoutMs > 0)
          ? Duration(milliseconds: timeoutMs)
          : null;
      final options = Options(
        method: method,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
        headers: requestHeaders,
      );

      final permit = await _acquireConcurrentRatePermit(
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
      );
      late ({Response<List<int>> response, int retryCount}) requestResult;
      final dio = _selectDio(enabledCookieJar: enabledCookieJar);
      try {
        requestResult = await _requestCodecSupport.requestBytesWithRetry(
          dio: dio,
          url: finalUrl,
          options: options,
          method: method,
          body: body,
          retry: retry,
          cancelToken: cancelToken,
        );
      } finally {
        _releaseConcurrentRatePermit(permit.record);
      }

      final response = requestResult.response;
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      final responseHeaders = response.headers.map.map(
        (key, value) => MapEntry(key, value.join(', ')),
      );
      final decoded = _requestCodecSupport.decodeResponseBytes(
        bytes: bytes,
        responseHeaders: responseHeaders,
        optionCharset: parsedUrl.option?.charset,
      );
      final finalResponseUrl = response.realUri.toString().trim();
      final redirected = response.redirects.isNotEmpty || response.isRedirect;
      onIsRedirect?.call(redirected);
      if (finalResponseUrl.isNotEmpty) {
        onFinalUrl?.call(finalResponseUrl);
      }
      return _applyStageResponseJs(
        responseText: decoded.text,
        jsRule: loginCheckJs,
        currentUrl: finalResponseUrl.isNotEmpty ? finalResponseUrl : finalUrl,
        jsLib: jsLib,
        stageLabel: 'loginCheckJs',
      );
    } catch (_) {
      return null;
    }
  }

  Future<FetchDebugResult> fetchDebug(
    String url, {
    String? header,
    String? jsLib,
    String? loginCheckJs,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
    CancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    final parsedHeaders = _requestUrlSupport.parseRequestHeaders(
      header,
      jsLib: jsLib,
    );
    final parsedUrl = _requestUrlSupport.parseLegadoStyleUrl(url);
    final mergedCustomHeaders = <String, String>{}
      ..addAll(parsedHeaders.headers);
    await mergeSourceLoginHeaders(mergedCustomHeaders, sourceKey);
    mergedCustomHeaders
        .addAll(parsedUrl.option?.headers ?? const <String, String>{});

    var finalUrl = parsedUrl.url;
    UrlJsPatchResult? urlJsPatch;
    if (parsedUrl.option?.js != null &&
        parsedUrl.option!.js!.trim().isNotEmpty) {
      urlJsPatch = _requestUrlSupport.applyLegadoUrlOptionJs(
        js: parsedUrl.option!.js!.trim(),
        url: finalUrl,
        headerMap: mergedCustomHeaders,
      );
      if (urlJsPatch != null) {
        finalUrl = urlJsPatch.url;
        mergedCustomHeaders
          ..clear()
          ..addAll(urlJsPatch.headers);
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
    final method = normalized.method;
    final body = normalized.body;
    final retry = normalized.retry;
    final methodDecision = normalized.methodDecision;
    final retryDecision = normalized.retryDecision;
    final requestCharsetDecision = normalized.requestCharsetDecision;
    final bodyEncoding = normalized.bodyEncoding;
    final bodyDecision = normalized.bodyDecision;
    final forLog = Map<String, String>.from(requestHeaders);
    final normalizedUrl = normalized.url;
    var concurrentWaitMs = 0;
    var concurrentDecision = '未启用并发率限制';

    if (enabledCookieJar ?? true) {
      try {
        final cookies = await _loadCookiesForUrl(normalizedUrl);
        if (cookies.isNotEmpty &&
            !forLog.keys.any((key) => key.toLowerCase() == 'cookie')) {
          forLog['Cookie'] =
              cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
        }
      } catch (_) {}
    }

    try {
      final contentType = _requestCodecSupport.getHeaderIgnoreCase(
        requestHeaders,
        'Content-Type',
      );
      if (contentType != null && contentType.trim().isNotEmpty) {
        forLog['Content-Type'] = contentType;
      }

      final timeout = (timeoutMs != null && timeoutMs > 0)
          ? Duration(milliseconds: timeoutMs)
          : null;
      final options = Options(
        method: method,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        validateStatus: (_) => true,
        responseType: ResponseType.bytes,
        headers: requestHeaders,
      );

      final permit = await _acquireConcurrentRatePermit(
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
      );
      concurrentWaitMs = permit.waitMs;
      concurrentDecision = permit.decision;
      late ({Response<List<int>> response, int retryCount}) requestResult;
      try {
        requestResult = await _requestCodecSupport.requestBytesWithRetry(
          dio: _selectDio(enabledCookieJar: enabledCookieJar),
          url: normalizedUrl,
          options: options,
          method: method,
          body: body,
          retry: retry,
          cancelToken: cancelToken,
        );
      } finally {
        _releaseConcurrentRatePermit(permit.record);
      }

      final response = requestResult.response;
      final responseHeaders = response.headers.map.map(
        (key, value) => MapEntry(key, value.join(', ')),
      );
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      final decoded = _requestCodecSupport.decodeResponseBytes(
        bytes: bytes,
        responseHeaders: responseHeaders,
        optionCharset: parsedUrl.option?.charset,
      );
      final responseRealUrl = response.realUri.toString().trim();
      final checkedBody = _applyStageResponseJs(
        responseText: decoded.text,
        jsRule: loginCheckJs,
        currentUrl: responseRealUrl.isNotEmpty ? responseRealUrl : normalizedUrl,
        jsLib: jsLib,
        stageLabel: 'loginCheckJs',
      );
      sw.stop();
      return FetchDebugResult(
        requestUrl: parsedUrl.url,
        finalUrl: response.realUri.toString(),
        statusCode: response.statusCode,
        elapsedMs: sw.elapsedMilliseconds,
        isRedirect: response.redirects.isNotEmpty || response.isRedirect,
        method: method,
        requestBodySnippet: _snippet(body),
        responseCharset: decoded.charset,
        responseLength: checkedBody.length,
        responseSnippet: _snippet(checkedBody),
        requestHeaders: forLog,
        headersWarning: parsedHeaders.warning,
        responseHeaders: responseHeaders,
        error: urlJsPatch?.error,
        retryCount: requestResult.retryCount,
        methodDecision: methodDecision,
        retryDecision: retryDecision,
        requestCharsetDecision: requestCharsetDecision,
        bodyEncoding: bodyEncoding,
        bodyDecision: bodyDecision,
        responseCharsetSource: decoded.charsetSource,
        responseCharsetDecision: decoded.charsetDecision,
        concurrentWaitMs: concurrentWaitMs,
        concurrentDecision: concurrentDecision,
        body: checkedBody,
      );
    } catch (error) {
      sw.stop();
      final actualError = error is RequestRetryFailure ? error.error : error;
      final actualRetryCount = error is RequestRetryFailure ? error.retryCount : retry;
      if (actualError is DioException &&
          actualError.type == DioExceptionType.cancel) {
        throw actualError;
      }
      return _fetchDebugFailureSupport.buildFailedFetchDebugResult(
        parsedUrl: parsedUrl,
        parsedHeaders: parsedHeaders,
        optionCharset: parsedUrl.option?.charset,
        method: method,
        body: body,
        retryCount: actualRetryCount,
        methodDecision: methodDecision,
        retryDecision: retryDecision,
        requestCharsetDecision: requestCharsetDecision,
        bodyEncoding: bodyEncoding,
        bodyDecision: bodyDecision,
        concurrentWaitMs: concurrentWaitMs,
        concurrentDecision: concurrentDecision,
        error: actualError,
        loginCheckJs: loginCheckJs,
        jsLib: jsLib,
        requestHeadersForLog: forLog,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }
  }

  Future<ScriptHttpResponse> fetchForLoginScript({
    required BookSource source,
    required String requestUrl,
    Map<String, String>? headerOverride,
  }) async {
    final url = requestUrl.trim();
    if (url.isEmpty) {
      return const ScriptHttpResponse(
        requestUrl: '',
        finalUrl: '',
        statusCode: 200,
        statusMessage: 'OK',
        headers: <String, String>{},
        body: '',
      );
    }

    final headerText =
        headerOverride == null ? source.header : jsonEncode(headerOverride);
    final sourceKey = headerOverride == null ? source.bookSourceUrl : null;
    final fetch = await fetchDebug(
      url,
      header: headerText,
      jsLib: source.jsLib,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: sourceKey,
      concurrentRate: source.concurrentRate,
    );
    final resolvedFinalUrl = (fetch.finalUrl ?? '').trim().isNotEmpty
        ? fetch.finalUrl!.trim()
        : fetch.requestUrl.trim();
    return ScriptHttpResponse(
      requestUrl: fetch.requestUrl,
      finalUrl: resolvedFinalUrl,
      statusCode: fetch.statusCode ?? 200,
      statusMessage: statusMessageFromCode(fetch.statusCode ?? 200),
      headers: fetch.statusCode == null
          ? const <String, String>{}
          : fetch.responseHeaders,
      body: fetch.body ?? fetch.error ?? '',
    );
  }

  String statusMessageFromCode(int code) {
    switch (code) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 202:
        return 'Accepted';
      case 204:
        return 'No Content';
      case 301:
        return 'Moved Permanently';
      case 302:
        return 'Found';
      case 303:
        return 'See Other';
      case 307:
        return 'Temporary Redirect';
      case 308:
        return 'Permanent Redirect';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 405:
        return 'Method Not Allowed';
      case 408:
        return 'Request Timeout';
      case 409:
        return 'Conflict';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Internal Server Error';
      case 501:
        return 'Not Implemented';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      case 504:
        return 'Gateway Timeout';
      default:
        return 'HTTP $code';
    }
  }

  String? _snippet(dynamic text) {
    final raw = text?.toString();
    if (raw == null) return null;
    final normalized = raw.replaceAll('\r\n', '\n');
    return normalized.length <= 1200
        ? normalized
        : normalized.substring(0, 1200);
  }

}
