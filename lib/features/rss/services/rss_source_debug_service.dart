import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/rss_source.dart';
import 'rss_default_xml_parser.dart';
import 'rss_sort_urls_helper.dart';

class RssSourceDebugSnapshot {
  final String? listSrc;
  final String? contentSrc;
  final List<String> logs;

  const RssSourceDebugSnapshot({
    required this.listSrc,
    required this.contentSrc,
    required this.logs,
  });
}

/// RSS 源调试快照（对齐 legado `RssSourceDebugModel` 的 list/content 源码承载语义）
class RssSourceDebugService {
  final RuleParserEngine _engine;

  RssSourceDebugService({
    RuleParserEngine? engine,
  }) : _engine = engine ?? RuleParserEngine();

  Future<RssSourceDebugSnapshot> run(RssSource source) async {
    final logs = <String>[];
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) {
      return const RssSourceDebugSnapshot(
        listSrc: null,
        contentSrc: null,
        logs: <String>['sourceUrl 为空'],
      );
    }

    final listUrl = await _resolveListUrl(source, logs);
    if (listUrl.isEmpty) {
      return RssSourceDebugSnapshot(
        listSrc: null,
        contentSrc: null,
        logs: logs.isEmpty ? const <String>['分类 URL 为空'] : logs,
      );
    }

    final baseSource = _buildBaseBookSource(source);
    String? listSrc;
    String? firstArticleUrl;

    final hasRuleArticles = (source.ruleArticles ?? '').trim().isNotEmpty;
    if (hasRuleArticles) {
      logs.add('开始调试列表规则');
      final listDebugSource = _buildRuleSearchBookSource(
        source: source,
        sortUrl: listUrl,
      );
      final search = await _engine.searchDebug(
        listDebugSource,
        '',
        page: 1,
      );
      listSrc = search.fetch.body;
      if (listSrc == null) {
        logs.add(search.error ?? search.fetch.error ?? '列表请求失败');
        return RssSourceDebugSnapshot(
          listSrc: null,
          contentSrc: null,
          logs: logs,
        );
      }
      logs.add('列表源码抓取完成');
      if (search.results.isNotEmpty) {
        firstArticleUrl = _absoluteUrl(
          sourceUrl,
          search.results.first.bookUrl.trim(),
        );
      }
      final debugError = (search.error ?? '').trim();
      if (debugError.isNotEmpty) {
        logs.add(debugError);
      }
    } else {
      logs.add('开始调试默认 RSS 列表解析');
      final fetch = await _engine.fetchForLoginScript(
        source: baseSource,
        requestUrl: listUrl,
      );
      listSrc = fetch.body;
      final body = fetch.body.trim();
      if (body.isEmpty) {
        logs.add('RSS 响应为空');
        return RssSourceDebugSnapshot(
          listSrc: listSrc,
          contentSrc: null,
          logs: logs,
        );
      }
      logs.add('列表源码抓取完成');
      final articles = RssDefaultXmlParser.parse(
        sortName: '',
        xml: body,
        sourceUrl: sourceUrl,
      );
      if (articles.isNotEmpty) {
        firstArticleUrl = articles.first.link.trim();
      }
    }

    final contentRule = (source.ruleContent ?? '').trim();
    if (contentRule.isEmpty) {
      logs.add('ruleContent 为空');
      return RssSourceDebugSnapshot(
        listSrc: listSrc,
        contentSrc: null,
        logs: logs,
      );
    }

    final contentUrl = (firstArticleUrl ?? '').trim();
    if (contentUrl.isEmpty) {
      logs.add('未解析到正文链接');
      return RssSourceDebugSnapshot(
        listSrc: listSrc,
        contentSrc: null,
        logs: logs,
      );
    }

    logs.add('开始调试正文规则');
    final contentDebugSource = baseSource.copyWith(
      ruleContent: ContentRule(content: contentRule),
    );
    final content = await _engine.getContentDebug(
      contentDebugSource,
      contentUrl,
    );
    final contentSrc = content.fetch.body;
    if (contentSrc == null) {
      logs.add(content.error ?? content.fetch.error ?? '正文请求失败');
      return RssSourceDebugSnapshot(
        listSrc: listSrc,
        contentSrc: null,
        logs: logs,
      );
    }

    logs.add('正文源码抓取完成');
    return RssSourceDebugSnapshot(
      listSrc: listSrc,
      contentSrc: contentSrc,
      logs: logs,
    );
  }

  Future<String> _resolveListUrl(
    RssSource source,
    List<String> logs,
  ) async {
    try {
      final tabs = await RssSortUrlsHelper.resolveSortTabs(source);
      if (tabs.isNotEmpty) {
        final firstUrl = tabs.first.url.trim();
        if (firstUrl.isNotEmpty) return firstUrl;
      }
    } catch (error) {
      logs.add('分类解析失败：$error');
    }
    return source.sourceUrl.trim();
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
  }) {
    return _buildBaseBookSource(source).copyWith(
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
    );
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
}
