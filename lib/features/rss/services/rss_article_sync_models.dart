import '../models/rss_article.dart';

/// RSS 列表分页拉取结果（fetch 层）。
class RssArticleFetchResult {
  final List<RssArticle> articles;
  final String? nextPageUrl;
  final bool hasMore;
  final String? error;

  const RssArticleFetchResult({
    required this.articles,
    required this.nextPageUrl,
    required this.hasMore,
    required this.error,
  });
}

/// 一次列表浏览过程的滚动状态（页码、下一页 URL、order 游标等）。
class RssArticleSession {
  static const Object _unset = Object();

  final String sortName;
  final String sortUrl;
  final int page;
  final String? nextPageUrl;
  final int orderCursor;
  final bool hasMore;

  const RssArticleSession({
    required this.sortName,
    required this.sortUrl,
    required this.page,
    required this.nextPageUrl,
    required this.orderCursor,
    required this.hasMore,
  });

  RssArticleSession copyWith({
    String? sortName,
    String? sortUrl,
    int? page,
    Object? nextPageUrl = _unset,
    int? orderCursor,
    bool? hasMore,
  }) {
    return RssArticleSession(
      sortName: sortName ?? this.sortName,
      sortUrl: sortUrl ?? this.sortUrl,
      page: page ?? this.page,
      nextPageUrl: identical(nextPageUrl, _unset)
          ? this.nextPageUrl
          : nextPageUrl as String?,
      orderCursor: orderCursor ?? this.orderCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 下拉刷新结果（清理 + 入库 + 新会话）。
class RssArticleRefreshResult {
  final RssArticleSession session;
  final List<RssArticle> articles;
  final String? error;

  const RssArticleRefreshResult({
    required this.session,
    required this.articles,
    required this.error,
  });
}

/// 触底加载更多结果（追加+新会话）。
class RssArticleLoadMoreResult {
  final RssArticleSession session;
  final List<RssArticle> appendedArticles;
  final String? error;

  const RssArticleLoadMoreResult({
    required this.session,
    required this.appendedArticles,
    required this.error,
  });
}
