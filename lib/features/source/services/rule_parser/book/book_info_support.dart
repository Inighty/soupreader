import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_detail_support.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class BookInfoAnalyzeOutcome {
  final BookDetail? detail;
  final String? initRule;
  final bool initMatched;
  final Map<String, String> fieldSample;
  final String? error;

  const BookInfoAnalyzeOutcome({
    required this.detail,
    required this.initRule,
    required this.initMatched,
    required this.fieldSample,
    required this.error,
  });
}

class RuleParserEngineBookInfoSupport {
  RuleParserEngineBookInfoSupport(this._ctx);

  final RuleParserContext _ctx;

  dynamic _tryDecodeJsonValue(String text) => _ctx.tryDecodeJsonValue(text);
  String _parseValueOnNode(dynamic node, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseValueOnNode(node, rule, baseUrl);
  String _parseRule(Element element, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseRule(element, rule, baseUrl);
  String _parseRuleAsUrlLikeLegado(
    Element element,
    String? rule,
    String baseUrl, {
    bool fallbackToBaseUrlWhenEmpty = false,
  }) =>
      _ctx.ruleParseSupport.parseRuleAsUrlLikeLegado(
        element,
        rule,
        baseUrl,
        fallbackToBaseUrlWhenEmpty: fallbackToBaseUrlWhenEmpty,
      );
  String _parseRuleAsUrlRawLikeLegado(
    Element element,
    String? rule,
    String baseUrl,
  ) =>
      _ctx.ruleParseSupport.parseRuleAsUrlRawLikeLegado(element, rule, baseUrl);
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
  Element? _selectFirstElementByRule(Element root, String rule) =>
      _ctx.ruleQuerySupport.selectFirstElementByRule(root, rule);
  RuleParserEngineBookDetailSupport get _detailSupport =>
      _ctx.bookDetailSupport;
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

  BookDetail? parseBookInfoLikeLegado({
    required BookSource source,
    required String requestUrl,
    required String responseUrl,
    required String body,
  }) {
    final rule = source.ruleBookInfo;
    if (rule == null) return null;

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    if (jsonRoot != null) {
      final fields = _parseJsonFields(
        jsonRoot: jsonRoot,
        rule: rule,
        requestUrl: requestUrl,
        parseBaseUrl: responseUrl,
      );
      _cacheTocHtmlIfSameRequest(
        tocUrl: fields.tocUrl,
        requestUrl: requestUrl,
        body: body,
      );
      return fields.toDetail();
    }

    final document = html_parser.parse(body);
    Element? root = document.documentElement;
    if (root != null && rule.init != null && rule.init!.isNotEmpty) {
      root = _selectFirstElementByRule(root, rule.init!);
    }
    if (root == null) return null;

    final fields = _parseHtmlFields(
      root: root,
      rule: rule,
      requestUrl: requestUrl,
      parseBaseUrl: responseUrl,
    );
    _cacheTocHtmlIfSameRequest(
      tocUrl: fields.tocUrl,
      requestUrl: requestUrl,
      body: body,
    );
    return fields.toDetail();
  }

  BookInfoAnalyzeOutcome analyzeBookInfoDebugLikeLegado({
    required BookSource source,
    required String requestUrl,
    required String responseUrl,
    required String body,
  }) {
    final rule = source.ruleBookInfo;
    if (rule == null) {
      return const BookInfoAnalyzeOutcome(
        detail: null,
        initRule: null,
        initMatched: false,
        fieldSample: <String, String>{},
        error: 'ruleBookInfo 为空',
      );
    }

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    if (jsonRoot != null) {
      final fields = _parseJsonFields(
        jsonRoot: jsonRoot,
        rule: rule,
        requestUrl: requestUrl,
        parseBaseUrl: responseUrl,
      );
      final initRule = rule.init;
      final initMatched = initRule == null || initRule.trim().isEmpty;
      return BookInfoAnalyzeOutcome(
        detail: fields.toDetail(),
        initRule: initRule,
        initMatched: initMatched,
        fieldSample: fields.fieldSample,
        error: initMatched ? null : '响应为 JSON：init 规则不适用',
      );
    }

    final document = html_parser.parse(body);
    Element? root = document.documentElement;
    var initMatched = true;
    if (root != null && rule.init != null && rule.init!.isNotEmpty) {
      root = _selectFirstElementByRule(root, rule.init!);
      initMatched = root != null;
    }
    if (root == null) {
      return BookInfoAnalyzeOutcome(
        detail: null,
        initRule: rule.init,
        initMatched: initMatched,
        fieldSample: const <String, String>{},
        error: 'init 定位失败或页面无 documentElement',
      );
    }

    final fields = _parseHtmlFields(
      root: root,
      rule: rule,
      requestUrl: requestUrl,
      parseBaseUrl: responseUrl,
    );
    return BookInfoAnalyzeOutcome(
      detail: fields.toDetail(),
      initRule: rule.init,
      initMatched: initMatched,
      fieldSample: fields.fieldSample,
      error: null,
    );
  }

  _BookInfoFields _parseJsonFields({
    required dynamic jsonRoot,
    required BookInfoRule rule,
    required String requestUrl,
    required String parseBaseUrl,
  }) {
    final name = _detailSupport.formatBookNameLikeLegado(
      _parseValueOnNode(jsonRoot, rule.name, parseBaseUrl),
    );
    final author = _detailSupport.formatBookAuthorLikeLegado(
      _parseValueOnNode(jsonRoot, rule.author, parseBaseUrl),
    );
    var coverUrl = _parseValueOnNode(jsonRoot, rule.coverUrl, parseBaseUrl);
    if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
      coverUrl = _absoluteUrl(parseBaseUrl, coverUrl);
    }
    final intro = _detailSupport.formatIntroLikeLegado(
      _parseValueOnNode(jsonRoot, rule.intro, parseBaseUrl),
    );
    final kind = _detailSupport.parseKindFromJsonNodeLikeLegado(
      jsonRoot,
      rule.kind,
      parseBaseUrl,
    );
    final lastChapter =
        _parseValueOnNode(jsonRoot, rule.lastChapter, parseBaseUrl);
    final updateTime =
        _parseValueOnNode(jsonRoot, rule.updateTime, parseBaseUrl);
    final wordCount = _detailSupport.formatWordCountLikeLegado(
      _parseValueOnNode(jsonRoot, rule.wordCount, parseBaseUrl),
    );
    final tocUrl = _resolveBookInfoTocUrlLikeLegado(
      rawValue: _parseValueOnNode(jsonRoot, rule.tocUrl, parseBaseUrl),
      requestUrl: requestUrl,
      redirectUrl: parseBaseUrl,
    );
    return _BookInfoFields(
      name: name,
      author: author,
      coverUrl: coverUrl,
      intro: intro,
      kind: kind,
      lastChapter: lastChapter,
      updateTime: updateTime,
      wordCount: wordCount,
      tocUrl: tocUrl,
      bookUrl: parseBaseUrl,
    );
  }

  _BookInfoFields _parseHtmlFields({
    required Element root,
    required BookInfoRule rule,
    required String requestUrl,
    required String parseBaseUrl,
  }) {
    final name = _detailSupport.formatBookNameLikeLegado(
      _parseRule(root, rule.name, parseBaseUrl),
    );
    final author = _detailSupport.formatBookAuthorLikeLegado(
      _parseRule(root, rule.author, parseBaseUrl),
    );
    final coverUrl = _parseRuleAsUrlLikeLegado(root, rule.coverUrl, parseBaseUrl);
    final intro = _detailSupport.formatIntroLikeLegado(
      _parseRule(root, rule.intro, parseBaseUrl),
    );
    final kind = _detailSupport.parseKindFromHtmlElementLikeLegado(
      root,
      rule.kind,
      parseBaseUrl,
    );
    final lastChapter = _parseRule(root, rule.lastChapter, parseBaseUrl);
    final updateTime = _parseRule(root, rule.updateTime, parseBaseUrl);
    final wordCount = _detailSupport.formatWordCountLikeLegado(
      _parseRule(root, rule.wordCount, parseBaseUrl),
    );
    final tocUrl = _resolveBookInfoTocUrlLikeLegado(
      rawValue: _parseRuleAsUrlRawLikeLegado(root, rule.tocUrl, parseBaseUrl),
      requestUrl: requestUrl,
      redirectUrl: parseBaseUrl,
    );
    return _BookInfoFields(
      name: name,
      author: author,
      coverUrl: coverUrl,
      intro: intro,
      kind: kind,
      lastChapter: lastChapter,
      updateTime: updateTime,
      wordCount: wordCount,
      tocUrl: tocUrl,
      bookUrl: parseBaseUrl,
    );
  }

  void _cacheTocHtmlIfSameRequest({
    required String tocUrl,
    required String requestUrl,
    required String body,
  }) {
    if (_normalizeUrlVisitKey(tocUrl) != _normalizeUrlVisitKey(requestUrl)) {
      return;
    }
    _cacheBookInfoTocHtml(
      tocUrl: tocUrl,
      html: body,
    );
  }
}

class _BookInfoFields {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String updateTime;
  final String wordCount;
  final String tocUrl;
  final String bookUrl;

  const _BookInfoFields({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.kind,
    required this.lastChapter,
    required this.updateTime,
    required this.wordCount,
    required this.tocUrl,
    required this.bookUrl,
  });

  BookDetail toDetail() {
    return BookDetail(
      name: name,
      author: author,
      coverUrl: coverUrl,
      intro: intro,
      kind: kind,
      lastChapter: lastChapter,
      updateTime: updateTime,
      wordCount: wordCount,
      tocUrl: tocUrl,
      bookUrl: bookUrl,
    );
  }

  Map<String, String> get fieldSample => <String, String>{
    'name': name,
    'author': author,
    'coverUrl': coverUrl,
    'intro': intro,
    'kind': kind,
    'lastChapter': lastChapter,
    'updateTime': updateTime,
    'wordCount': wordCount,
    'tocUrl': tocUrl,
  };
}
