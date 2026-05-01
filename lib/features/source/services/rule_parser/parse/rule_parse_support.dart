import 'dart:convert';

import 'package:html/dom.dart';
import 'package:json_path/json_path.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

import 'package:soupreader/features/source/services/rule_parser/parse/legacy_rule_types.dart';
import 'package:soupreader/features/source/services/rule_parser/js/js_template_support.dart';
import 'package:soupreader/features/source/services/rule_parser/parse/rule_query_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/runtime_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/syntax_helper.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineRuleParseSupport {
  RuleParserEngineRuleParseSupport(this._ctx);

  final RuleParserContext _ctx;

  RuleParserEngineRuntimeSupport get _runtimeSupport => _ctx.runtimeSupport;
  RuleParserEngineJsTemplateSupport get _jsTemplateSupport =>
      _ctx.jsTemplateSupport;
  RuleParserEngineRuleQuerySupport get _querySupport => _ctx.ruleQuerySupport;
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
  String _resolveUrlFieldWithLegadoSemantics({
    required String rawValue,
    required String baseUrl,
    required bool fallbackToBaseUrlWhenEmpty,
  }) =>
      _ctx.urlBuildSupport.resolveUrlFieldWithLegadoSemantics(
        rawValue: rawValue,
        baseUrl: baseUrl,
        fallbackToBaseUrlWhenEmpty: fallbackToBaseUrlWhenEmpty,
      );
  String parseRuleAsUrlRawLikeLegado(Element element, String? rule, String baseUrl) {
    return parseRule(element, rule, baseUrl, urlLikeSingleValue: true);
  }
  String parseRuleAsUrlLikeLegado(
    Element element,
    String? rule,
    String baseUrl, {
    bool fallbackToBaseUrlWhenEmpty = false,
  }) {
    return _resolveUrlFieldWithLegadoSemantics(
      rawValue: parseRuleAsUrlRawLikeLegado(element, rule, baseUrl),
      baseUrl: baseUrl,
      fallbackToBaseUrlWhenEmpty: fallbackToBaseUrlWhenEmpty,
    );
  }
  bool looksLikeXPath(String rule) {
    final trimmed = rule.trimLeft();
    return trimmed.startsWith('@XPath:') || trimmed.startsWith('//');
  }

  bool looksLikeJsonPath(String rule) {
    final trimmed = rule.trimLeft();
    return trimmed.startsWith('@Json:') ||
        trimmed == r'$' ||
        trimmed.startsWith(r'$.') ||
        trimmed.startsWith(r'$[') ||
        trimmed.startsWith(r'$..');
  }
  bool looksLikeRegexRule(String rule) => rule.trimLeft().startsWith(':');
  String normalizeCssRulePrefix(String rule) {
    final trimmed = rule.trimLeft();
    if (trimmed.toLowerCase().startsWith('@css:')) {
      return trimmed.substring('@css:'.length).trimLeft();
    }
    if (trimmed.startsWith('@@')) return trimmed.substring(2).trimLeft();
    return rule;
  }
  ({String expr, List<LegadoReplacePair> replacements}) splitExprAndReplacements(
    String raw,
  ) {
    final parts = raw.split('##');
    final expr = parts.first.trim();
    final replacements = <LegadoReplacePair>[];
    if (parts.length > 1) {
      final rest = parts.sublist(1);
      for (var i = 0; i < rest.length; i += 2) {
        final pattern = rest[i].trim();
        if (pattern.isEmpty) continue;
        replacements.add(
          LegadoReplacePair(
            pattern: pattern,
            replacement: (i + 1) < rest.length ? rest[i + 1] : '',
          ),
        );
      }
    }
    return (expr: expr, replacements: replacements);
  }
  String parseXPathRule(Element element, String raw, String baseUrl) {
    final split = splitExprAndReplacements(raw);
    var expr = split.expr;
    if (expr.startsWith('@XPath:')) expr = expr.substring('@XPath:'.length).trim();
    if (expr.isEmpty) return '';
    try {
      final result = HtmlXPath.node(element).query(expr);
      final text =
          result.attr ?? (result.node?.text ?? (result.node?.toString() ?? ''));
      return _querySupport.applyInlineReplacements(text, split.replacements).trim();
    } catch (_) {
      return '';
    }
  }
  String parseJsonPathRule(dynamic json, String raw) {
    final split = splitExprAndReplacements(raw);
    var expr = split.expr;
    if (expr.startsWith('@Json:')) expr = expr.substring('@Json:'.length).trim();
    if (expr.isEmpty) return '';

    dynamic value;
    try {
      final matches = JsonPath(expr).read(json).toList(growable: false);
      if (matches.isEmpty) return '';
      value = matches.first.value;
    } catch (_) {
      if (json is Map && json.containsKey(expr)) {
        value = json[expr];
      } else {
        return '';
      }
    }
    String text;
    if (value == null) {
      text = '';
    } else if (value is String) {
      text = value;
    } else if (value is num || value is bool) {
      text = value.toString();
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = value.toString();
      }
    }
    return _querySupport.applyInlineReplacements(text, split.replacements).trim();
  }
  dynamic tryDecodeJsonValue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }
  void applyPutRules(
    Map<String, String> putMap, {
    required dynamic node,
    required String baseUrl,
    String? jsLib,
  }) {
    if (putMap.isEmpty) return;
    for (final entry in putMap.entries) {
      if (entry.value.trim().isEmpty) continue;
      var resolvedValueRule = _runtimeSupport.replaceGetTokens(entry.value);
      resolvedValueRule = _jsTemplateSupport.applyTemplateJsTokens(
        resolvedValueRule,
        baseUrl: baseUrl,
        jsLib: jsLib,
      );
      final value = _runtimeSupport.isLiteralRuleCandidate(entry.value)
          ? resolvedValueRule.trim()
          : parseValueOnNode(node, resolvedValueRule, baseUrl);
      _runtimeSupport.putRuntimeVariable(entry.key, value);
    }
  }
  List<String> _mergeRuleListResults(List<List<String>> results, String? operator) {
    if (results.isEmpty) return const <String>[];
    if (operator == '%%') {
      final out = <String>[];
      for (var i = 0; i < results.first.length; i++) {
        for (final list in results) {
          if (i < list.length) out.add(list[i]);
        }
      }
      return out;
    }
    return [for (final list in results) ...list];
  }
  String _mergeRuleTextResults(List<String> results, String? operator) {
    if (results.isEmpty) return '';
    return operator == '||' ? results.first : results.join('\n').trim();
  }
  List<String> _parseStringListFromHtmlSingle(
    Element root,
    String rule,
    String baseUrl,
    bool isUrl,
  ) {
    final extracted = RuleParserEngineSyntaxHelper.extractPutRules(rule);
    final current = extracted.cleanedRule.trim();
    if (current.isEmpty) return const <String>[];
    applyPutRules(extracted.putMap, node: root, baseUrl: baseUrl);
    var resolvedRule = _runtimeSupport.replaceGetTokens(current);
    resolvedRule =
        _jsTemplateSupport.applyTemplateJsTokens(resolvedRule, baseUrl: baseUrl);
    resolvedRule = normalizeCssRulePrefix(resolvedRule).trim();
    if (resolvedRule.isEmpty) return const <String>[];
    List<String> normalizeValues(String value) {
      final list = _runtimeSupport.splitPossibleListValues(value);
      return [
        for (final item in list)
          if (item.trim().isNotEmpty) isUrl ? _absoluteUrl(baseUrl, item) : item,
      ];
    }
    if (_runtimeSupport.isLiteralRuleCandidate(current)) {
      return normalizeValues(resolvedRule);
    }
    if (looksLikeXPath(resolvedRule)) {
      return normalizeValues(parseXPathRule(root, resolvedRule, baseUrl));
    }
    if (looksLikeRegexRule(resolvedRule)) {
      return normalizeValues(parseRegexRuleOnText(root.outerHtml, resolvedRule));
    }
    final parsed = LegadoTextRule.parse(
      resolvedRule,
      isExtractor: _querySupport.isExtractorToken,
    );
    final targets = parsed.selectors.isEmpty
        ? <Element>[root]
        : _querySupport.selectAllBySelectors(root, parsed.selectors);
    if (targets.isEmpty) return const <String>[];
    final out = <String>[];
    for (final element in targets) {
      var value = _querySupport.extractWithFallbacks(
        element,
        parsed.extractors,
        baseUrl: baseUrl,
      );
      value = _querySupport.applyInlineReplacements(value, parsed.replacements).trim();
      for (final item in _runtimeSupport.splitPossibleListValues(value)) {
        final resolved = isUrl ? _absoluteUrl(baseUrl, item) : item;
        if (resolved.trim().isNotEmpty) out.add(resolved);
      }
    }
    final seen = <String>{};
    return [
      for (final value in out)
        if (value.trim().isNotEmpty && seen.add(value.trim())) value.trim(),
    ];
  }
  List<String> _parseStringListFromJsonSingle(
    dynamic json,
    String rule,
    String baseUrl,
    bool isUrl,
  ) {
    final extracted = RuleParserEngineSyntaxHelper.extractPutRules(rule);
    final current = extracted.cleanedRule.trim();
    if (current.isEmpty) return const <String>[];
    applyPutRules(extracted.putMap, node: json, baseUrl: baseUrl);
    var resolvedRule = _runtimeSupport.replaceGetTokens(current);
    resolvedRule =
        _jsTemplateSupport.applyTemplateJsTokens(resolvedRule, baseUrl: baseUrl);
    if (_runtimeSupport.isLiteralRuleCandidate(current)) {
      return [
        for (final item in _runtimeSupport.splitPossibleListValues(resolvedRule))
          if (item.trim().isNotEmpty) isUrl ? _absoluteUrl(baseUrl, item) : item,
      ];
    }
    if (looksLikeJsonPath(resolvedRule)) {
      final split = splitExprAndReplacements(resolvedRule);
      var expr = split.expr.trim();
      if (expr.startsWith('@Json:')) expr = expr.substring('@Json:'.length).trim();
      if (expr.isEmpty) return const <String>[];
      try {
        final matches = JsonPath(expr).read(json).toList(growable: false);
        if (matches.isEmpty) return const <String>[];
        final out = <String>[];
        for (final match in matches) {
          final value = match.value;
          final values = value is List ? value : <dynamic>[value];
          for (final item in values) {
            if (item == null) continue;
            final text = _querySupport
                .applyInlineReplacements(item.toString(), split.replacements)
                .trim();
            for (final part in _runtimeSupport.splitPossibleListValues(text)) {
              if (part.trim().isNotEmpty) {
                out.add(isUrl ? _absoluteUrl(baseUrl, part) : part);
              }
            }
          }
        }
        return out;
      } catch (_) {
        return const <String>[];
      }
    }
    final value = parseValueOnNode(json, resolvedRule, baseUrl);
    return [
      for (final item in _runtimeSupport.splitPossibleListValues(value))
        if (item.trim().isNotEmpty) isUrl ? _absoluteUrl(baseUrl, item) : item,
    ];
  }
  List<String> parseStringListFromHtml({
    required Element root,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) {
    final raw = rule.trim();
    if (raw.isEmpty) return const <String>[];
    final split = RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(
      raw,
      const ['&&', '||', '%%'],
    );
    if (split.parts.isEmpty) return const <String>[];
    final results = <List<String>>[];
    for (final candidate in split.parts) {
      final out = _parseStringListFromHtmlSingle(root, candidate, baseUrl, isUrl);
      if (out.isNotEmpty) {
        results.add(out);
        if (split.operator == '||') break;
      }
    }
    return _mergeRuleListResults(results, split.operator);
  }
  List<String> parseStringListFromJson({
    required dynamic json,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) {
    final raw = rule.trim();
    if (raw.isEmpty) return const <String>[];
    final split = RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(
      raw,
      const ['&&', '||', '%%'],
    );
    if (split.parts.isEmpty) return const <String>[];
    final results = <List<String>>[];
    for (final candidate in split.parts) {
      final out = _parseStringListFromJsonSingle(json, candidate, baseUrl, isUrl);
      if (out.isNotEmpty) {
        results.add(out);
        if (split.operator == '||') break;
      }
    }
    return _mergeRuleListResults(results, split.operator);
  }
  String parseValueOnNode(dynamic node, String? rule, String baseUrl) {
    if (rule == null || rule.trim().isEmpty) return '';
    final extracted = RuleParserEngineSyntaxHelper.extractPutRules(rule);
    final currentRule = extracted.cleanedRule;
    if (currentRule.isEmpty) return '';
    applyPutRules(extracted.putMap, node: node, baseUrl: baseUrl);
    if (node is Element) return parseRule(node, currentRule, baseUrl);
    final split = RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(
      currentRule,
      const ['&&', '||'],
    );
    if (split.parts.isEmpty) return '';
    final values = <String>[];
    for (final raw in split.parts) {
      final original = raw.trim();
      if (original.isEmpty) continue;
      var current = _runtimeSupport.replaceGetTokens(original);
      current =
          _jsTemplateSupport.applyTemplateJsTokens(current, baseUrl: baseUrl).trim();
      if (current.isEmpty) continue;

      if (_runtimeSupport.isLiteralRuleCandidate(original)) {
        values.add(current);
      } else if (looksLikeJsonPath(current)) {
        final value = parseJsonPathRule(node, current);
        if (value.isNotEmpty) values.add(value);
      } else if (node is Map && node.containsKey(current) && node[current] != null) {
        final value = node[current].toString().trim();
        if (value.isNotEmpty) values.add(value);
      }
      if (values.isNotEmpty && split.operator == '||') break;
    }
    return _mergeRuleTextResults(values, split.operator);
  }
  List<dynamic> selectJsonList(dynamic json, String rawRule) {
    final split = splitExprAndReplacements(rawRule);
    var expr = split.expr.trim();
    if (expr.startsWith('@Json:')) expr = expr.substring('@Json:'.length).trim();
    if (expr.isEmpty) return const <dynamic>[];
    try {
      final matches = JsonPath(expr).read(json).toList(growable: false);
      if (matches.isEmpty) return const <dynamic>[];
      final first = matches.first.value;
      return first is List
          ? first
          : matches.map((match) => match.value).toList(growable: false);
    } catch (_) {
      return const <dynamic>[];
    }
  }
  String parseRegexRuleOnText(String text, String raw) {
    final split = splitExprAndReplacements(raw);
    var expr = split.expr.trimLeft();
    if (!expr.startsWith(':')) return '';
    expr = expr.substring(1).trim();
    if (expr.isEmpty) return '';
    try {
      final match = RegExp(expr, dotAll: true, multiLine: true).firstMatch(text);
      final value = (match?.groupCount ?? 0) >= 1 ? match?.group(1) : match?.group(0);
      return _querySupport.applyInlineReplacements(value ?? '', split.replacements).trim();
    } catch (_) {
      return '';
    }
  }
  String parseRule(
    Element element,
    String? rule,
    String baseUrl, {
    bool urlLikeSingleValue = false,
  }) {
    if (rule == null || rule.isEmpty) return '';
    final extracted = RuleParserEngineSyntaxHelper.extractPutRules(rule);
    final currentRule = extracted.cleanedRule;
    if (currentRule.isEmpty) return '';
    applyPutRules(extracted.putMap, node: element, baseUrl: baseUrl);
    final split = RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(
      currentRule,
      const ['&&', '||'],
    );
    if (split.parts.isEmpty) return '';
    final results = <String>[];
    for (final raw in split.parts) {
      final original = raw.trim();
      if (original.isEmpty) continue;
      var current = _runtimeSupport.replaceGetTokens(original);
      current =
          _jsTemplateSupport.applyTemplateJsTokens(current, baseUrl: baseUrl).trim();
      current = normalizeCssRulePrefix(current).trim();
      if (current.isEmpty) continue;

      final result = _runtimeSupport.isLiteralRuleCandidate(original)
          ? current
          : looksLikeXPath(current)
              ? parseXPathRule(element, current, baseUrl)
              : looksLikeRegexRule(current)
                  ? parseRegexRuleOnText(element.outerHtml, current)
                  : _parseSingleRule(
                      element,
                      current,
                      baseUrl,
                      urlLikeSingleValue: urlLikeSingleValue,
                    );
      if (result.isNotEmpty) {
        results.add(result);
        if (split.operator == '||') break;
      }
    }
    return _mergeRuleTextResults(results, split.operator);
  }
  String _parseSingleRule(
    Element element,
    String rule,
    String baseUrl, {
    bool urlLikeSingleValue = false,
  }) {
    if (rule.isEmpty) return '';
    final parsed = LegadoTextRule.parse(
      rule,
      isExtractor: _querySupport.isExtractorToken,
    );
    final targets = parsed.selectors.isEmpty
        ? <Element>[element]
        : _querySupport.selectAllBySelectors(element, parsed.selectors);
    if (targets.isEmpty) return '';
    final values = <String>[];
    for (final target in targets) {
      var value = _querySupport.extractWithFallbacks(
        target,
        parsed.extractors,
        baseUrl: baseUrl,
      );
      value = _querySupport.applyInlineReplacements(value, parsed.replacements).trim();
      if (value.isNotEmpty) values.add(value);
    }
    if (values.isEmpty) return '';
    return urlLikeSingleValue ? values.first : values.join('\n').trim();
  }
}
