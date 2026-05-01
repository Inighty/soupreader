import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

typedef RuleParserBookDebugFetchStage = Future<FetchDebugResult> Function(
  String url, {
  required int rawState,
});
typedef RuleParserBookDebugLogger = void Function(
  String msg, {
  int state,
  bool showTime,
});

class RuleParserEngineDebugBookSupport {
  RuleParserEngineDebugBookSupport(this._ctx);

  final RuleParserContext _ctx;

  String _buildUrl(
    String baseUrl,
    String rule,
    Map<String, String> params, {
    String? jsLib,
  }) =>
      _ctx.urlBuildSupport.buildUrl(baseUrl, rule, params, jsLib: jsLib);
  ResolvedBookListRule? _resolveBookListRuleForStage(
    BookSource source, {
    required bool isSearch,
  }) =>
      _ctx.requestLifecycleSupport
          .resolveBookListRuleForStage(source, isSearch: isSearch);
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
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
  dynamic _tryDecodeJsonValue(String text) => _ctx.tryDecodeJsonValue(text);
  String _parseValueOnNode(dynamic node, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseValueOnNode(node, rule, baseUrl);
  String _formatBookNameLikeLegado(String raw) =>
      _ctx.bookDetailSupport.formatBookNameLikeLegado(raw);
  String _formatBookAuthorLikeLegado(String raw) =>
      _ctx.bookDetailSupport.formatBookAuthorLikeLegado(raw);
  String _formatWordCountLikeLegado(String? raw) =>
      _ctx.bookDetailSupport.formatWordCountLikeLegado(raw);
  String _formatIntroLikeLegado(String raw) =>
      _ctx.bookDetailSupport.formatIntroLikeLegado(raw);
  String _parseKindFromJsonNodeLikeLegado(
    dynamic node,
    String? rule,
    String baseUrl,
  ) =>
      _ctx.bookDetailSupport
          .parseKindFromJsonNodeLikeLegado(node, rule, baseUrl);
  String _parseKindFromHtmlElementLikeLegado(
    Element root,
    String? rule,
    String baseUrl,
  ) =>
      _ctx.bookDetailSupport
          .parseKindFromHtmlElementLikeLegado(root, rule, baseUrl);
  String _resolveBookInfoTocUrlLikeLegado({
    required String rawValue,
    required String requestUrl,
    required String redirectUrl,
  }) =>
      _ctx.requestLifecycleSupport.resolveBookInfoTocUrlLikeLegado(
        rawValue: rawValue,
        requestUrl: requestUrl,
        redirectUrl: redirectUrl,
      );
  String _normalizeUrlVisitKey(String url) =>
      _ctx.runtimeSupport.normalizeUrlVisitKey(url);
  void _cacheBookInfoTocHtml({
    required String tocUrl,
    required String html,
  }) =>
      _ctx.runtimeSupport
          .cacheBookInfoTocHtml(tocUrl: tocUrl, html: html);
  Element? _selectFirstElementByRule(dynamic parent, String selectorRule) =>
      _ctx.ruleQuerySupport.selectFirstElementByRule(parent, selectorRule);
  String _parseRule(Element element, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseRule(element, rule, baseUrl);
  String _parseRuleAsUrlRawLikeLegado(
    Element element,
    String? rule,
    String baseUrl,
  ) =>
      _ctx.ruleParseSupport
          .parseRuleAsUrlRawLikeLegado(element, rule, baseUrl);
  Future<bool> _debugTocThenContent({
    required BookSource source,
    required String tocUrl,
    required RuleParserBookDebugFetchStage fetchStage,
    required void Function(int state, String payload) emitRaw,
    required RuleParserBookDebugLogger log,
  }) =>
      _ctx.debugTocWorkflowSupport.debugTocThenContent(
        source: source,
        tocUrl: tocUrl,
        fetchStage: fetchStage,
        emitRaw: emitRaw,
        log: log,
      );

  Future<String?> debugBookListThenPickFirst({
    required BookSource source,
    required String keyOrUrl,
    required RuleParserDebugListMode mode,
    String? exploreUrlOverride,
    required RuleParserBookDebugFetchStage fetchStage,
    required RuleParserBookDebugLogger log,
  }) async {
    final isSearch = mode == RuleParserDebugListMode.search;
    final resolved = _resolveBookListRuleForStage(source, isSearch: isSearch);
    final urlRule = isSearch
        ? source.searchUrl
        : ((exploreUrlOverride != null && exploreUrlOverride.trim().isNotEmpty)
            ? exploreUrlOverride.trim()
            : source.exploreUrl);

    log(isSearch ? '︾开始解析搜索页' : '︾开始解析发现页');
    if (resolved == null || urlRule == null || urlRule.trim().isEmpty) {
      log(isSearch ? '⇒搜索规则为空' : '⇒发现规则为空', state: -1);
      return null;
    }
    if (!isSearch && resolved.usedSearchRuleAsExploreFallback) {
      log('≡发现列表规则为空，回退使用搜索列表规则');
    }

    final requestUrl = isSearch
        ? _buildUrl(
            source.bookSourceUrl,
            urlRule,
            {'key': keyOrUrl, 'searchKey': keyOrUrl, 'page': '1'},
            jsLib: source.jsLib,
          )
        : _buildUrl(
            source.bookSourceUrl,
            urlRule,
            const {'page': '1'},
            jsLib: source.jsLib,
          );
    final fetch = await fetchStage(requestUrl, rawState: 10);
    if (fetch.body == null) {
      log('︽列表页解析失败', state: -1);
      return null;
    }

    log('┌获取书籍列表');
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
      isSearch: isSearch,
      onLog: (msg) => log(msg, showTime: false),
    );
    final sample = outcome.fieldSample;
    if (sample.isNotEmpty) {
      _logField(log, '获取书名', sample['name'] ?? '');
      _logField(log, '获取作者', sample['author'] ?? '');
      _logField(log, '获取封面', sample['coverUrl'] ?? '');
      _logField(log, '获取简介', sample['intro'] ?? '');
      _logField(log, '获取最新章节', sample['lastChapter'] ?? '');
      _logField(log, '获取详情链接', sample['bookUrl'] ?? '');
    }
    log('◇书籍总数:${outcome.results.length}');
    return outcome.results.isNotEmpty ? outcome.results.first.bookUrl : null;
  }

  Future<bool> debugInfoTocContent({
    required BookSource source,
    required String bookUrl,
    required RuleParserBookDebugFetchStage fetchStage,
    required void Function(int state, String payload) emitRaw,
    required RuleParserBookDebugLogger log,
  }) async {
    final tocUrl = await debugBookInfo(
      source: source,
      bookUrl: bookUrl,
      fetchStage: fetchStage,
      log: log,
    );
    if (tocUrl == null || tocUrl.trim().isEmpty) {
      log('≡未获取到目录链接', state: -1);
      return false;
    }
    return _debugTocThenContent(
      source: source,
      tocUrl: tocUrl,
      fetchStage: fetchStage,
      emitRaw: emitRaw,
      log: log,
    );
  }

  Future<String?> debugBookInfo({
    required BookSource source,
    required String bookUrl,
    required RuleParserBookDebugFetchStage fetchStage,
    required RuleParserBookDebugLogger log,
  }) async {
    log('︾开始解析详情页');
    final rule = source.ruleBookInfo;
    if (rule == null) {
      log('⇒详情规则为空', state: -1);
      return null;
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
    final fetch = await fetchStage(fullUrl, rawState: 20);
    if (fetch.body == null) {
      log('︽详情页解析失败', state: -1);
      return null;
    }

    final body = fetch.body!;
    final parseBaseUrl =
        (fetch.finalUrl == null || fetch.finalUrl!.trim().isEmpty)
            ? fullUrl
            : fetch.finalUrl!.trim();
    if (parseBaseUrl != fullUrl) {
      log('≡详情页重定向至:$parseBaseUrl', showTime: false);
    }

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;
    if (jsonRoot != null) {
      String getField(
        String label,
        String? ruleStr, {
        String Function(String value)? transform,
      }) {
        log('┌$label');
        var value = _parseValueOnNode(jsonRoot, ruleStr, parseBaseUrl);
        if (transform != null) value = transform(value);
        log('└$value');
        return value;
      }

      final name = getField('获取书名', rule.name, transform: _formatBookNameLikeLegado);
      final author = getField('获取作者', rule.author, transform: _formatBookAuthorLikeLegado);
      _logField(
        log,
        '获取分类',
        _parseKindFromJsonNodeLikeLegado(jsonRoot, rule.kind, parseBaseUrl),
      );
      getField('获取字数', rule.wordCount, transform: _formatWordCountLikeLegado);
      final lastChapter = getField('获取最新章节', rule.lastChapter);
      getField('获取简介', rule.intro, transform: _formatIntroLikeLegado);
      getField('获取封面', rule.coverUrl);
      log('┌获取目录链接');
      final rawTocUrl = _parseValueOnNode(jsonRoot, rule.tocUrl, parseBaseUrl);
      if (rawTocUrl.trim().isEmpty) {
        log('≡目录链接为空，将使用详情页作为目录页', showTime: false);
      }
      final tocUrl = _resolveBookInfoTocUrlLikeLegado(
        rawValue: rawTocUrl,
        requestUrl: fullUrl,
        redirectUrl: parseBaseUrl,
      );
      log('└$tocUrl');
      if (_normalizeUrlVisitKey(tocUrl) == _normalizeUrlVisitKey(fullUrl)) {
        _cacheBookInfoTocHtml(tocUrl: tocUrl, html: body);
      }
      if (name.isEmpty && author.isEmpty && lastChapter.isEmpty && tocUrl.isEmpty) {
        log('≡字段全为空，可能 ruleBookInfo 不匹配', state: -1);
      }
      log('︽详情页解析完成', showTime: false);
      log('', showTime: false);
      return tocUrl;
    }

    final document = html_parser.parse(body);
    Element? root = document.documentElement;
    if (root == null) {
      log('⇒页面无 documentElement', state: -1);
      return null;
    }
    if (rule.init != null && rule.init!.trim().isNotEmpty) {
      log('≡执行详情页初始化规则');
      final initEl = _selectFirstElementByRule(document, rule.init!.trim());
      if (initEl != null) {
        root = initEl;
      } else {
        log('└init 匹配失败（将继续用 documentElement）');
      }
    }

    String getField(
      String label,
      String? ruleStr, {
      String Function(String value)? transform,
    }) {
      log('┌$label');
      var value = _parseRule(root!, ruleStr, parseBaseUrl);
      if (transform != null) value = transform(value);
      log('└$value');
      return value;
    }

    final name = getField('获取书名', rule.name, transform: _formatBookNameLikeLegado);
    final author = getField('获取作者', rule.author, transform: _formatBookAuthorLikeLegado);
    _logField(
      log,
      '获取分类',
      _parseKindFromHtmlElementLikeLegado(root, rule.kind, parseBaseUrl),
    );
    getField('获取字数', rule.wordCount, transform: _formatWordCountLikeLegado);
    final lastChapter = getField('获取最新章节', rule.lastChapter);
    getField('获取简介', rule.intro, transform: _formatIntroLikeLegado);
    getField('获取封面', rule.coverUrl);
    log('┌获取目录链接');
    final rawTocUrl = _parseRuleAsUrlRawLikeLegado(root, rule.tocUrl, parseBaseUrl);
    if (rawTocUrl.trim().isEmpty) {
      log('≡目录链接为空，将使用详情页作为目录页', showTime: false);
    }
    final tocUrl = _resolveBookInfoTocUrlLikeLegado(
      rawValue: rawTocUrl,
      requestUrl: fullUrl,
      redirectUrl: parseBaseUrl,
    );
    log('└$tocUrl');
    if (_normalizeUrlVisitKey(tocUrl) == _normalizeUrlVisitKey(fullUrl)) {
      _cacheBookInfoTocHtml(tocUrl: tocUrl, html: body);
    }
    if (name.isEmpty && author.isEmpty && lastChapter.isEmpty && tocUrl.isEmpty) {
      log('≡字段全为空，可能 ruleBookInfo 不匹配', state: -1);
    }
    log('︽详情页解析完成', showTime: false);
    log('', showTime: false);
    return tocUrl;
  }

  void _logField(RuleParserBookDebugLogger log, String label, String value) {
    log('┌$label');
    log('└$value');
  }
}
