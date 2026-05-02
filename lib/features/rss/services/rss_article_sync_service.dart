import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import 'rss_article_fetch_service.dart';
import 'rss_article_sync_models.dart';

export 'rss_article_fetch_service.dart' show RssArticleFetchService;
export 'rss_article_sync_models.dart';

/// RSS 文章抓取+入库服务（对齐 legado `Rss/RssArticlesViewModel` 语义）
class RssArticleSyncService {
  final RssArticleRepository _articleRepo;
  final RssArticleFetchService _fetchService;

  RssArticleSyncService({
    required DatabaseService db,
    RssArticleRepository? articleRepository,
    RssArticleFetchService? fetchService,
  })  : _articleRepo = articleRepository ?? RssArticleRepository(db),
        _fetchService = fetchService ?? RssArticleFetchService();

  Future<RssArticleRefreshResult> refresh({
    required RssSource source,
    required String sortName,
    required String sortUrl,
  }) async {
    final fetch = await _fetchService.fetchPage(
      source: source,
      sortName: sortName,
      sortUrl: sortUrl,
      page: 1,
    );

    var orderCursor = DateTime.now().millisecondsSinceEpoch;
    final ordered = <RssArticle>[];
    for (final article in fetch.articles) {
      ordered.add(article.copyWith(order: orderCursor--));
    }

    if (ordered.isNotEmpty) {
      await _articleRepo.insert(ordered);
    }

    final hasRuleNextPage = _hasRuleNextPage(source.ruleNextPage);
    if (hasRuleNextPage) {
      await _articleRepo.clearOld(source.sourceUrl, sortName, orderCursor);
    }

    final session = RssArticleSession(
      sortName: sortName,
      sortUrl: sortUrl,
      page: 1,
      nextPageUrl: fetch.nextPageUrl,
      orderCursor: orderCursor,
      hasMore: ordered.isNotEmpty && hasRuleNextPage,
    );

    return RssArticleRefreshResult(
      session: session,
      articles: ordered,
      error: fetch.error,
    );
  }

  Future<RssArticleLoadMoreResult> loadMore({
    required RssSource source,
    required RssArticleSession session,
  }) async {
    if (!session.hasMore) {
      return RssArticleLoadMoreResult(
        session: session,
        appendedArticles: const <RssArticle>[],
        error: null,
      );
    }
    final pageUrl = (session.nextPageUrl ?? '').trim();
    if (pageUrl.isEmpty) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(hasMore: false),
        appendedArticles: const <RssArticle>[],
        error: null,
      );
    }

    final nextPage = session.page + 1;
    final fetch = await _fetchService.fetchPage(
      source: source,
      sortName: session.sortName,
      sortUrl: pageUrl,
      page: nextPage,
    );

    if (fetch.error != null && fetch.articles.isEmpty) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(
          page: nextPage,
          nextPageUrl: fetch.nextPageUrl,
          hasMore: false,
        ),
        appendedArticles: const <RssArticle>[],
        error: fetch.error,
      );
    }

    if (fetch.articles.isEmpty) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(
          page: nextPage,
          nextPageUrl: fetch.nextPageUrl,
          hasMore: false,
        ),
        appendedArticles: const <RssArticle>[],
        error: fetch.error,
      );
    }

    final first = fetch.articles.first;
    final last = fetch.articles.last;
    final dbFirst = await _articleRepo.get(first.origin, first.link);
    final dbLast = await _articleRepo.get(last.origin, last.link);
    if (dbFirst != null && dbLast != null) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(
          page: nextPage,
          nextPageUrl: fetch.nextPageUrl,
          hasMore: false,
        ),
        appendedArticles: const <RssArticle>[],
        error: fetch.error,
      );
    }

    var orderCursor = session.orderCursor;
    final appendList = <RssArticle>[];
    for (final article in fetch.articles) {
      appendList.add(article.copyWith(order: orderCursor--));
    }
    await _articleRepo.append(appendList);

    final nextSession = session.copyWith(
      page: nextPage,
      nextPageUrl: fetch.nextPageUrl,
      orderCursor: orderCursor,
      // 对齐 legado：loadMoreSuccess 仅在“空列表/重复首尾”时置 false。
      hasMore: true,
    );

    return RssArticleLoadMoreResult(
      session: nextSession,
      appendedArticles: appendList,
      error: fetch.error,
    );
  }

  static bool _hasRuleNextPage(String? ruleNextPage) {
    return (ruleNextPage ?? '').trim().isNotEmpty;
  }
}
