import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/models/book_source.dart';
import '../../../core/services/exception_log_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../services/search_aggregator.dart';
import 'search_view_helpers.dart';

/// `_runSearchPage` 的轻量上下文，集中承载状态读写所需的回调；State 类负
/// 责实例化并把字段暴露出来，运行函数本身保持纯异步。
class SearchRunContext {
  SearchRunContext({
    required this.aggregator,
    required this.activeCancelTokens,
    required this.isSessionActive,
    required this.setSearchingSource,
    required this.appendIssue,
    required this.incrementCompleted,
    required this.applyIngest,
    required this.recordIssueLog,
    required this.currentKeyword,
    required this.filterMode,
    required this.concurrency,
  });

  final LegadoSearchAggregator aggregator;
  final Set<CancelToken> activeCancelTokens;
  final bool Function(int sessionId) isSessionActive;
  final void Function(String name) setSearchingSource;
  final void Function(SourceRunIssue issue) appendIssue;
  final void Function() incrementCompleted;
  final void Function() applyIngest;
  final void Function({
    required BookSource source,
    required int page,
    required String reason,
    int? statusCode,
    int? listCount,
    Object? error,
    StackTrace? stackTrace,
  }) recordIssueLog;
  final String currentKeyword;
  final SearchFilterMode filterMode;
  final int concurrency;
}

/// 多源并发搜索的核心 worker：与 legado 一致按 [concurrency] 同时跑多个书源。
Future<bool> runSearchPage({
  required int searchSessionId,
  required List<BookSource> sources,
  required int page,
  required SearchRunContext ctx,
}) async {
  if (sources.isEmpty) return false;
  var nextSourceIndex = 0;
  var pageHasAnyResult = false;
  final workerCount = sources.length < ctx.concurrency
      ? sources.length
      : ctx.concurrency;

  Future<void> runWorker() async {
    while (true) {
      if (!ctx.isSessionActive(searchSessionId)) return;
      if (nextSourceIndex >= sources.length) return;
      final source = sources[nextSourceIndex++];
      if (!ctx.isSessionActive(searchSessionId)) return;
      ctx.setSearchingSource(source.bookSourceName);

      final token = CancelToken();
      ctx.activeCancelTokens.add(token);
      try {
        final debugEngine = RuleParserEngine();
        final debugResult = await debugEngine
            .searchDebug(source, ctx.currentKeyword,
                page: page, cancelToken: token)
            .timeout(const Duration(seconds: 30));
        if (!ctx.isSessionActive(searchSessionId)) return;
        final issue = buildSearchIssueFromDebug(source, debugResult);
        if (issue != null) {
          ctx.recordIssueLog(
            source: source,
            page: page,
            reason: issue.reason,
            statusCode: debugResult.fetch.statusCode,
            listCount: debugResult.listCount,
          );
        }
        final filtered = filterSearchResultsByMode(
          incoming: debugResult.results,
          filterMode: ctx.filterMode,
          keyword: ctx.currentKeyword.trim(),
        );
        if (filtered.isNotEmpty) pageHasAnyResult = true;
        final ingestStat = ctx.aggregator.ingest(filtered);
        if (!ctx.isSessionActive(searchSessionId)) return;
        if (ingestStat.changed) ctx.applyIngest();
        if (issue != null) ctx.appendIssue(issue);
        ctx.incrementCompleted();
      } catch (e, st) {
        if (!ctx.isSessionActive(searchSessionId)) return;
        if (isSearchCanceledError(e)) {
          ctx.incrementCompleted();
          return;
        }
        if (e is TimeoutException) {
          ctx.recordIssueLog(
            source: source,
            page: page,
            reason: '请求超时（30s）',
            error: e,
            stackTrace: st,
          );
          ctx.incrementCompleted();
          return;
        }
        final reason = '搜索异常：${compactSearchReason(e.toString())}';
        ctx.recordIssueLog(
          source: source,
          page: page,
          reason: reason,
          error: e,
          stackTrace: st,
        );
        ctx.incrementCompleted();
        ctx.appendIssue(SourceRunIssue(
          sourceName: source.bookSourceName,
          reason: reason,
        ));
      } finally {
        ctx.activeCancelTokens.remove(token);
      }
    }
  }

  await Future.wait(
    List<Future<void>>.generate(workerCount, (_) => runWorker()),
  );
  return pageHasAnyResult;
}

/// 把搜索失败原因记录到 ExceptionLogService。
void recordSearchIssueLog({
  required String currentKeyword,
  required BookSource source,
  required int page,
  required String reason,
  int? statusCode,
  int? listCount,
  Object? error,
  StackTrace? stackTrace,
}) {
  ExceptionLogService().record(
    node: 'search.run_source',
    message: '书源搜索失败',
    error: error,
    stackTrace: stackTrace,
    context: <String, dynamic>{
      'keyword': currentKeyword,
      'page': page,
      'reason': reason,
      'sourceUrl': source.bookSourceUrl,
      'sourceName': source.bookSourceName,
      if (statusCode != null) 'statusCode': statusCode,
      if (listCount != null) 'listCount': listCount,
    },
  );
}
