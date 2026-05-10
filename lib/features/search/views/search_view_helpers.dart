import 'package:dio/dio.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/models.dart';
import '../services/search_aggregator.dart';

/// 把多行 + 多余空白合并为单行并截断到 [maxLength]，便于在 1 行展示原因。
String compactSearchReason(String text, {int maxLength = 96}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength)}…';
}

/// 从 [SearchDebugResult] 推断本次书源是否需要记录失败原因。
SourceRunIssue? buildSearchIssueFromDebug(
  BookSource source,
  SearchDebugResult debugResult,
) {
  final explicitError = (debugResult.error ?? '').trim();
  if (explicitError.isNotEmpty) {
    return SourceRunIssue(
      sourceName: source.bookSourceName,
      reason: compactSearchReason(explicitError),
    );
  }
  final statusCode = debugResult.fetch.statusCode;
  if (statusCode != null && statusCode >= 400) {
    final detail = compactSearchReason(
      debugResult.fetch.error ?? 'HTTP $statusCode',
    );
    return SourceRunIssue(
      sourceName: source.bookSourceName,
      reason: '请求失败（HTTP $statusCode）：$detail',
    );
  }
  if (debugResult.fetch.body != null &&
      debugResult.listCount > 0 &&
      debugResult.results.isEmpty) {
    return SourceRunIssue(
      sourceName: source.bookSourceName,
      reason: '解析到列表 ${debugResult.listCount} 项，但缺少 name/bookUrl',
    );
  }
  return null;
}

bool isSearchCanceledError(Object error) =>
    error is DioException && error.type == DioExceptionType.cancel;

/// 根据当前过滤模式过滤搜索结果。
List<SearchResult> filterSearchResultsByMode({
  required List<SearchResult> incoming,
  required SearchFilterMode filterMode,
  required String keyword,
}) {
  switch (filterMode) {
    case SearchFilterMode.none:
    case SearchFilterMode.normal:
      return incoming;
    case SearchFilterMode.precise:
      if (keyword.isEmpty) return incoming;
      return incoming
          .where((item) =>
              item.name.contains(keyword) || item.author.contains(keyword))
          .toList(growable: false);
  }
}
