import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart' show SearchResult;
import '../services/search_aggregator.dart';
import 'search_book_info_view.dart';
import 'search_view_actions.dart';
import 'search_view_engine.dart';

/// 创建一个 [SearchRunContext]，把 State 中的可变字段以闭包方式接进去。
/// 与 [runSearchPage] 协同把搜索会话的并发 worker 解耦到 [search_view_engine] 文件。
SearchRunContext buildSearchRunContext({
  required LegadoSearchAggregator aggregator,
  required Set<CancelToken> activeCancelTokens,
  required bool Function(int sessionId) isSessionActive,
  required void Function(String name) setSearchingSource,
  required void Function(SourceRunIssue issue) appendIssue,
  required void Function() incrementCompleted,
  required void Function() applyIngest,
  required String currentKeyword,
  required SearchFilterMode filterMode,
  required int concurrency,
}) {
  return SearchRunContext(
    aggregator: aggregator,
    activeCancelTokens: activeCancelTokens,
    isSessionActive: isSessionActive,
    setSearchingSource: setSearchingSource,
    appendIssue: appendIssue,
    incrementCompleted: incrementCompleted,
    applyIngest: applyIngest,
    recordIssueLog: ({
      required source,
      required page,
      required reason,
      statusCode,
      listCount,
      error,
      stackTrace,
    }) =>
        recordSearchIssueLog(
      currentKeyword: currentKeyword,
      source: source,
      page: page,
      reason: reason,
      statusCode: statusCode,
      listCount: listCount,
      error: error,
      stackTrace: stackTrace,
    ),
    currentKeyword: currentKeyword,
    filterMode: filterMode,
    concurrency: concurrency,
  );
}

/// 打开书籍详情页（含异常埋点 + 友好提示）。
Future<bool> openSearchBookInfo({
  required BuildContext context,
  required SearchResult result,
}) async {
  try {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => SearchBookInfoView(result: result),
      ),
    );
    return true;
  } catch (e, st) {
    ExceptionLogService().record(
      node: 'search.open_book_info',
      message: '打开书籍详情失败',
      error: e,
      stackTrace: st,
      context: <String, dynamic>{
        'bookName': result.name,
        'bookUrl': result.bookUrl,
        'sourceUrl': result.sourceUrl,
        'sourceName': result.sourceName,
      },
    );
    if (context.mounted) showSearchMessage(context, '打开详情失败，请稍后重试');
    return false;
  }
}
