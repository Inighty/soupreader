import 'package:soupreader/features/source/services/rule_parser/js/js_template_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_codec_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_url_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/runtime_support.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineUrlBuildSupport {
  RuleParserEngineUrlBuildSupport(this._ctx);

  final RuleParserContext _ctx;

  RuleParserEngineRuntimeSupport get _runtimeSupport => _ctx.runtimeSupport;
  RuleParserEngineJsTemplateSupport get _jsTemplateSupport =>
      _ctx.jsTemplateSupport;
  RuleParserEngineRequestUrlSupport get _requestUrlSupport =>
      _ctx.requestUrlSupport;
  RuleParserEngineRequestCodecSupport get _requestCodecSupport =>
      _ctx.requestCodecSupport;
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

  String absoluteUrl(String baseUrl, String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    try {
      return Uri.parse(baseUrl).resolve(url).toString();
    } catch (_) {
      if (url.startsWith('/')) {
        final uri = Uri.tryParse(baseUrl);
        if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
          return '${uri.scheme}://${uri.host}$url';
        }
      }
      final trimmedBase =
          baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final trimmedUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$trimmedBase/$trimmedUrl';
    }
  }

  String resolveUrlFieldWithLegadoSemantics({
    required String rawValue,
    required String baseUrl,
    required bool fallbackToBaseUrlWhenEmpty,
  }) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return fallbackToBaseUrlWhenEmpty ? baseUrl : '';
    return absoluteUrl(baseUrl, trimmed).trim();
  }

  String resolveTocUrlLikeLegado({
    required String rawValue,
    required String baseUrl,
  }) {
    return resolveUrlFieldWithLegadoSemantics(
      rawValue: rawValue,
      baseUrl: baseUrl,
      fallbackToBaseUrlWhenEmpty: true,
    );
  }

  String buildUrl(
    String baseUrl,
    String rule,
    Map<String, String> params, {
    String? jsLib,
  }) {
    var resolvedRule = _runtimeSupport.replaceGetTokens(rule);
    resolvedRule = _jsTemplateSupport.applyUrlJsSegments(
      resolvedRule,
      baseUrl: baseUrl,
      params: params,
      jsLib: jsLib,
    );

    params.forEach((key, value) {
      final encoded = Uri.encodeComponent(value);
      resolvedRule = resolvedRule.replaceAll('{{$key}}', encoded);
      resolvedRule = resolvedRule.replaceAll('{$key}', encoded);
    });

    resolvedRule = _jsTemplateSupport.applyTemplateJsTokens(
      resolvedRule,
      baseUrl: baseUrl,
      jsLib: jsLib,
    );

    final splitIndex =
        _requestUrlSupport.findLegadoUrlOptionSplitIndex(resolvedRule);
    if (splitIndex <= 0) return absoluteUrl(baseUrl, resolvedRule);

    final urlPart = resolvedRule.substring(0, splitIndex).trim();
    final optionPart = resolvedRule.substring(splitIndex + 1).trim();
    if (optionPart.isEmpty) return absoluteUrl(baseUrl, urlPart);
    return '${absoluteUrl(baseUrl, urlPart)},$optionPart';
  }

  ({
    String url,
    String? method,
    String? body,
    int retry,
    Map<String, String> headers,
    String methodDecision,
    String retryDecision,
    String requestCharsetDecision,
    String bodyEncoding,
    String bodyDecision,
  }) debugResolveRequest(
    String baseUrl,
    String urlRule,
    Map<String, String> params, {
    String? header,
    String? jsLib,
    Map<String, String>? sourceLoginHeaders,
  }) {
    final builtUrl = buildUrl(baseUrl, urlRule, params, jsLib: jsLib);
    final parsedHeaders = _requestUrlSupport.parseRequestHeaders(header, jsLib: jsLib);
    final parsedUrl = _requestUrlSupport.parseLegadoStyleUrl(builtUrl);

    final mergedCustomHeaders = <String, String>{}
      ..addAll(parsedHeaders.headers)
      ..addAll(sourceLoginHeaders ?? const <String, String>{})
      ..addAll(parsedUrl.option?.headers ?? const <String, String>{});

    var finalUrl = parsedUrl.url;
    if (parsedUrl.option?.js != null && parsedUrl.option!.js!.trim().isNotEmpty) {
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

    return (
      url: normalized.url,
      method: normalized.method,
      body: normalized.body,
      retry: normalized.retry,
      headers: requestHeaders,
      methodDecision: normalized.methodDecision,
      retryDecision: normalized.retryDecision,
      requestCharsetDecision: normalized.requestCharsetDecision,
      bodyEncoding: normalized.bodyEncoding,
      bodyDecision: normalized.bodyDecision,
    );
  }
}
