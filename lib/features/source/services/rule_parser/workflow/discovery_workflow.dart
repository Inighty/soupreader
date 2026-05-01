import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_list_support.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineDiscoveryWorkflowSupport {
  RuleParserEngineDiscoveryWorkflowSupport(this._ctx);

  final RuleParserContext _ctx;

  void _clearRuntimeVariables() => _ctx.runtimeSupport.clearRuntimeVariables();
  ResolvedBookListRule? _resolveBookListRuleForStage(
    BookSource source, {
    required bool isSearch,
  }) =>
      _ctx.requestLifecycleSupport
          .resolveBookListRuleForStage(source, isSearch: isSearch);
  String _buildUrl(
    String baseUrl,
    String rule,
    Map<String, String> params, {
    String? jsLib,
  }) =>
      _ctx.urlBuildSupport.buildUrl(baseUrl, rule, params, jsLib: jsLib);
  Future<String?> _fetch(
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
  }) =>
      _ctx.fetchSupport.fetch(
        url,
        header: header,
        jsLib: jsLib,
        loginCheckJs: loginCheckJs,
        timeoutMs: timeoutMs,
        enabledCookieJar: enabledCookieJar,
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
        cancelToken: cancelToken,
        onFinalUrl: onFinalUrl,
        onIsRedirect: onIsRedirect,
      );
  Future<FetchDebugResult> _fetchDebug(
    String url, {
    String? header,
    String? jsLib,
    String? loginCheckJs,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
    CancelToken? cancelToken,
  }) =>
      _ctx.fetchSupport.fetchDebug(
        url,
        header: header,
        jsLib: jsLib,
        loginCheckJs: loginCheckJs,
        timeoutMs: timeoutMs,
        enabledCookieJar: enabledCookieJar,
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
        cancelToken: cancelToken,
      );
  BookListAnalyzeOutcome _analyzeBookListLikeLegado({
    required BookSource source,
    required BookListRule rule,
    required String requestUrl,
    required String responseUrl,
    required bool isRedirect,
    required String body,
    required bool isSearch,
    bool Function(String name, String author)? filter,
    bool Function(int size)? shouldBreak,
    void Function(String msg)? onLog,
  }) =>
      _ctx.bookListSupport.analyzeBookListLikeLegado(
        source: source,
        rule: rule,
        requestUrl: requestUrl,
        responseUrl: responseUrl,
        isRedirect: isRedirect,
        body: body,
        isSearch: isSearch,
        filter: filter,
        shouldBreak: shouldBreak,
        onLog: onLog,
      );

  Future<List<SearchResult>> search(
    BookSource source,
    String keyword, {
    int page = 1,
    bool Function(String name, String author)? filter,
    bool Function(int size)? shouldBreak,
    CancelToken? cancelToken,
  }) async {
    _clearRuntimeVariables();
    final resolved = _resolveBookListRuleForStage(source, isSearch: true);
    final searchUrlRule = source.searchUrl;
    if (resolved == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return [];
    }

    try {
      final searchUrl = _buildUrl(
        source.bookSourceUrl,
        searchUrlRule,
        {'key': keyword, 'searchKey': keyword, 'page': '$page'},
        jsLib: source.jsLib,
      );
      var responseUrl = searchUrl;
      var isRedirect = false;
      final response = await _fetch(
        searchUrl,
        header: source.header,
        jsLib: source.jsLib,
        loginCheckJs: source.loginCheckJs,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
        cancelToken: cancelToken,
        onFinalUrl: (finalUrl) {
          if (finalUrl.trim().isNotEmpty) responseUrl = finalUrl.trim();
        },
        onIsRedirect: (redirected) => isRedirect = redirected,
      );
      if (response == null) return [];
      return _analyzeBookListLikeLegado(
        source: source,
        rule: resolved.rule,
        requestUrl: searchUrl,
        responseUrl: responseUrl,
        isRedirect: isRedirect,
        body: response,
        isSearch: true,
        filter: filter,
        shouldBreak: shouldBreak,
      ).results;
    } catch (e, st) {
      debugPrint('搜索失败: $e');
      ExceptionLogService().record(
        node: 'source.search',
        message: '搜索解析失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
          'keyword': keyword,
          'page': page,
        },
      );
      return [];
    }
  }

  Future<SearchDebugResult> searchDebug(
    BookSource source,
    String keyword, {
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    final resolved = _resolveBookListRuleForStage(source, isSearch: true);
    final searchUrlRule = source.searchUrl;
    if (resolved == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return SearchDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: resolved?.rule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'searchUrl / ruleSearch 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      searchUrlRule,
      {'key': keyword, 'searchKey': keyword, 'page': '$page'},
      jsLib: source.jsLib,
    );
    final fetch = await _fetchDebug(
      requestUrl,
      header: source.header,
      jsLib: source.jsLib,
      loginCheckJs: source.loginCheckJs,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
      cancelToken: cancelToken,
    );
    if (fetch.body == null) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: resolved.rule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final responseUrl =
          (fetch.finalUrl == null || fetch.finalUrl!.trim().isEmpty)
              ? requestUrl
              : fetch.finalUrl!.trim();
      final outcome = _analyzeBookListLikeLegado(
        source: source,
        rule: resolved.rule,
        requestUrl: requestUrl,
        responseUrl: responseUrl,
        isRedirect: fetch.isRedirect,
        body: fetch.body!,
        isSearch: true,
      );
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: outcome.listRuleRaw,
        listCount: outcome.listCount,
        results: outcome.results,
        fieldSample: outcome.fieldSample,
        error: null,
      );
    } catch (e) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: resolved.rule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  Future<List<SearchResult>> explore(
    BookSource source, {
    String? exploreUrlOverride,
    int page = 1,
  }) async {
    _clearRuntimeVariables();
    final resolved = _resolveBookListRuleForStage(source, isSearch: false);
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (resolved == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return [];
    }

    try {
      final exploreUrl = _buildUrl(
        source.bookSourceUrl,
        exploreUrlRule,
        <String, String>{'page': '$page'},
        jsLib: source.jsLib,
      );
      var responseUrl = exploreUrl;
      var isRedirect = false;
      final response = await _fetch(
        exploreUrl,
        header: source.header,
        jsLib: source.jsLib,
        loginCheckJs: source.loginCheckJs,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
        onFinalUrl: (finalUrl) {
          if (finalUrl.trim().isNotEmpty) responseUrl = finalUrl.trim();
        },
        onIsRedirect: (redirected) => isRedirect = redirected,
      );
      if (response == null) return [];
      return _analyzeBookListLikeLegado(
        source: source,
        rule: resolved.rule,
        requestUrl: exploreUrl,
        responseUrl: responseUrl,
        isRedirect: isRedirect,
        body: response,
        isSearch: false,
      ).results;
    } catch (e, st) {
      debugPrint('发现失败: $e');
      ExceptionLogService().record(
        node: 'source.explore',
        message: '发现解析失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
          'exploreUrl': exploreUrlOverride ?? source.exploreUrl,
        },
      );
      return [];
    }
  }

  Future<ExploreDebugResult> exploreDebug(
    BookSource source, {
    String? exploreUrlOverride,
    CancelToken? cancelToken,
  }) async {
    final resolved = _resolveBookListRuleForStage(source, isSearch: false);
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (resolved == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return ExploreDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: resolved?.rule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'exploreUrl / ruleExplore 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      exploreUrlRule,
      const {},
      jsLib: source.jsLib,
    );
    final fetch = await _fetchDebug(
      requestUrl,
      header: source.header,
      jsLib: source.jsLib,
      loginCheckJs: source.loginCheckJs,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
      cancelToken: cancelToken,
    );
    if (fetch.body == null) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: resolved.rule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final responseUrl =
          (fetch.finalUrl == null || fetch.finalUrl!.trim().isEmpty)
              ? requestUrl
              : fetch.finalUrl!.trim();
      final outcome = _analyzeBookListLikeLegado(
        source: source,
        rule: resolved.rule,
        requestUrl: requestUrl,
        responseUrl: responseUrl,
        isRedirect: fetch.isRedirect,
        body: fetch.body!,
        isSearch: false,
      );
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: outcome.listRuleRaw,
        listCount: outcome.listCount,
        results: outcome.results,
        fieldSample: outcome.fieldSample,
        error: null,
      );
    } catch (e) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: resolved.rule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }
}
