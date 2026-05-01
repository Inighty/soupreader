import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_codec_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineFetchDebugFailureSupport {
  RuleParserEngineFetchDebugFailureSupport(this._ctx);

  final RuleParserContext _ctx;

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

  FetchDebugResult buildFailedFetchDebugResult({
    required LegadoUrlParsed parsedUrl,
    required ParsedHeaders parsedHeaders,
    required String? optionCharset,
    required String method,
    required dynamic body,
    required int retryCount,
    required String methodDecision,
    required String retryDecision,
    required String requestCharsetDecision,
    required String bodyEncoding,
    required String bodyDecision,
    required int concurrentWaitMs,
    required String concurrentDecision,
    required Object error,
    required String? loginCheckJs,
    required String? jsLib,
    required Map<String, String> requestHeadersForLog,
    required int elapsedMs,
  }) {
    if (error is DioException) {
      final response = error.response;
      final finalUrl = response?.realUri.toString();
      final responseHeaders = response?.headers.map.map(
            (key, value) => MapEntry(key, value.join(', ')),
          ) ??
          const <String, String>{};
      String? bodyText;
      String? responseCharset;
      String? responseCharsetSource;
      String? responseCharsetDecision;
      if (response?.data is List<int>) {
        final decoded = _requestCodecSupport.decodeResponseBytes(
          bytes: Uint8List.fromList(response?.data ?? const <int>[]),
          responseHeaders: responseHeaders,
          optionCharset: optionCharset,
        );
        bodyText = _applyStageResponseJs(
          responseText: decoded.text,
          jsRule: loginCheckJs,
          currentUrl: (finalUrl != null && finalUrl.trim().isNotEmpty)
              ? finalUrl.trim()
              : parsedUrl.url,
          jsLib: jsLib,
          stageLabel: 'loginCheckJs',
        );
        responseCharset = decoded.charset;
        responseCharsetSource = decoded.charsetSource;
        responseCharsetDecision = decoded.charsetDecision;
      } else {
        bodyText = response?.data?.toString();
      }

      final parts = <String>[
        'DioException(${error.type})',
        if (parsedHeaders.warning != null) 'header警告=${parsedHeaders.warning}',
        if (retryCount > 0) 'retry=$retryCount',
        if (error.message != null && error.message!.trim().isNotEmpty)
          error.message!.trim(),
        if (error.error != null) 'error=${error.error}',
      ];
      return FetchDebugResult(
        requestUrl: parsedUrl.url,
        finalUrl: finalUrl,
        statusCode: response?.statusCode,
        elapsedMs: elapsedMs,
        isRedirect: (response?.redirects.isNotEmpty ?? false) ||
            (response?.isRedirect ?? false),
        method: method,
        requestBodySnippet: _snippet(body),
        responseCharset: responseCharset,
        responseLength: bodyText?.length ?? 0,
        responseSnippet: _snippet(bodyText),
        requestHeaders: requestHeadersForLog,
        headersWarning: parsedHeaders.warning,
        responseHeaders: responseHeaders,
        error: parts.join('：'),
        retryCount: retryCount,
        methodDecision: methodDecision,
        retryDecision: retryDecision,
        requestCharsetDecision: requestCharsetDecision,
        bodyEncoding: bodyEncoding,
        bodyDecision: bodyDecision,
        responseCharsetSource: responseCharsetSource,
        responseCharsetDecision: responseCharsetDecision,
        concurrentWaitMs: concurrentWaitMs,
        concurrentDecision: concurrentDecision,
        body: bodyText,
      );
    }

    return FetchDebugResult(
      requestUrl: parsedUrl.url,
      finalUrl: null,
      statusCode: null,
      elapsedMs: elapsedMs,
      isRedirect: false,
      method: method,
      requestBodySnippet: _snippet(body),
      responseCharset: null,
      responseLength: 0,
      responseSnippet: null,
      requestHeaders: requestHeadersForLog,
      headersWarning: parsedHeaders.warning,
      responseHeaders: const <String, String>{},
      error: error.toString(),
      retryCount: retryCount,
      methodDecision: methodDecision,
      retryDecision: retryDecision,
      requestCharsetDecision: requestCharsetDecision,
      bodyEncoding: bodyEncoding,
      bodyDecision: bodyDecision,
      responseCharsetSource: null,
      responseCharsetDecision: null,
      concurrentWaitMs: concurrentWaitMs,
      concurrentDecision: concurrentDecision,
      body: null,
    );
  }

  String? _snippet(dynamic text) {
    final raw = text?.toString();
    if (raw == null) return null;
    final normalized = raw.replaceAll('\r\n', '\n');
    return normalized.length <= 1200 ? normalized : normalized.substring(0, 1200);
  }
}
