import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';

import 'package:soupreader/core/services/cookie_store.dart';
import 'package:soupreader/core/services/js_runtime.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

export 'package:soupreader/features/source/services/rule_parser/models.dart';

/// 规则解析引擎：书源相关搜索 / 详情 / 目录 / 正文 / 封面 / 调试入口。
///
/// 内部装配下沉到 [RuleParserContext]，本类仅做：
/// - 暴露公开异步 API（透传至 ctx 中对应 workflow / fetch support）
/// - 维护引擎级共享状态（cookies / dio / jsRuntime / runtime variables）
/// - 暴露 `@visibleForTesting` 钩子供单测直接访问内部 support
class RuleParserEngine {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Upgrade-Insecure-Requests': '1',
  };
  static final RegExp _httpHeaderTokenRegex =
      RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");
  static final Dio _dioPlain = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: _defaultHeaders,
      followRedirects: true,
      maxRedirects: 8,
    ),
  );
  static final Map<String, ConcurrentRecord> _concurrentRecordMap =
      <String, ConcurrentRecord>{};

  static CookieJar get _cookieJar => CookieStore.jar;
  static Dio? _dioCookieInstance;
  static JsRuntime? _jsRuntimeInstance;
  static Dio get _dioCookie {
    final existing = _dioCookieInstance;
    if (existing != null) return existing;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: _defaultHeaders,
        followRedirects: true,
        maxRedirects: 8,
      ),
    )..interceptors.add(CookieManager(_cookieJar));
    _dioCookieInstance = dio;
    return dio;
  }

  static JsRuntime get _jsRuntime => _jsRuntimeInstance ??= createJsRuntime();

  final _runtimeVariables = <String, String>{};
  final _bookInfoTocHtmlCache = <String, String>{};
  late final RuleParserContext _ctx;

  RuleParserEngine() {
    _ctx = RuleParserContext(
      runtimeVariables: _runtimeVariables,
      bookInfoTocHtmlCache: _bookInfoTocHtmlCache,
      defaultHeaders: _defaultHeaders,
      httpHeaderTokenRegex: _httpHeaderTokenRegex,
      concurrentRecordMap: _concurrentRecordMap,
      runtimeEvaluate: (script) => _jsRuntime.evaluate(script),
      tryDecodeJsonValue: _tryDecodeJsonValue,
      normalizeListRule: _normalizeListRule,
      selectDio: _selectDio,
      loadCookiesForUrl: RuleParserEngine.loadCookiesForUrl,
    );
  }

  static dynamic _tryDecodeJsonValue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  static NormalizedListRule _normalizeListRule(String? rawRule) {
    var rule = (rawRule ?? '').trim();
    var reverse = false;
    if (rule.startsWith('-')) {
      reverse = true;
      rule = rule.substring(1);
    }
    if (rule.startsWith('+')) rule = rule.substring(1);
    return NormalizedListRule(selector: rule.trim(), reverse: reverse);
  }

  static Dio _selectDio({bool? enabledCookieJar}) {
    return (enabledCookieJar ?? true) ? _dioCookie : _dioPlain;
  }

  // ── 公开 API（discovery / read / fetch / cookie）─────────

  Future<List<SearchResult>> search(
    BookSource source,
    String keyword, {
    int page = 1,
    bool Function(String name, String author)? filter,
    bool Function(int size)? shouldBreak,
    CancelToken? cancelToken,
  }) =>
      _ctx.discoveryWorkflowSupport.search(
        source,
        keyword,
        page: page,
        filter: filter,
        shouldBreak: shouldBreak,
        cancelToken: cancelToken,
      );

  Future<void> debugRun(
    BookSource source,
    String key, {
    required void Function(SourceDebugEvent event) onEvent,
    CancelToken? cancelToken,
  }) =>
      _ctx.debugRunSupport.debugRun(
        source,
        key,
        onEvent: onEvent,
        cancelToken: cancelToken,
      );

  Future<SearchDebugResult> searchDebug(
    BookSource source,
    String keyword, {
    int page = 1,
    CancelToken? cancelToken,
  }) =>
      _ctx.discoveryWorkflowSupport.searchDebug(
        source,
        keyword,
        page: page,
        cancelToken: cancelToken,
      );

  Future<List<SearchResult>> explore(
    BookSource source, {
    String? exploreUrlOverride,
    int page = 1,
  }) =>
      _ctx.discoveryWorkflowSupport.explore(
        source,
        exploreUrlOverride: exploreUrlOverride,
        page: page,
      );

  Future<ExploreDebugResult> exploreDebug(
    BookSource source, {
    String? exploreUrlOverride,
    CancelToken? cancelToken,
  }) =>
      _ctx.discoveryWorkflowSupport.exploreDebug(
        source,
        exploreUrlOverride: exploreUrlOverride,
        cancelToken: cancelToken,
      );

  Future<BookDetail?> getBookInfo(
    BookSource source,
    String bookUrl, {
    bool clearRuntimeVariables = true,
    CancelToken? cancelToken,
  }) =>
      _ctx.readWorkflowSupport.getBookInfo(
        source,
        bookUrl,
        clearRuntimeVariables: clearRuntimeVariables,
        cancelToken: cancelToken,
      );

  Future<BookInfoDebugResult> getBookInfoDebug(
    BookSource source,
    String bookUrl,
  ) =>
      _ctx.readWorkflowSupport.getBookInfoDebug(source, bookUrl);

  Future<List<TocItem>> getToc(
    BookSource source,
    String tocUrl, {
    bool clearRuntimeVariables = true,
    CancelToken? cancelToken,
  }) =>
      _ctx.readWorkflowSupport.getToc(
        source,
        tocUrl,
        clearRuntimeVariables: clearRuntimeVariables,
        cancelToken: cancelToken,
      );

  Future<TocDebugResult> getTocDebug(BookSource source, String tocUrl) =>
      _ctx.readWorkflowSupport.getTocDebug(source, tocUrl);

  Future<String> getContent(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
    bool clearRuntimeVariables = true,
    CancelToken? cancelToken,
  }) =>
      _ctx.readWorkflowSupport.getContent(
        source,
        chapterUrl,
        nextChapterUrl: nextChapterUrl,
        clearRuntimeVariables: clearRuntimeVariables,
        cancelToken: cancelToken,
      );

  Future<ContentDebugResult> getContentDebug(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
  }) =>
      _ctx.readWorkflowSupport.getContentDebug(
        source,
        chapterUrl,
        nextChapterUrl: nextChapterUrl,
      );

  Future<Uint8List?> fetchCoverBytes({
    required BookSource source,
    required String imageUrl,
  }) =>
      _ctx.readWorkflowSupport.fetchCoverBytes(
        source: source,
        imageUrl: imageUrl,
      );

  Future<ScriptHttpResponse> fetchForLoginScript({
    required BookSource source,
    required String requestUrl,
    Map<String, String>? headerOverride,
  }) =>
      _ctx.fetchSupport.fetchForLoginScript(
        source: source,
        requestUrl: requestUrl,
        headerOverride: headerOverride,
      );

  static Future<void> saveCookiesForUrl(
      String url, List<Cookie> cookies) async {
    await CookieStore.saveFromResponse(Uri.parse(url), cookies);
  }

  static Future<List<Cookie>> loadCookiesForUrl(String url) async {
    return CookieStore.loadForRequest(Uri.parse(url));
  }

  // ── 测试钩子 ─────────────────────────────────────────────

  @visibleForTesting
  static Dio debugDioForTest({bool enabledCookieJar = false}) {
    return enabledCookieJar ? _dioCookie : _dioPlain;
  }

  @visibleForTesting
  static void debugResetConcurrentRateLimiterForTest() {
    _concurrentRecordMap.clear();
  }

  @visibleForTesting
  String debugBuildUrlForTest(
    String baseUrl,
    String rule,
    Map<String, String> params, {
    String? jsLib,
  }) =>
      _ctx.urlBuildSupport.buildUrl(baseUrl, rule, params, jsLib: jsLib);

  @visibleForTesting
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
  }) debugResolveRequestForTest(
    String baseUrl,
    String urlRule,
    Map<String, String> params, {
    String? header,
    String? jsLib,
    Map<String, String>? sourceLoginHeaders,
  }) =>
          _ctx.urlBuildSupport.debugResolveRequest(
            baseUrl,
            urlRule,
            params,
            header: header,
            jsLib: jsLib,
            sourceLoginHeaders: sourceLoginHeaders,
          );

  @visibleForTesting
  String debugResolveTocUrlLikeLegadoForTest({
    required String rawTocUrl,
    required String detailUrl,
  }) =>
      _ctx.urlBuildSupport.resolveTocUrlLikeLegado(
        rawValue: rawTocUrl,
        baseUrl: detailUrl,
      );

  @visibleForTesting
  List<Element> debugQueryAllElements(dynamic ctx, String css) =>
      _ctx.ruleQuerySupport.queryAllElements(ctx, css);

  String parseRuleForContext(dynamic ctx, String rule, String baseUrl) {
    final root = ctx is Document ? ctx.documentElement : ctx;
    return root is Element
        ? _ctx.ruleParseSupport.parseRule(root, rule, baseUrl)
        : '';
  }

  @visibleForTesting
  String debugParseRule(dynamic ctx, String rule, String baseUrl) =>
      parseRuleForContext(ctx, rule, baseUrl);

  @visibleForTesting
  List<String> debugParseStringListFromHtml(
    dynamic ctx,
    String rule,
    String baseUrl,
    bool isUrl,
  ) {
    final root = ctx is Document ? ctx.documentElement : ctx;
    return root is Element
        ? _ctx.ruleParseSupport.parseStringListFromHtml(
            root: root,
            rule: rule,
            baseUrl: baseUrl,
            isUrl: isUrl,
          )
        : const <String>[];
  }

  @visibleForTesting
  List<String> debugParseStringListFromJson(
    dynamic json,
    String rule,
    String baseUrl,
    bool isUrl,
  ) =>
      _ctx.ruleParseSupport.parseStringListFromJson(
        json: json,
        rule: rule,
        baseUrl: baseUrl,
        isUrl: isUrl,
      );

  @visibleForTesting
  void debugClearRuntimeVariables() =>
      _ctx.runtimeSupport.clearRuntimeVariables();

  @visibleForTesting
  void debugPutRuntimeVariable(String key, String value) =>
      _ctx.runtimeSupport.putRuntimeVariable(key, value);

  @visibleForTesting
  String debugGetRuntimeVariable(String key) =>
      _ctx.runtimeSupport.getRuntimeVariable(key);

  Map<String, String> debugRuntimeVariablesSnapshot({
    bool desensitize = true,
  }) =>
      _ctx.runtimeSupport.runtimeVariableSnapshot(desensitize: desensitize);

  @visibleForTesting
  String? debugPickNextUrlCandidateForTest(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrls,
    String? blockedUrl,
  }) {
    final visitedKeys = <String>{
      for (final item in visitedUrls)
        _ctx.runtimeSupport.normalizeUrlVisitKey(item),
    }..removeWhere((item) => item.isEmpty);
    final blockedKey = (blockedUrl == null || blockedUrl.trim().isEmpty)
        ? null
        : _ctx.runtimeSupport.normalizeUrlVisitKey(blockedUrl);
    return _ctx.runtimeSupport.pickNextUrlCandidate(
      candidates,
      currentUrl: currentUrl,
      visitedUrlKeys: visitedKeys,
      blockedUrlKey: blockedKey,
    );
  }

  @visibleForTesting
  ({List<String> urls, List<String> debugLines, bool hasBlockedCandidate})
      debugCollectNextUrlCandidatesWithDebugForTest(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrls,
    Set<String>? queuedUrls,
    String? blockedUrl,
  }) {
    final visitedKeys = <String>{
      for (final item in visitedUrls)
        _ctx.runtimeSupport.normalizeUrlVisitKey(item),
    }..removeWhere((item) => item.isEmpty);
    final queuedKeys = queuedUrls == null
        ? null
        : <String>{
            for (final item in queuedUrls)
              _ctx.runtimeSupport.normalizeUrlVisitKey(item),
          }..removeWhere((item) => item.isEmpty);
    final blockedKey = (blockedUrl == null || blockedUrl.trim().isEmpty)
        ? null
        : _ctx.runtimeSupport.normalizeUrlVisitKey(blockedUrl);
    return _ctx.runtimeSupport.collectNextUrlCandidatesWithDebug(
      candidates,
      currentUrl: currentUrl,
      visitedUrlKeys: visitedKeys,
      queuedUrlKeys: queuedKeys,
      blockedUrlKey: blockedKey,
    );
  }
}
