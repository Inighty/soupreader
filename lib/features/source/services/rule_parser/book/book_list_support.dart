import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_detail_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_support_types.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineBookListSupport {
  RuleParserEngineBookListSupport(this._ctx);

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
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
  bool _looksLikeJsonPath(String rule) =>
      _ctx.ruleParseSupport.looksLikeJsonPath(rule);
  List<dynamic> _selectJsonList(dynamic root, String rule) =>
      _ctx.ruleParseSupport.selectJsonList(root, rule);
  NormalizedListRule _normalizeListRule(String? rawRule) =>
      _ctx.normalizeListRule(rawRule);
  List<Element> _selectAllElementsByRule(
    dynamic parent,
    String selectorRule, {
    String? rawHtml,
  }) =>
      _ctx.selectorSupport.selectAllElementsByRule(
        parent,
        selectorRule,
        rawHtml: rawHtml,
      );
  RuleParserEngineBookDetailSupport get _detailSupport =>
      _ctx.bookDetailSupport;

  BookListAnalyzeOutcome analyzeBookListLikeLegado({
    required BookSource source,
    required BookListRule rule,
    required String requestUrl,
    required String responseUrl,
    required bool isRedirect,
    required String body,
    required bool isSearch,
    RuleParserSearchResultFilter? filter,
    RuleParserSearchResultShouldBreak? shouldBreak,
    RuleParserDebugLogger? onLog,
  }) {
    final baseUrl =
        responseUrl.trim().isNotEmpty ? responseUrl.trim() : requestUrl.trim();
    final normalizedListRule = _normalizeListRule(rule.bookList);
    final selector = normalizedListRule.selector;
    final isInfoByPattern = isSearch &&
        _matchesBookUrlPatternLikeLegado(source.bookUrlPattern, baseUrl);
    if (isInfoByPattern) {
      onLog?.call('≡链接为详情页');
      final info = _detailSupport.parseInfoAsSearchResultLikeLegado(
        source: source,
        requestUrl: requestUrl,
        responseUrl: baseUrl,
        isRedirect: isRedirect,
        body: body,
        filter: filter,
      );
      final infoList =
          info == null ? const <SearchResult>[] : <SearchResult>[info];
      return BookListAnalyzeOutcome(
        results: infoList,
        listCount: 0,
        fieldSample: info == null
            ? const <String, String>{}
            : <String, String>{
                'name': info.name,
                'author': info.author,
                'coverUrl': info.coverUrl,
                'intro': info.intro,
                'kind': info.kind,
                'lastChapter': info.lastChapter,
                'updateTime': info.updateTime,
                'wordCount': info.wordCount,
                'bookUrl': info.bookUrl,
              },
        listRuleRaw: rule.bookList,
        usedInfoFallback: true,
      );
    }

    final results = <SearchResult>[];
    Map<String, String> fieldSample = const <String, String>{};
    var listCount = 0;

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    if (jsonRoot != null && _looksLikeJsonPath(selector)) {
      final nodes = _selectJsonList(jsonRoot, selector);
      listCount = nodes.length;
      onLog?.call('└列表大小:${nodes.length}');
      for (final node in nodes) {
        final name = _detailSupport.formatBookNameLikeLegado(
          _parseValueOnNode(node, rule.name, baseUrl),
        );
        final author = _detailSupport.formatBookAuthorLikeLegado(
          _parseValueOnNode(node, rule.author, baseUrl),
        );
        if (name.isEmpty) continue;
        if (filter?.call(name, author) == false) continue;

        final intro = _detailSupport.formatIntroLikeLegado(
          _parseValueOnNode(node, rule.intro, baseUrl),
        );
        final kind = _detailSupport.parseKindFromJsonNodeLikeLegado(
          node,
          rule.kind,
          baseUrl,
        );
        final lastChapter =
            _parseValueOnNode(node, rule.lastChapter, baseUrl).trim();
        final updateTime =
            _parseValueOnNode(node, rule.updateTime, baseUrl).trim();
        final wordCount = _detailSupport.formatWordCountLikeLegado(
          _parseValueOnNode(node, rule.wordCount, baseUrl),
        );
        var bookUrl = _parseValueOnNode(node, rule.bookUrl, baseUrl).trim();
        if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
          bookUrl = _absoluteUrl(baseUrl, bookUrl);
        }
        if (bookUrl.isEmpty) bookUrl = baseUrl;
        var coverUrl = _parseValueOnNode(node, rule.coverUrl, baseUrl).trim();
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(baseUrl, coverUrl);
        }

        fieldSample = fieldSample.isEmpty
            ? <String, String>{
                'name': name,
                'author': author,
                'coverUrl': coverUrl,
                'intro': intro,
                'kind': kind,
                'lastChapter': lastChapter,
                'updateTime': updateTime,
                'wordCount': wordCount,
                'bookUrl': bookUrl,
              }
            : fieldSample;

        results.add(
          SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          ),
        );
        if (shouldBreak?.call(results.length) == true) break;
      }
    } else {
      final document = html_parser.parse(body);
      final elements = _selectAllElementsByRule(document, selector);
      listCount = elements.length;
      onLog?.call('└列表大小:${elements.length}');
      for (final element in elements) {
        final name = _detailSupport.formatBookNameLikeLegado(
          _parseRule(element, rule.name, baseUrl),
        );
        final author = _detailSupport.formatBookAuthorLikeLegado(
          _parseRule(element, rule.author, baseUrl),
        );
        if (name.isEmpty) continue;
        if (filter?.call(name, author) == false) continue;

        final kind = _detailSupport.parseKindFromHtmlElementLikeLegado(
          element,
          rule.kind,
          baseUrl,
        );
        final intro = _detailSupport.formatIntroLikeLegado(
          _parseRule(element, rule.intro, baseUrl),
        );
        final lastChapter =
            _parseRule(element, rule.lastChapter, baseUrl).trim();
        final updateTime = _parseRule(element, rule.updateTime, baseUrl).trim();
        final wordCount = _detailSupport.formatWordCountLikeLegado(
          _parseRule(element, rule.wordCount, baseUrl),
        );
        var bookUrl =
            _parseRuleAsUrlLikeLegado(element, rule.bookUrl, baseUrl).trim();
        if (bookUrl.isEmpty) bookUrl = baseUrl;
        final coverUrl =
            _parseRuleAsUrlLikeLegado(element, rule.coverUrl, baseUrl).trim();

        fieldSample = fieldSample.isEmpty
            ? <String, String>{
                'name': name,
                'author': author,
                'coverUrl': coverUrl,
                'intro': intro,
                'kind': kind,
                'lastChapter': lastChapter,
                'updateTime': updateTime,
                'wordCount': wordCount,
                'bookUrl': bookUrl,
              }
            : fieldSample;

        results.add(
          SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          ),
        );
        if (shouldBreak?.call(results.length) == true) break;
      }
    }

    if (listCount == 0) {
      onLog?.call('≡列表为空，可能是详情页或规则不匹配');
    }

    var out = _postProcessBookListLikeLegado(
      results: results,
      reverse: normalizedListRule.reverse,
    );

    if (out.isEmpty && isSearch && (source.bookUrlPattern ?? '').trim().isEmpty) {
      onLog?.call('└列表为空,按详情页解析');
      final info = _detailSupport.parseInfoAsSearchResultLikeLegado(
        source: source,
        requestUrl: requestUrl,
        responseUrl: baseUrl,
        isRedirect: isRedirect,
        body: body,
        filter: filter,
      );
      if (info != null) {
        out = <SearchResult>[info];
        fieldSample = <String, String>{
          'name': info.name,
          'author': info.author,
          'coverUrl': info.coverUrl,
          'intro': info.intro,
          'kind': info.kind,
          'lastChapter': info.lastChapter,
          'updateTime': info.updateTime,
          'wordCount': info.wordCount,
          'bookUrl': info.bookUrl,
        };
      }
    }

    return BookListAnalyzeOutcome(
      results: out,
      listCount: listCount,
      fieldSample: fieldSample,
      listRuleRaw: rule.bookList,
      usedInfoFallback: out.isNotEmpty && listCount == 0,
    );
  }

  bool _matchesBookUrlPatternLikeLegado(String? pattern, String url) {
    final raw = (pattern ?? '').trim();
    if (raw.isEmpty) return false;
    final target = url.trim();
    if (target.isEmpty) return false;
    try {
      final match = RegExp(raw).firstMatch(target);
      return match != null && match.start == 0 && match.end == target.length;
    } catch (_) {
      return false;
    }
  }

  String _searchResultDedupKey(SearchResult result) {
    return result.bookUrl;
  }

  List<SearchResult> _postProcessBookListLikeLegado({
    required List<SearchResult> results,
    required bool reverse,
  }) {
    if (results.isEmpty) return const <SearchResult>[];
    final out = <SearchResult>[];
    final seen = <String>{};
    for (final item in results) {
      final key = _searchResultDedupKey(item);
      if (!seen.add(key)) continue;
      out.add(item);
    }
    if (reverse) {
      return out.reversed.toList(growable: false);
    }
    return out;
  }
}
