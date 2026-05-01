class LegadoTextRule {
  final List<LegadoSelectorStep> selectors;
  final List<String> extractors;
  final List<LegadoReplacePair> replacements;

  const LegadoTextRule({
    required this.selectors,
    required this.extractors,
    required this.replacements,
  });

  static LegadoTextRule parse(
    String raw, {
    required bool Function(String token) isExtractor,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const LegadoTextRule(
        selectors: <LegadoSelectorStep>[],
        extractors: <String>['text'],
        replacements: <LegadoReplacePair>[],
      );
    }

    final parts = trimmed.split('##');
    final pipeline = parts.first.trim();

    final replacements = <LegadoReplacePair>[];
    if (parts.length > 1) {
      final rep = parts.sublist(1).toList(growable: false);
      var start = 0;
      // 对齐 legado：当 replace 段为奇数时，首段按 replaceFirst 处理（如 `##a##b###`）。
      if (rep.length >= 3 && rep.length.isOdd) {
        final firstPattern = rep[0].trim();
        if (firstPattern.isNotEmpty) {
          replacements.add(
            LegadoReplacePair(
              pattern: firstPattern,
              replacement: rep[1],
              firstOnly: true,
            ),
          );
        }
        start = 3;
      }

      for (var i = start; i < rep.length; i += 2) {
        final pattern = rep[i].trim();
        final replacement = (i + 1) < rep.length ? rep[i + 1] : '';
        if (pattern.isEmpty) continue;
        replacements.add(
          LegadoReplacePair(
            pattern: pattern,
            replacement: replacement,
          ),
        );
      }
    }

    final tokens = pipeline
        .split('@')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    // 从末尾识别 extractor（对标 legado：h1@title@text 表示 title 为空则取 text）
    final startsWithAt = pipeline.startsWith('@');
    var cut = tokens.length;
    final extractors = <String>[];
    if (startsWithAt) {
      // 兼容 legado 写法：@href / @textNodes 等表示“当前元素取属性/文本”
      for (final token in tokens) {
        if (isExtractor(token)) extractors.add(token);
      }
      cut = 0;
    } else if (tokens.length == 1 && isExtractor(tokens.first)) {
      // 对齐 legado：单 token 规则如 text / href 视为“当前元素 extractor”，
      // 不能当作 selector，否则会出现 chapterName=text / chapterUrl=href 取值为空。
      extractors.add(tokens.first);
      cut = 0;
    } else if (tokens.length >= 2) {
      while (cut > 0) {
        final candidate = tokens[cut - 1];
        if (!isExtractor(candidate)) break;
        extractors.insert(0, candidate);
        cut--;
      }
    }

    final selectors = <LegadoSelectorStep>[];
    for (final token in tokens.take(cut)) {
      final step = LegadoSelectorStep.tryParse(token);
      if (step != null) selectors.add(step);
    }

    return LegadoTextRule(
      selectors: selectors,
      extractors: extractors.isEmpty ? const <String>['text'] : extractors,
      replacements: replacements,
    );
  }
}

class LegadoSelectorStep {
  final String cssSelector;
  final LegadoIndexSpec? indexSpec;
  final bool childrenOnly;
  final String? ownTextContains;

  const LegadoSelectorStep({
    required this.cssSelector,
    required this.indexSpec,
    this.childrenOnly = false,
    this.ownTextContains,
  });

  static LegadoSelectorStep? tryParse(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;

    var base = trimmed;
    LegadoIndexSpec? indexSpec;

    final bracketParsed = _tryParseBracketIndex(trimmed);
    if (bracketParsed != null) {
      base = bracketParsed.base;
      indexSpec = bracketParsed.spec;
    } else {
      final dotParsed = _tryParseDotIndex(trimmed);
      if (dotParsed != null) {
        base = dotParsed.base;
        indexSpec = dotParsed.spec;
      }
    }

    final selectorBase = _parseLegacySelectorBase(base);
    if (selectorBase.textSelector &&
        (selectorBase.ownTextContains == null ||
            selectorBase.ownTextContains!.isEmpty)) {
      return null;
    }

    base = selectorBase.cssBase;
    final css = _toCssSelector(base);
    if (css.trim().isEmpty) {
      // 对齐 legado：允许仅写索引（如 [0]），语义等价于当前节点 children。
      if (indexSpec != null && base.trim().isEmpty) {
        return LegadoSelectorStep(
          cssSelector: '*',
          indexSpec: indexSpec,
          childrenOnly: true,
          ownTextContains: null,
        );
      }
      return null;
    }
    return LegadoSelectorStep(
      cssSelector: css,
      indexSpec: indexSpec,
      childrenOnly: selectorBase.childrenOnly,
      ownTextContains: selectorBase.ownTextContains,
    );
  }

  static ({
    String cssBase,
    bool childrenOnly,
    bool textSelector,
    String? ownTextContains,
  }) _parseLegacySelectorBase(String raw) {
    final trimmed = raw.trim();
    if (trimmed == 'children' || trimmed.startsWith('children.')) {
      return (
        cssBase: '*',
        childrenOnly: true,
        textSelector: false,
        ownTextContains: null,
      );
    }

    if (trimmed.startsWith('text.')) {
      var keyword = trimmed.substring('text.'.length);
      final nextDot = keyword.indexOf('.');
      if (nextDot >= 0) {
        keyword = keyword.substring(0, nextDot);
      }
      keyword = keyword.trim();
      return (
        cssBase: '*',
        childrenOnly: false,
        textSelector: true,
        ownTextContains: keyword.isEmpty ? null : keyword,
      );
    }

    return (
      cssBase: trimmed,
      childrenOnly: false,
      textSelector: false,
      ownTextContains: null,
    );
  }

  static ({String base, LegadoIndexSpec spec})? _tryParseDotIndex(String token) {
    ({String base, LegadoIndexSpec spec})? parseBySplit(
      int splitPos, {
      required bool exclude,
    }) {
      if (splitPos < 0 || splitPos >= token.length - 1) return null;
      final body = token.substring(splitPos + 1).trim();
      final values = _parseLegacyColonIndexes(body);
      if (values == null || values.isEmpty) return null;
      final base = token.substring(0, splitPos).trimRight();
      return (
        base: base,
        spec: LegadoIndexSpec(
          exclude: exclude,
          terms: values
              .map((value) => LegadoIndexTerm.value(value))
              .toList(growable: false),
        ),
      );
    }

    // 旧语法：selector!0:3（排除）
    final bangPos = token.lastIndexOf('!');
    if (bangPos >= 0) {
      final parsed = parseBySplit(bangPos, exclude: true);
      if (parsed != null) return parsed;
    }

    // 旧语法：selector.-1:10:2（选择）
    for (var pos = token.length - 1; pos >= 0; pos--) {
      if (token[pos] != '.') continue;
      final parsed = parseBySplit(pos, exclude: false);
      if (parsed != null) return parsed;
    }

    return null;
  }

  static List<int>? _parseLegacyColonIndexes(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final out = <int>[];
    for (final part in trimmed.split(':')) {
      final value = int.tryParse(part.trim());
      if (value == null) return null;
      out.add(value);
    }
    return out;
  }

  static ({String base, LegadoIndexSpec spec})? _tryParseBracketIndex(
    String token,
  ) {
    if (!token.endsWith(']')) return null;
    final start = _findTrailingBracketStart(token);
    if (start < 0) return null;

    final body = token.substring(start + 1, token.length - 1).trim();
    if (body.isEmpty) return null;

    // 只接受 legado 索引语法字符，避免把 CSS 属性选择器误判为索引列表。
    for (final rune in body.runes) {
      final ch = String.fromCharCode(rune);
      final isDigit = rune >= 0x30 && rune <= 0x39;
      final isAllowed = isDigit ||
          ch == '-' ||
          ch == ':' ||
          ch == ',' ||
          ch == '!' ||
          ch == ' ';
      if (!isAllowed) return null;
    }

    var includeBody = body;
    var exclude = false;
    if (includeBody.startsWith('!')) {
      exclude = true;
      includeBody = includeBody.substring(1).trimLeft();
      if (includeBody.isEmpty) return null;
    }

    final terms = <LegadoIndexTerm>[];
    final segments = includeBody.split(',');
    for (final segment in segments) {
      final raw = segment.trim();
      if (raw.isEmpty) return null;

      final colonCount = ':'.allMatches(raw).length;
      if (colonCount == 0) {
        final value = int.tryParse(raw);
        if (value == null) return null;
        terms.add(LegadoIndexTerm.value(value));
        continue;
      }

      if (colonCount > 2) return null;
      final parts = raw.split(':');
      if (parts.length < 2 || parts.length > 3) return null;

      int? parseNullableInt(String value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return int.tryParse(trimmed);
      }

      final startRaw = parts[0].trim();
      final endRaw = parts[1].trim();
      final stepRaw = parts.length == 3 ? parts[2].trim() : '';

      final startVal = parseNullableInt(parts[0]);
      final endVal = parseNullableInt(parts[1]);
      if (startRaw.isNotEmpty && startVal == null) return null;
      if (endRaw.isNotEmpty && endVal == null) return null;

      var stepVal = 1;
      if (parts.length == 3) {
        final parsedStep = parseNullableInt(parts[2]);
        if (stepRaw.isNotEmpty && parsedStep == null) return null;
        stepVal = parsedStep ?? 1;
      }
      if (stepVal == 0) stepVal = 1;

      terms.add(
        LegadoIndexTerm.range(
          start: startVal,
          end: endVal,
          step: stepVal,
        ),
      );
    }

    if (terms.isEmpty) return null;
    final base = token.substring(0, start).trimRight();
    return (
      base: base,
      spec: LegadoIndexSpec(
        exclude: exclude,
        terms: terms,
      ),
    );
  }

  static int _findTrailingBracketStart(String token) {
    var depth = 0;
    for (var i = token.length - 1; i >= 0; i--) {
      final ch = token[i];
      if (ch == ']') {
        depth++;
        continue;
      }
      if (ch != '[') continue;
      depth--;
      if (depth == 0) return i;
      if (depth < 0) return -1;
    }
    return -1;
  }

  static String _toCssSelector(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('class.')) {
      return '.${trimmed.substring('class.'.length)}';
    }
    if (trimmed.startsWith('id.')) {
      return '#${trimmed.substring('id.'.length)}';
    }
    if (trimmed.startsWith('tag.')) {
      return trimmed.substring('tag.'.length);
    }
    if (trimmed.startsWith('css.')) {
      return trimmed.substring('css.'.length);
    }
    return trimmed;
  }
}

class LegadoIndexSpec {
  final bool exclude;
  final List<LegadoIndexTerm> terms;

  const LegadoIndexSpec({
    this.exclude = false,
    required this.terms,
  });
}

class LegadoIndexTerm {
  final int? value;
  final int? start;
  final int? end;
  final int step;

  const LegadoIndexTerm.value(int value)
      : this._(
          value: value,
          start: null,
          end: null,
          step: 1,
        );

  const LegadoIndexTerm.range({
    required int? start,
    required int? end,
    required int step,
  }) : this._(
          value: null,
          start: start,
          end: end,
          step: step,
        );

  const LegadoIndexTerm._({
    required this.value,
    required this.start,
    required this.end,
    required this.step,
  });

  bool get isRange => value == null;
}

class LegadoReplacePair {
  final String pattern;
  final String replacement;
  final bool firstOnly;

  const LegadoReplacePair({
    required this.pattern,
    required this.replacement,
    this.firstOnly = false,
  });
}

class TopLevelRuleSplit {
  final List<String> parts;
  final String? operator;

  const TopLevelRuleSplit({
    required this.parts,
    required this.operator,
  });
}
