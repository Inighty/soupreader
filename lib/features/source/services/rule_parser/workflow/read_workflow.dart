import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_info_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/content_support.dart';
import 'package:soupreader/features/source/services/rule_parser/fetch/cover_support.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/toc_debug_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/toc_support.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineReadWorkflowSupport {
  RuleParserEngineReadWorkflowSupport(this._ctx);

  final RuleParserContext _ctx;

  void _clearRuntimeVariables() => _ctx.runtimeSupport.clearRuntimeVariables();
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
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
  RuleParserEngineBookInfoSupport get _bookInfoSupport => _ctx.bookInfoSupport;
  RuleParserEngineTocSupport get _tocSupport => _ctx.tocSupport;
  RuleParserEngineTocDebugSupport get _tocDebugSupport => _ctx.tocDebugSupport;
  RuleParserEngineContentSupport get _contentSupport => _ctx.contentSupport;
  RuleParserEngineCoverSupport get _coverSupport => _ctx.coverSupport;

  Future<BookDetail?> getBookInfo(
    BookSource source,
    String bookUrl, {
    bool clearRuntimeVariables = true,
    CancelToken? cancelToken,
  }) async {
    if (clearRuntimeVariables) _clearRuntimeVariables();
    if (source.ruleBookInfo == null) return null;

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
      var parseBaseUrl = fullUrl;
      final response = await _fetch(
        fullUrl,
        header: source.header,
        jsLib: source.jsLib,
        loginCheckJs: source.loginCheckJs,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
        cancelToken: cancelToken,
        onFinalUrl: (finalUrl) {
          if (finalUrl.trim().isNotEmpty) parseBaseUrl = finalUrl.trim();
        },
      );
      if (response == null) return null;
      return _bookInfoSupport.parseBookInfoLikeLegado(
        source: source,
        requestUrl: fullUrl,
        responseUrl: parseBaseUrl,
        body: response,
      );
    } catch (e, st) {
      debugPrint('获取书籍详情失败: $e');
      ExceptionLogService().record(
        node: 'source.bookInfo',
        message: '详情解析失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
          'bookUrl': bookUrl,
        },
      );
      return null;
    }
  }

  Future<BookInfoDebugResult> getBookInfoDebug(
    BookSource source,
    String bookUrl,
  ) async {
    if (source.ruleBookInfo == null) {
      return BookInfoDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: null,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: 'ruleBookInfo 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      jsLib: source.jsLib,
      loginCheckJs: source.loginCheckJs,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    if (fetch.body == null) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: source.ruleBookInfo?.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    final parseBaseUrl =
        (fetch.finalUrl == null || fetch.finalUrl!.trim().isEmpty)
            ? fullUrl
            : fetch.finalUrl!.trim();
    try {
      final outcome = _bookInfoSupport.analyzeBookInfoDebugLikeLegado(
        source: source,
        requestUrl: fullUrl,
        responseUrl: parseBaseUrl,
        body: fetch.body!,
      );
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: outcome.initRule,
        initMatched: outcome.initMatched,
        detail: outcome.detail,
        fieldSample: outcome.fieldSample,
        error: outcome.error,
      );
    } catch (e) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: source.ruleBookInfo?.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  Future<List<TocItem>> getToc(
    BookSource source,
    String tocUrl, {
    bool clearRuntimeVariables = true,
    CancelToken? cancelToken,
  }) async {
    if (clearRuntimeVariables) _clearRuntimeVariables();
    try {
      return _tocSupport.getToc(source, tocUrl, cancelToken: cancelToken);
    } catch (e, st) {
      debugPrint('获取目录失败: $e');
      ExceptionLogService().record(
        node: 'source.toc',
        message: '目录解析失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
          'tocUrl': tocUrl,
        },
      );
      return [];
    }
  }

  Future<TocDebugResult> getTocDebug(BookSource source, String tocUrl) async {
    try {
      return _tocDebugSupport.getTocDebug(source, tocUrl);
    } catch (e) {
      return TocDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: source.ruleToc?.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  Future<String> getContent(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
    bool clearRuntimeVariables = true,
    CancelToken? cancelToken,
  }) async {
    if (clearRuntimeVariables) _clearRuntimeVariables();
    try {
      return _contentSupport.getContent(
        source,
        chapterUrl,
        nextChapterUrl: nextChapterUrl,
        cancelToken: cancelToken,
      );
    } catch (e, st) {
      debugPrint('获取正文失败: $e');
      ExceptionLogService().record(
        node: 'source.content',
        message: '正文解析失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
          'chapterUrl': chapterUrl,
          'nextChapterUrl': nextChapterUrl,
        },
      );
      return '';
    }
  }

  Future<ContentDebugResult> getContentDebug(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
  }) async {
    try {
      return _contentSupport.getContentDebug(
        source,
        chapterUrl,
        nextChapterUrl: nextChapterUrl,
      );
    } catch (e) {
      return ContentDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: '解析失败: $e',
      );
    }
  }

  Future<Uint8List?> fetchCoverBytes({
    required BookSource source,
    required String imageUrl,
  }) async {
    try {
      return _coverSupport.fetchCoverBytes(source: source, imageUrl: imageUrl);
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'source.cover',
        message: '封面请求失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
          'imageUrl': imageUrl,
        },
      );
      return null;
    }
  }
}
