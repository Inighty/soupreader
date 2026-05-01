import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/services/rule_parser/parse/legacy_rule_types.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';
import 'package:soupreader/features/source/services/source/rule_text_utils.dart';

class RuleParserEngineRuleQuerySupport {
  RuleParserEngineRuleQuerySupport(this._ctx);

  final RuleParserContext _ctx;

  RuleParserEngineSelectorSupport get _selectorSupport => _ctx.selectorSupport;
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);

  static const Set<String> _specialExtractors = {
    'text',
    'textnodes',
    'owntext',
    'html',
    'innerhtml',
    'outerhtml',
    'all',
  };

  static const Set<String> _commonAttrExtractors = {
    'href',
    'src',
    'title',
    'alt',
    'value',
    'content',
    'data-src',
    'data-original',
    'data-url',
  };

  bool looksLikeCssSelector(String token) {
    return token.contains(RegExp(r'[ #.:\[\]\(\)>+~*,]')) ||
        token.startsWith('.') ||
        token.startsWith('#') ||
        token.startsWith('class.') ||
        token.startsWith('id.') ||
        token.startsWith('tag.') ||
        token.startsWith('css.');
  }

  bool isExtractorToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty || looksLikeCssSelector(trimmed)) return false;
    final lower = trimmed.toLowerCase();
    if (_specialExtractors.contains(lower) || _commonAttrExtractors.contains(lower)) {
      return true;
    }
    return lower.startsWith('data-') ||
        lower.startsWith('aria-') ||
        trimmed.contains('-') ||
        trimmed.contains('_') ||
        trimmed.contains(':');
  }

  List<Element> selectAllBySelectors(
    dynamic parent,
    List<LegadoSelectorStep> steps,
  ) {
    List<dynamic> contexts = <dynamic>[parent];
    for (final step in steps) {
      final css = step.cssSelector.trim();
      if (css.isEmpty) continue;
      final matched = <Element>[];
      for (final ctx in contexts) {
        if (step.ownTextContains != null) {
          matched.addAll(queryElementsContainingOwnText(ctx, step.ownTextContains!));
        } else if (step.childrenOnly) {
          matched.addAll(queryChildElements(ctx, css));
        } else {
          matched.addAll(queryAllElements(ctx, css));
        }
      }
      final indexSpec = step.indexSpec;
      contexts = indexSpec == null
          ? matched
          : applyLegadoIndexSpec(matched, indexSpec);
      if (contexts.isEmpty) return const <Element>[];
    }
    return contexts.whereType<Element>().toList(growable: false);
  }

  List<Element> queryElementsContainingOwnText(dynamic ctx, String keyword) {
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty) return const <Element>[];
    final root = ctx is Document
        ? ctx.documentElement
        : ctx is Element
            ? ctx
            : null;
    if (root == null) return const <Element>[];

    final out = <Element>[];
    final stack = <Element>[root];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final ownText =
          current.nodes.whereType<Text>().map((node) => node.text).join().toLowerCase();
      if (ownText.contains(needle)) out.add(current);
      for (var i = current.children.length - 1; i >= 0; i--) {
        stack.add(current.children[i]);
      }
    }
    return out;
  }

  List<Element> queryChildElements(dynamic ctx, String css) {
    final children = switch (ctx) {
      Document() => ctx.documentElement?.children.toList(growable: false) ?? const <Element>[],
      Element() => ctx.children.toList(growable: false),
      _ => const <Element>[],
    };
    final trimmed = css.trim();
    if (trimmed.isEmpty || trimmed == '*') return children;
    final allowed = queryAllElements(ctx, css).toSet();
    return children.where(allowed.contains).toList(growable: false);
  }

  List<Element> applyLegadoIndexSpec(
    List<Element> elements,
    LegadoIndexSpec spec,
  ) {
    if (elements.isEmpty) return const <Element>[];
    final len = elements.length;
    final indexSet = <int>{};
    for (final term in spec.terms) {
      if (!term.isRange) {
        final normalized = _normalizeLegadoIndex(term.value!, len);
        if (normalized != null) indexSet.add(normalized);
      } else {
        indexSet.addAll(_expandLegadoRange(term, len));
      }
    }
    if (indexSet.isEmpty) {
      return spec.exclude ? elements : const <Element>[];
    }
    if (spec.exclude) {
      return [
        for (var i = 0; i < len; i++)
          if (!indexSet.contains(i)) elements[i],
      ];
    }
    return [for (final idx in indexSet) elements[idx]];
  }

  int? _normalizeLegadoIndex(int index, int len) {
    if (index >= 0) return index < len ? index : null;
    return len >= -index ? index + len : null;
  }

  Iterable<int> _expandLegadoRange(LegadoIndexTerm range, int len) sync* {
    var start = range.start ?? 0;
    if (start < 0) start += len;
    var end = range.end ?? (len - 1);
    if (end < 0) end += len;
    if ((start < 0 && end < 0) || (start >= len && end >= len)) return;
    start = start >= len ? len - 1 : (start < 0 ? 0 : start);
    end = end >= len ? len - 1 : (end < 0 ? 0 : end);

    final rawStep = range.step;
    if (start == end || rawStep >= len) {
      yield start;
      return;
    }

    final step = rawStep > 0 ? rawStep : ((-rawStep) < len ? rawStep + len : 1);
    if (step <= 0) {
      yield start;
      return;
    }

    if (end > start) {
      for (var i = start; i <= end; i += step) {
        yield i;
      }
      return;
    }
    for (var i = start; i >= end; i -= step) {
      yield i;
    }
  }

  List<Element> queryAllElements(dynamic ctx, String css) {
    return _selectorSupport.queryAllElements(ctx, css);
  }

  Element? selectFirstElementByRule(dynamic parent, String selectorRule) {
    final all = _selectorSupport.selectAllElementsByRule(parent, selectorRule);
    return all.isEmpty ? null : all.first;
  }

  String extractWithFallbacks(
    Element target,
    List<String> extractors, {
    required String baseUrl,
  }) {
    for (final extractor in extractors) {
      final token = extractor.trim();
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();
      var value = switch (lower) {
        'text' => target.text,
        'textnodes' => extractTextNodesLikeLegado(target),
        'owntext' => extractOwnTextLikeLegado(target),
        'html' || 'innerhtml' => extractHtmlLikeLegado(target),
        'outerhtml' || 'all' => target.outerHtml,
        _ =>
          target.attributes[token] ??
              target.attributes[lower] ??
              target.attributes[token.toLowerCase()] ??
              '',
      };
      value = value.trim();
      if (value.isEmpty) continue;
      if (lower == 'href' || lower == 'src') value = _absoluteUrl(baseUrl, value);
      return value;
    }
    return '';
  }

  String extractTextNodesLikeLegado(Element target) {
    return target.nodes
        .whereType<Text>()
        .map((node) => node.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  String extractOwnTextLikeLegado(Element target) {
    final buf = StringBuffer();
    for (final node in target.nodes.whereType<Text>()) {
      buf.write(node.text);
    }
    return buf.toString();
  }

  String extractHtmlLikeLegado(Element target) {
    final fragment = html_parser.parseFragment(target.outerHtml);
    for (final node in fragment.querySelectorAll('script')) {
      node.remove();
    }
    for (final node in fragment.querySelectorAll('style')) {
      node.remove();
    }
    return fragment.nodes.map((node) {
      if (node is Element) return node.outerHtml;
      if (node is Text) return node.text;
      return node.toString();
    }).join();
  }

  String applyInlineReplacements(
    String input,
    List<LegadoReplacePair> replacements,
  ) {
    var result = input;
    for (final replacement in replacements) {
      if (replacement.pattern.isEmpty) continue;
      result = RuleTextUtils.applyLegacyReplace(
        content: result,
        pattern: replacement.pattern,
        replacement: replacement.replacement,
        firstOnly: replacement.firstOnly,
      );
    }
    return result;
  }
}
