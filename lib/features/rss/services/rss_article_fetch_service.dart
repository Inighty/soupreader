import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import 'rss_article_sync_models.dart';
import 'rss_default_xml_parser.dart';

/// 抽象 RSS 列表抓取网关，方便注入测试替身。
abstract class RssArticleRuleGateway {
  const RssArticleRuleGateway();

  Future<SearchDebugResult> searchDebug({
    required BookSource source,
    required String keyword,
    required int page,
  });

  Future<BookInfoDebugResult> getBookInfoDebug({
    required BookSource source,
    required String bookUrl,
  });

  Future<ScriptHttpResponse> fetchForLoginScript({
    required BookSource source,
    required String requestUrl,
  });
}

/// 默认实现：通过 RuleParserEngine 完成抓取与调试调用。
class RuleParserEngineRssArticleGateway implements RssArticleRuleGateway {
  final RuleParserEngine _engine;

  RuleParserEngineRssArticleGateway({
    RuleParserEngine? engine,
  }) : _engine = engine ?? RuleParserEngine();

  @override
  Future<SearchDebugResult> searchDebug({
    required BookSource source,
    required String keyword,
    required int page,
  }) {
    return _engine.searchDebug(
      source,
      keyword,
      page: page,
    );
  }

  @override
  Future<BookInfoDebugResult> getBookInfoDebug({
    required BookSource source,
    required String bookUrl,
  }) {
    return _engine.getBookInfoDebug(source, bookUrl);
  }

  @override
  Future<ScriptHttpResponse> fetchForLoginScript({
    required BookSource source,
    required String requestUrl,
  }) {
    return _engine.fetchForLoginScript(
      source: source,
      requestUrl: requestUrl,
    );
  }
}

/// RSS 列表分页抓取服务（无入库副作用）。
class RssArticleFetchService {
  final RssArticleRuleGateway _gateway;

  RssArticleFetchService({
    RssArticleRuleGateway? gateway,
  }) : _gateway = gateway ?? RuleParserEngineRssArticleGateway();

  Future<RssArticleFetchResult> fetchPage({
    required RssSource source,
    required String sortName,
    required String sortUrl,
    required int page,
  }) async {
    final requestUrl = sortUrl.trim();
    if (requestUrl.isEmpty) {
      return const RssArticleFetchResult(
        articles: <RssArticle>[],
        nextPageUrl: null,
        hasMore: false,
        error: '分类 URL 为空',
      );
    }

    if ((source.ruleArticles ?? '').trim().isEmpty) {
      return _fetchWithDefaultParser(
        source: source,
        sortName: sortName,
        sortUrl: requestUrl,
      );
    }

    return _fetchWithRuleParser(
      source: source,
      sortName: sortName,
      sortUrl: requestUrl,
      page: page,
    );
  }

  Future<RssArticleFetchResult> _fetchWithDefaultParser({
    required RssSource source,
    required String sortName,
    required String sortUrl,
  }) async {
    final fetchSource = _buildBaseBookSource(source);
    final fetch = await _gateway.fetchForLoginScript(
      source: fetchSource,
      requestUrl: sortUrl,
    );
    final body = fetch.body.trim();
    if (body.isEmpty) {
      return const RssArticleFetchResult(
        articles: <RssArticle>[],
        nextPageUrl: null,
        hasMore: false,
        error: 'RSS 响应为空',
      );
    }

    final articles = RssDefaultXmlParser.parse(
      sortName: sortName,
      xml: body,
      sourceUrl: source.sourceUrl,
    );

    final nextPageUrl = await _resolveNextPageUrl(
      source: source,
      sortUrl: sortUrl,
    );
    final hasMore =
        articles.isNotEmpty && _hasRuleNextPage(source.ruleNextPage);
    return RssArticleFetchResult(
      articles: articles,
      nextPageUrl: nextPageUrl,
      hasMore: hasMore,
      error: null,
    );
  }

  Future<RssArticleFetchResult> _fetchWithRuleParser({
    required RssSource source,
    required String sortName,
    required String sortUrl,
    required int page,
  }) async {
    final parserSource = _buildRuleSearchBookSource(
      source: source,
      sortUrl: sortUrl,
      nextPageRule: source.ruleNextPage,
    );

    final debug = await _gateway.searchDebug(
      source: parserSource,
      keyword: '',
      page: page,
    );
    if (debug.fetch.body == null) {
      return RssArticleFetchResult(
        articles: const <RssArticle>[],
        nextPageUrl: null,
        hasMore: false,
        error: debug.error ?? 'RSS 列表请求失败',
      );
    }

    final articles = debug.results
        .map(
          (item) => _searchResultToArticle(
            source: source,
            sortName: sortName,
            item: item,
          ),
        )
        .whereType<RssArticle>()
        .toList(growable: false);

    final nextPageUrl = await _resolveNextPageUrl(
      source: source,
      sortUrl: sortUrl,
    );

    final hasMore =
        articles.isNotEmpty && _hasRuleNextPage(source.ruleNextPage);
    final error =
        (debug.error != null && articles.isEmpty) ? debug.error : null;
    return RssArticleFetchResult(
      articles: articles,
      nextPageUrl: nextPageUrl,
      hasMore: hasMore,
      error: error,
    );
  }

  Future<String?> _resolveNextPageUrl({
    required RssSource source,
    required String sortUrl,
  }) async {
    final rule = (source.ruleNextPage ?? '').trim();
    if (rule.isEmpty) return null;
    if (rule.toUpperCase() == 'PAGE') return sortUrl;

    final parserSource = _buildRuleSearchBookSource(
      source: source,
      sortUrl: sortUrl,
      nextPageRule: rule,
    );
    final info = await _gateway.getBookInfoDebug(
      source: parserSource,
      bookUrl: sortUrl,
    );
    final next = info.detail?.tocUrl.trim() ?? '';
    if (next.isEmpty) return null;
    return _absoluteUrl(sortUrl, next);
  }

  static RssArticle? _searchResultToArticle({
    required RssSource source,
    required String sortName,
    required SearchResult item,
  }) {
    final title = item.name.trim();
    if (title.isEmpty) return null;
    final link = _absoluteUrl(source.sourceUrl, item.bookUrl.trim());
    if (link.isEmpty) return null;
    final pubDate = _emptyAsNull(item.updateTime);
    final description = _emptyAsNull(item.intro);
    final image = _emptyAsNull(item.coverUrl);
    return RssArticle(
      origin: source.sourceUrl,
      sort: sortName,
      title: title,
      link: link,
      pubDate: pubDate,
      description: description,
      image: image,
      variable: null,
    );
  }

  static bool _hasRuleNextPage(String? ruleNextPage) {
    return (ruleNextPage ?? '').trim().isNotEmpty;
  }

  static String? _emptyAsNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String _absoluteUrl(String baseUrl, String target) {
    final raw = target.trim();
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null) return raw;
    return base.resolve(raw).toString();
  }

  static BookSource _buildBaseBookSource(RssSource source) {
    return BookSource(
      bookSourceUrl: source.sourceUrl,
      bookSourceName: source.sourceName,
      bookSourceGroup: source.sourceGroup,
      customOrder: source.customOrder,
      enabled: source.enabled,
      enabledExplore: false,
      jsLib: source.jsLib,
      enabledCookieJar: source.enabledCookieJar ?? true,
      concurrentRate: source.concurrentRate,
      header: source.header,
      loginUrl: source.loginUrl,
      loginUi: source.loginUi,
      loginCheckJs: source.loginCheckJs,
      coverDecodeJs: source.coverDecodeJs,
      bookSourceComment: source.sourceComment,
      variableComment: source.variableComment,
      lastUpdateTime: source.lastUpdateTime,
      respondTime: 180000,
      weight: 0,
    );
  }

  static BookSource _buildRuleSearchBookSource({
    required RssSource source,
    required String sortUrl,
    required String? nextPageRule,
  }) {
    return _buildBaseBookSource(source).copyWith(
      // 禁止 SearchRule 空列表时走详情 fallback，避免 RSS 列表被错误降级。
      bookUrlPattern: '#rss#',
      searchUrl: sortUrl,
      ruleSearch: SearchRule(
        bookList: source.ruleArticles,
        name: source.ruleTitle,
        updateTime: source.rulePubDate,
        intro: source.ruleDescription,
        coverUrl: source.ruleImage,
        bookUrl: source.ruleLink,
      ),
      ruleBookInfo: BookInfoRule(
        tocUrl: nextPageRule,
      ),
    );
  }
}
