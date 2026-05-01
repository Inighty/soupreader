import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/core/utils/html_text_formatter.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_support_types.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineBookDetailSupport {
  RuleParserEngineBookDetailSupport(this._ctx);

  static final RegExp _bookNameRegexLikeLegado =
      RegExp(r'\s+作\s*者.*|\s+\S+\s+著');
  static final RegExp _bookAuthorRegexLikeLegado =
      RegExp(r'^\s*作\s*者[:：\s]+|\s+著');
  static final RegExp _numericRegexLikeLegado = RegExp(r'^-?[0-9]+$');

  final RuleParserContext _ctx;

  dynamic _tryDecodeJsonValue(String text) => _ctx.tryDecodeJsonValue(text);
  String _parseValueOnNode(dynamic node, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseValueOnNode(node, rule, baseUrl);
  List<String> _parseStringListFromJson({
    required dynamic json,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) =>
      _ctx.ruleParseSupport.parseStringListFromJson(
        json: json,
        rule: rule,
        baseUrl: baseUrl,
        isUrl: isUrl,
      );
  List<String> _parseStringListFromHtml({
    required Element root,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) =>
      _ctx.ruleParseSupport.parseStringListFromHtml(
        root: root,
        rule: rule,
        baseUrl: baseUrl,
        isUrl: isUrl,
      );
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
  String _resolveTocUrlLikeLegado({
    required String rawValue,
    required String baseUrl,
  }) =>
      _ctx.urlBuildSupport
          .resolveTocUrlLikeLegado(rawValue: rawValue, baseUrl: baseUrl);
  String _normalizeRequestUrl(String requestUrl) =>
      _ctx.requestUrlSupport.parseLegadoStyleUrl(requestUrl).url.trim();

  String formatBookNameLikeLegado(String raw) {
    return raw.replaceAll(_bookNameRegexLikeLegado, '').trim();
  }

  String formatBookAuthorLikeLegado(String raw) {
    return raw.replaceAll(_bookAuthorRegexLikeLegado, '').trim();
  }

  String formatWordCountLikeLegado(String? raw) {
    final wordCount = (raw ?? '').trim();
    if (wordCount.isEmpty) return '';
    if (!_numericRegexLikeLegado.hasMatch(wordCount)) return wordCount;

    final words = int.tryParse(wordCount) ?? 0;
    if (words <= 0) return '';
    if (words > 10000) {
      final value = (words / 10000.0)
          .toStringAsFixed(1)
          .replaceFirst(RegExp(r'\.0$'), '');
      return '$value万字';
    }
    return '$words字';
  }

  String formatIntroLikeLegado(String raw) {
    if (raw.trim().isEmpty) return '';
    return HtmlTextFormatter.formatIntroLikeLegado(raw);
  }

  String parseKindFromJsonNodeLikeLegado(
    dynamic node,
    String? rule,
    String baseUrl,
  ) {
    final rawRule = (rule ?? '').trim();
    if (rawRule.isEmpty) return '';
    final values = _parseStringListFromJson(
      json: node,
      rule: rawRule,
      baseUrl: baseUrl,
      isUrl: false,
    );
    if (values.isNotEmpty) {
      return _joinKindLikeLegado(values);
    }
    return _parseValueOnNode(node, rawRule, baseUrl).trim();
  }

  String parseKindFromHtmlElementLikeLegado(
    Element root,
    String? rule,
    String baseUrl,
  ) {
    final rawRule = (rule ?? '').trim();
    if (rawRule.isEmpty) return '';
    final values = _parseStringListFromHtml(
      root: root,
      rule: rawRule,
      baseUrl: baseUrl,
      isUrl: false,
    );
    if (values.isNotEmpty) {
      return _joinKindLikeLegado(values);
    }
    return _parseRule(root, rawRule, baseUrl).trim();
  }

  BookDetail? parseBookDetailFromBodyLikeLegado({
    required BookSource source,
    required String parseBaseUrl,
    required String body,
  }) {
    final rule = source.ruleBookInfo;
    if (rule == null) return null;
    try {
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      if (jsonRoot != null) {
        var coverUrl = _parseValueOnNode(jsonRoot, rule.coverUrl, parseBaseUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(parseBaseUrl, coverUrl);
        }
        final name = formatBookNameLikeLegado(
          _parseValueOnNode(jsonRoot, rule.name, parseBaseUrl),
        );
        final author = formatBookAuthorLikeLegado(
          _parseValueOnNode(jsonRoot, rule.author, parseBaseUrl),
        );
        final intro = formatIntroLikeLegado(
          _parseValueOnNode(jsonRoot, rule.intro, parseBaseUrl),
        );
        final kind = parseKindFromJsonNodeLikeLegado(
          jsonRoot,
          rule.kind,
          parseBaseUrl,
        );
        final wordCount = formatWordCountLikeLegado(
          _parseValueOnNode(jsonRoot, rule.wordCount, parseBaseUrl),
        );
        return BookDetail(
          name: name,
          author: author,
          coverUrl: coverUrl,
          intro: intro,
          kind: kind,
          lastChapter:
              _parseValueOnNode(jsonRoot, rule.lastChapter, parseBaseUrl),
          updateTime:
              _parseValueOnNode(jsonRoot, rule.updateTime, parseBaseUrl),
          wordCount: wordCount,
          tocUrl: _resolveTocUrlLikeLegado(
            rawValue: _parseValueOnNode(jsonRoot, rule.tocUrl, parseBaseUrl),
            baseUrl: parseBaseUrl,
          ),
          bookUrl: parseBaseUrl,
        );
      }

      final document = html_parser.parse(body);
      Element? root = document.documentElement;
      if (rule.init != null && rule.init!.trim().isNotEmpty) {
        root = _selectFirstElementByRule(document, rule.init!.trim());
      }
      if (root == null) return null;
      final name =
          formatBookNameLikeLegado(_parseRule(root, rule.name, parseBaseUrl));
      final author =
          formatBookAuthorLikeLegado(_parseRule(root, rule.author, parseBaseUrl));
      final intro =
          formatIntroLikeLegado(_parseRule(root, rule.intro, parseBaseUrl));
      final kind = parseKindFromHtmlElementLikeLegado(
        root,
        rule.kind,
        parseBaseUrl,
      );
      final wordCount = formatWordCountLikeLegado(
        _parseRule(root, rule.wordCount, parseBaseUrl),
      );
      return BookDetail(
        name: name,
        author: author,
        coverUrl: _parseRuleAsUrlLikeLegado(root, rule.coverUrl, parseBaseUrl),
        intro: intro,
        kind: kind,
        lastChapter: _parseRule(root, rule.lastChapter, parseBaseUrl),
        updateTime: _parseRule(root, rule.updateTime, parseBaseUrl),
        wordCount: wordCount,
        tocUrl: _resolveTocUrlLikeLegado(
          rawValue:
              _parseRuleAsUrlRawLikeLegado(root, rule.tocUrl, parseBaseUrl),
          baseUrl: parseBaseUrl,
        ),
        bookUrl: parseBaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  SearchResult? parseInfoAsSearchResultLikeLegado({
    required BookSource source,
    required String requestUrl,
    required String responseUrl,
    required bool isRedirect,
    required String body,
    RuleParserSearchResultFilter? filter,
  }) {
    final detail = parseBookDetailFromBodyLikeLegado(
      source: source,
      parseBaseUrl: responseUrl,
      body: body,
    );
    if (detail == null) return null;
    final name = detail.name.trim();
    if (name.isEmpty) return null;
    final author = detail.author.trim();
    if (filter?.call(name, author) == false) {
      return null;
    }
    final normalizedRequestUrl = _normalizeRequestUrl(requestUrl);
    final bookUrl = isRedirect
        ? responseUrl.trim()
        : (normalizedRequestUrl.isNotEmpty
            ? normalizedRequestUrl
            : responseUrl.trim());
    return SearchResult(
      name: name,
      author: author,
      coverUrl: detail.coverUrl.trim(),
      intro: detail.intro,
      kind: detail.kind.trim(),
      lastChapter: detail.lastChapter.trim(),
      updateTime: detail.updateTime.trim(),
      wordCount: detail.wordCount.trim(),
      bookUrl: bookUrl,
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
    );
  }

  String _joinKindLikeLegado(List<String> values) {
    final cleaned = values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return '';
    return cleaned.join(',');
  }
}
