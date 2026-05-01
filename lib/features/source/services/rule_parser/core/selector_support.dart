import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

import 'package:soupreader/features/source/services/rule_parser/parse/legacy_rule_types.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineSelectorSupport {
  RuleParserEngineSelectorSupport(this._ctx);

  final RuleParserContext _ctx;

  String _normalizeCssRulePrefix(String raw) =>
      _ctx.ruleParseSupport.normalizeCssRulePrefix(raw);
  bool _looksLikeXPath(String rule) =>
      _ctx.ruleParseSupport.looksLikeXPath(rule);
  ({String expr, List<LegadoReplacePair> replacements})
      _splitExprAndReplacements(String raw) =>
          _ctx.ruleParseSupport.splitExprAndReplacements(raw);
  bool _looksLikeRegexRule(String rule) =>
      _ctx.ruleParseSupport.looksLikeRegexRule(rule);
  bool _isExtractorToken(String token) =>
      _ctx.ruleQuerySupport.isExtractorToken(token);
  List<Element> _selectAllBySelectors(
    dynamic parent,
    List<LegadoSelectorStep> steps,
  ) =>
      _ctx.ruleQuerySupport.selectAllBySelectors(parent, steps);

  List<Element> queryAllElements(dynamic ctx, String css) {
    if (css.trim().isEmpty) return const <Element>[];
    try {
      if (_containsNthPseudo(css)) {
        return _querySelectorAllCompat(ctx, css);
      }
      if (ctx is Document) return ctx.querySelectorAll(css);
      if (ctx is Element) return ctx.querySelectorAll(css);
    } catch (error) {
      debugPrint('选择器解析失败: $css - $error');
    }
    return const <Element>[];
  }

  List<Element> selectAllElementsByRule(
    dynamic parent,
    String selectorRule, {
    String? rawHtml,
  }) {
    final raw = _normalizeCssRulePrefix(selectorRule).trim();
    if (raw.isEmpty) return const <Element>[];

    if (_looksLikeXPath(raw)) {
      final split = _splitExprAndReplacements(raw);
      var expr = split.expr;
      if (expr.startsWith('@XPath:')) {
        expr = expr.substring('@XPath:'.length).trim();
      }
      if (expr.isEmpty) return const <Element>[];
      try {
        final root = parent is Document
            ? parent.documentElement
            : parent is Element
                ? parent
                : null;
        if (root == null) return const <Element>[];
        final result = HtmlXPath.node(root).query(expr);
        return result.nodes
            .where((node) => node.isElement)
            .map((node) => (node as HtmlNodeTree).element)
            .toList(growable: false);
      } catch (error) {
        debugPrint('XPath 列表解析失败: $expr - $error');
        return const <Element>[];
      }
    }

    if (_looksLikeRegexRule(raw)) {
      final split = _splitExprAndReplacements(raw);
      var expr = split.expr.trimLeft();
      expr = expr.startsWith(':') ? expr.substring(1).trim() : expr;
      if (expr.isEmpty) return const <Element>[];

      final htmlText = rawHtml ??
          (parent is Document
              ? parent.documentElement?.outerHtml
              : parent is Element
                  ? parent.outerHtml
                  : null) ??
          '';
      if (htmlText.isEmpty) return const <Element>[];

      try {
        final re = RegExp(expr, dotAll: true, multiLine: true);
        final out = <Element>[];
        for (final match in re.allMatches(htmlText)) {
          final snippet =
              (match.groupCount >= 1 ? match.group(1) : match.group(0)) ?? '';
          if (snippet.trim().isEmpty) continue;
          final wrapper = html_parser
              .parse('<div>$snippet</div>')
              .documentElement
              ?.querySelector('div');
          if (wrapper != null) out.add(wrapper);
        }
        return out;
      } catch (error) {
        debugPrint('Regex 列表解析失败: $expr - $error');
        return const <Element>[];
      }
    }

    final parsed = LegadoTextRule.parse(
      raw,
      isExtractor: _isExtractorToken,
    );
    return _selectAllBySelectors(parent, parsed.selectors);
  }

  bool _containsNthPseudo(String css) {
    final lower = css.toLowerCase();
    return lower.contains(':nth-child(') ||
        lower.contains(':nth-last-child(') ||
        lower.contains(':nth-of-type(') ||
        lower.contains(':nth-last-of-type(');
  }

  List<String> _splitSelectorGroups(String selector) {
    final out = <String>[];
    final buf = StringBuffer();
    var bracket = 0;
    var paren = 0;
    String? quote;

    void flush() {
      final value = buf.toString().trim();
      buf.clear();
      if (value.isNotEmpty) out.add(value);
    }

    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '[') bracket++;
      if (ch == ']') bracket = bracket > 0 ? (bracket - 1) : 0;
      if (ch == '(') paren++;
      if (ch == ')') paren = paren > 0 ? (paren - 1) : 0;

      if (ch == ',' && bracket == 0 && paren == 0) {
        flush();
        continue;
      }
      buf.write(ch);
    }
    flush();
    return out;
  }

  NthExpr? _parseNthExpr(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '');
    if (normalized.isEmpty) return null;
    if (normalized == 'odd') return const NthExpr(a: 2, b: 1);
    if (normalized == 'even') return const NthExpr(a: 2, b: 0);

    if (!normalized.contains('n')) {
      final value = int.tryParse(normalized);
      return value == null ? null : NthExpr(a: 0, b: value);
    }

    final parts = normalized.split('n');
    final aPart = parts.isNotEmpty ? parts.first : '';
    final bPart = parts.length >= 2 ? parts[1] : '';

    int a;
    if (aPart.isEmpty || aPart == '+') {
      a = 1;
    } else if (aPart == '-') {
      a = -1;
    } else {
      a = int.tryParse(aPart) ?? 0;
    }

    final b = bPart.isNotEmpty ? (int.tryParse(bPart) ?? 0) : 0;
    return NthExpr(a: a, b: b);
  }

  bool _matchesNth(NthExpr expr, int position1Based) {
    final a = expr.a;
    final b = expr.b;
    final position = position1Based;
    if (position <= 0) return false;

    if (a == 0) return position == b;
    if (a > 0) {
      final diff = position - b;
      if (diff < 0) return false;
      return diff % a == 0;
    }

    final diff = b - position;
    if (diff < 0) return false;
    return diff % (-a) == 0;
  }

  List<SelectorStepCompat> _tokenizeSelectorChain(String selector) {
    final steps = <SelectorStepCompat>[];
    final buf = StringBuffer();

    var bracket = 0;
    var paren = 0;
    String? quote;

    void pushStep(String combinator) {
      final raw = buf.toString().trim();
      buf.clear();
      if (raw.isEmpty) return;
      final extracted = _extractNthFilters(raw);
      steps.add(
        SelectorStepCompat(
          combinator: combinator,
          selector: extracted.baseSelector,
          nthFilters: extracted.filters,
        ),
      );
    }

    var pendingCombinator = '';

    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '[') bracket++;
      if (ch == ']') bracket = bracket > 0 ? (bracket - 1) : 0;
      if (ch == '(') paren++;
      if (ch == ')') paren = paren > 0 ? (paren - 1) : 0;

      final isTopLevel = bracket == 0 && paren == 0;
      if (isTopLevel && (ch == '>' || ch == '+' || ch == '~')) {
        pushStep(pendingCombinator);
        pendingCombinator = ch;
        continue;
      }

      if (isTopLevel && ch.trim().isEmpty) {
        if (buf.isNotEmpty) {
          pushStep(pendingCombinator);
          pendingCombinator = ' ';
        } else {
          pendingCombinator =
              pendingCombinator.isEmpty ? ' ' : pendingCombinator;
        }
        continue;
      }

      buf.write(ch);
    }
    pushStep(pendingCombinator);

    if (steps.isNotEmpty) {
      final first = steps.first;
      steps[0] = SelectorStepCompat(
        combinator: '',
        selector: first.selector,
        nthFilters: first.nthFilters,
      );
    }
    return steps;
  }

  NthExtractResult _extractNthFilters(String rawSelectorPart) {
    var selector = rawSelectorPart;
    final filters = <NthFilter>[];
    final kinds = <String>[
      'nth-child',
      'nth-last-child',
      'nth-of-type',
      'nth-last-of-type',
    ];

    for (final kind in kinds) {
      while (true) {
        final lower = selector.toLowerCase();
        final idx = lower.indexOf(':$kind(');
        if (idx < 0) break;

        final start = idx + kind.length + 2;
        var depth = 1;
        var end = -1;
        for (var i = start; i < selector.length; i++) {
          final ch = selector[i];
          if (ch == '(') depth++;
          if (ch == ')') depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
        if (end < 0) break;
        final exprText = selector.substring(start, end);
        final expr = _parseNthExpr(exprText);
        if (expr != null) {
          filters.add(NthFilter(kind: kind, expr: expr));
        }
        selector =
            (selector.substring(0, idx) + selector.substring(end + 1)).trim();
      }
    }

    if (selector.trim().isEmpty) selector = '*';
    return NthExtractResult(
      baseSelector: selector.trim(),
      filters: filters,
    );
  }

  List<Element> _querySelectorAllCompat(dynamic ctx, String selector) {
    final groups = _splitSelectorGroups(selector);
    if (groups.isEmpty) return const <Element>[];

    final out = <Element>[];
    final seen = <Element>{};
    for (final group in groups) {
      final one = _querySelectorAllCompatSingle(ctx, group);
      for (final element in one) {
        if (seen.add(element)) out.add(element);
      }
    }
    return out;
  }

  List<Element> _querySelectorAllCompatSingle(dynamic ctx, String selector) {
    final chain = _tokenizeSelectorChain(selector);
    if (chain.isEmpty) return const <Element>[];

    List<Element> contexts;
    if (ctx is Document) {
      final root = ctx.documentElement;
      contexts = root == null ? const <Element>[] : <Element>[root];
    } else if (ctx is Element) {
      contexts = <Element>[ctx];
    } else {
      return const <Element>[];
    }

    List<Element> queryDescendants(Element root, String css) {
      try {
        return root.querySelectorAll(css);
      } catch (error) {
        debugPrint('选择器解析失败(compat): $css - $error');
        return const <Element>[];
      }
    }

    List<Element> applyNthFilters(
      List<Element> elements,
      List<NthFilter> filters,
    ) {
      if (filters.isEmpty || elements.isEmpty) return elements;
      return elements.where((element) {
        final parent = element.parent;
        if (parent is! Element) return false;
        final siblings = parent.children;
        final idx = siblings.indexOf(element);
        if (idx < 0) return false;

        for (final filter in filters) {
          int pos;
          if (filter.kind == 'nth-child') {
            pos = idx + 1;
          } else if (filter.kind == 'nth-last-child') {
            pos = siblings.length - idx;
          } else if (filter.kind == 'nth-of-type' ||
              filter.kind == 'nth-last-of-type') {
            final tag = (element.localName ?? '').toLowerCase();
            final sameType = siblings
                .where((item) => (item.localName ?? '').toLowerCase() == tag)
                .toList(growable: false);
            final typeIdx = sameType.indexOf(element);
            if (typeIdx < 0) return false;
            pos = filter.kind == 'nth-of-type'
                ? (typeIdx + 1)
                : (sameType.length - typeIdx);
          } else {
            continue;
          }

          if (!_matchesNth(filter.expr, pos)) return false;
        }
        return true;
      }).toList(growable: false);
    }

    for (final step in chain) {
      final combinator = step.combinator.isEmpty ? ' ' : step.combinator;
      final css = step.selector.trim();
      if (css.isEmpty) return const <Element>[];

      final matched = <Element>[];
      if (combinator == ' ') {
        for (final context in contexts) {
          matched.addAll(queryDescendants(context, css));
        }
      } else if (combinator == '>') {
        for (final context in contexts) {
          final all = queryDescendants(context, css);
          matched.addAll(all.where((item) => item.parent == context));
        }
      } else if (combinator == '+') {
        for (final context in contexts) {
          final parent = context.parent;
          if (parent is! Element) continue;
          final siblings = parent.children;
          final idx = siblings.indexOf(context);
          if (idx < 0 || idx + 1 >= siblings.length) continue;
          final candidate = siblings[idx + 1];
          final allowed = queryDescendants(parent, css).toSet();
          if (allowed.contains(candidate)) matched.add(candidate);
        }
      } else if (combinator == '~') {
        for (final context in contexts) {
          final parent = context.parent;
          if (parent is! Element) continue;
          final siblings = parent.children;
          final idx = siblings.indexOf(context);
          if (idx < 0) continue;
          final allowed = queryDescendants(parent, css).toSet();
          for (var i = idx + 1; i < siblings.length; i++) {
            final candidate = siblings[i];
            if (allowed.contains(candidate)) matched.add(candidate);
          }
        }
      } else {
        for (final context in contexts) {
          matched.addAll(queryDescendants(context, css));
        }
      }

      contexts = applyNthFilters(matched, step.nthFilters);
      if (contexts.isEmpty) return const <Element>[];
    }

    return contexts;
  }
}
