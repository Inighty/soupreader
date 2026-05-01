/// Pure text processing utilities extracted from [RuleParserEngine].
///
/// These functions implement Legado-compatible rule replacement and text
/// extraction logic. They are stateless and have no external dependencies,
/// making them easy to test.
class RuleTextUtils {
  RuleTextUtils._();

  /// Applies a Legado-format replacement regex chain to [content].
  ///
  /// Format: `regex##replacement##regex2##replacement2...`
  ///
  /// Special case: when there are an odd number of parts (>= 3), the first
  /// pair uses `replaceFirst` semantics (Legado `###` suffix).
  static String applyReplaceRegex(String content, String replaceRegex) {
    final parts = replaceRegex.split('##');
    if (parts.isEmpty) return content;

    var result = content;
    var start = 0;

    if (parts.length >= 3 && parts.length.isOdd) {
      final pattern = parts[0];
      if (pattern.isNotEmpty) {
        final replacement = parts[1];
        result = applyLegacyReplace(
          content: result,
          pattern: pattern,
          replacement: replacement,
          firstOnly: true,
        );
      }
      start = 3;
    }

    for (int i = start; i < parts.length - 1; i += 2) {
      final pattern = parts[i];
      if (pattern.isEmpty) continue;
      final replacement = parts.length > i + 1 ? parts[i + 1] : '';
      result = applyLegacyReplace(
        content: result,
        pattern: pattern,
        replacement: replacement,
        firstOnly: false,
      );
    }

    return result;
  }

  /// Applies a single regex replacement.
  ///
  /// When [firstOnly] is `true`, only the first match is replaced, and if
  /// no match is found, the result is an empty string (Legado semantics).
  static String applyLegacyReplace({
    required String content,
    required String pattern,
    required String replacement,
    required bool firstOnly,
  }) {
    if (pattern.isEmpty) return content;

    if (firstOnly) {
      try {
        final regex = RegExp(pattern);
        final matcher = regex.firstMatch(content);
        if (matcher == null) return '';
        final matchedText = matcher.group(0) ?? '';
        return matchedText.replaceFirst(regex, replacement);
      } catch (_) {
        return replacement;
      }
    }

    try {
      return content.replaceAll(RegExp(pattern), replacement);
    } catch (_) {
      return content.replaceAll(pattern, replacement);
    }
  }

  /// Splits a rule string by top-level operators (`&&`, `||`, etc.), respecting
  /// quotes, parentheses, brackets, and braces.
  ///
  /// Returns a [RuleSplitResult] with the list of parts and the operator used.
  static RuleSplitResult splitByTopLevelOperator(
    String raw,
    List<String> operators,
  ) {
    final source = raw.trim();
    if (source.isEmpty) {
      return const RuleSplitResult(parts: [], operator: null);
    }

    final operatorSet = operators
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (operatorSet.isEmpty) {
      return RuleSplitResult(parts: [source], operator: null);
    }

    final matchOrder = operatorSet.toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));

    final parts = <String>[];
    final buffer = StringBuffer();
    String? activeOperator;

    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    void flush() {
      final value = buffer.toString().trim();
      buffer.clear();
      if (value.isNotEmpty) {
        parts.add(value);
      }
    }

    var index = 0;
    while (index < source.length) {
      final ch = source[index];

      if (quote != null) {
        buffer.write(ch);
        if (ch == '\\' && index + 1 < source.length) {
          index++;
          buffer.write(source[index]);
          index++;
          continue;
        }
        if (ch == quote) quote = null;
        index++;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        buffer.write(ch);
        index++;
        continue;
      }

      if (ch == '(') parenDepth++;
      if (ch == ')') parenDepth = (parenDepth - 1).clamp(0, 999);
      if (ch == '[') bracketDepth++;
      if (ch == ']') bracketDepth = (bracketDepth - 1).clamp(0, 999);
      if (ch == '{') braceDepth++;
      if (ch == '}') braceDepth = (braceDepth - 1).clamp(0, 999);

      final isNested =
          parenDepth > 0 || bracketDepth > 0 || braceDepth > 0;
      if (!isNested) {
        var matched = false;
        for (final op in matchOrder) {
          if (index + op.length <= source.length &&
              source.substring(index, index + op.length) == op) {
            if (activeOperator != null && activeOperator != op) {
              buffer.write(ch);
              index++;
              matched = true;
              break;
            }
            activeOperator ??= op;
            flush();
            index += op.length;
            matched = true;
            break;
          }
        }
        if (matched) continue;
      }

      buffer.write(ch);
      index++;
    }
    flush();

    return RuleSplitResult(parts: parts, operator: activeOperator);
  }

  /// Normalizes a URL by trimming whitespace and collapsing redundant schemes.
  static String normalizeUrl(String url) {
    var result = url.trim();
    if (result.isEmpty) return result;
    // Some sources produce double scheme like http://http://...
    if (result.startsWith('http://http://') ||
        result.startsWith('http://https://')) {
      result = result.substring(7);
    }
    if (result.startsWith('https://http://') ||
        result.startsWith('https://https://')) {
      result = result.substring(8);
    }
    return result;
  }
}

/// Result of [RuleTextUtils.splitByTopLevelOperator].
class RuleSplitResult {
  final List<String> parts;
  final String? operator;

  const RuleSplitResult({
    required this.parts,
    required this.operator,
  });
}
