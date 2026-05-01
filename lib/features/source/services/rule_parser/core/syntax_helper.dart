import 'dart:convert';

import 'package:soupreader/features/source/services/rule_parser/parse/legacy_rule_types.dart';

class RuleParserEngineSyntaxHelper {
  static int findBalancedBraceEnd(String source, int openBraceIndex) {
    if (openBraceIndex < 0 || openBraceIndex >= source.length) return -1;
    if (source[openBraceIndex] != '{') return -1;

    var depth = 0;
    String? quote;

    for (var i = openBraceIndex; i < source.length; i++) {
      final ch = source[i];
      if (quote != null) {
        if (ch == '\\' && i + 1 < source.length) {
          i++;
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        continue;
      }

      if (ch == '{') {
        depth++;
        continue;
      }
      if (ch == '}') {
        depth--;
        if (depth == 0) return i;
        if (depth < 0) return -1;
      }
    }
    return -1;
  }

  static List<String> splitByTopLevelComma(String text) {
    final out = <String>[];
    final buffer = StringBuffer();
    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    void push() {
      final one = buffer.toString().trim();
      buffer.clear();
      if (one.isNotEmpty) out.add(one);
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quote != null) {
        buffer.write(ch);
        if (ch == '\\' && i + 1 < text.length) {
          i++;
          buffer.write(text[i]);
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '\\' && i + 1 < text.length) {
        buffer.write(ch);
        i++;
        buffer.write(text[i]);
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buffer.write(ch);
        continue;
      }

      if (ch == '(') parenDepth++;
      if (ch == ')') parenDepth = parenDepth > 0 ? (parenDepth - 1) : 0;
      if (ch == '[') bracketDepth++;
      if (ch == ']') bracketDepth = bracketDepth > 0 ? (bracketDepth - 1) : 0;
      if (ch == '{') braceDepth++;
      if (ch == '}') braceDepth = braceDepth > 0 ? (braceDepth - 1) : 0;

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel && ch == ',') {
        push();
        continue;
      }
      buffer.write(ch);
    }
    push();
    return out;
  }

  static int indexOfTopLevelColon(String text) {
    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quote != null) {
        if (ch == '\\' && i + 1 < text.length) {
          i++;
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        continue;
      }
      if (ch == '(') parenDepth++;
      if (ch == ')') parenDepth = parenDepth > 0 ? (parenDepth - 1) : 0;
      if (ch == '[') bracketDepth++;
      if (ch == ']') bracketDepth = bracketDepth > 0 ? (bracketDepth - 1) : 0;
      if (ch == '{') braceDepth++;
      if (ch == '}') braceDepth = braceDepth > 0 ? (braceDepth - 1) : 0;

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel && ch == ':') {
        return i;
      }
    }
    return -1;
  }

  static String stripPairedQuotes(String text) {
    if (text.length < 2) return text;
    final first = text[0];
    final last = text[text.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  static void mergePutMapFromText(
    String jsonLikeText,
    Map<String, String> putMap,
  ) {
    final text = jsonLikeText.trim();
    if (text.isEmpty) return;

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (key == null || value == null) return;
          final normalizedKey = key.toString().trim();
          if (normalizedKey.isEmpty) return;
          putMap[normalizedKey] = value.toString();
        });
        return;
      }
    } catch (_) {
      // ignore and fallback to宽松解析
    }

    var inner = text;
    if (inner.startsWith('{') && inner.endsWith('}')) {
      inner = inner.substring(1, inner.length - 1).trim();
    }
    if (inner.isEmpty) return;

    final pairs = splitByTopLevelComma(inner);
    for (final pair in pairs) {
      final one = pair.trim();
      if (one.isEmpty) continue;

      final idx = indexOfTopLevelColon(one);
      if (idx <= 0) continue;

      final key = stripPairedQuotes(one.substring(0, idx).trim());
      var value = one.substring(idx + 1).trim();
      value = stripPairedQuotes(value);

      if (key.isEmpty) continue;
      putMap[key] = value;
    }
  }

  static ({String cleanedRule, Map<String, String> putMap}) extractPutRules(
    String rawRule,
  ) {
    if (rawRule.trim().isEmpty) {
      return (cleanedRule: '', putMap: <String, String>{});
    }

    final putMap = <String, String>{};
    final cleaned = StringBuffer();

    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    var index = 0;
    while (index < rawRule.length) {
      final ch = rawRule[index];

      if (quote != null) {
        cleaned.write(ch);
        if (ch == '\\' && index + 1 < rawRule.length) {
          index++;
          cleaned.write(rawRule[index]);
          index++;
          continue;
        }
        if (ch == quote) quote = null;
        index++;
        continue;
      }

      if (ch == '\\' && index + 1 < rawRule.length) {
        cleaned.write(ch);
        index++;
        cleaned.write(rawRule[index]);
        index++;
        continue;
      }

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel && rawRule.startsWith('@put:{', index)) {
        final openBraceIndex = index + '@put:'.length;
        final closeBraceIndex = findBalancedBraceEnd(rawRule, openBraceIndex);
        if (closeBraceIndex > openBraceIndex) {
          final jsonText =
              rawRule.substring(openBraceIndex, closeBraceIndex + 1);
          mergePutMapFromText(jsonText, putMap);
          index = closeBraceIndex + 1;
          continue;
        }
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '(') {
        parenDepth++;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == ')') {
        if (parenDepth > 0) parenDepth--;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '[') {
        bracketDepth++;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == ']') {
        if (bracketDepth > 0) bracketDepth--;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '{') {
        braceDepth++;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '}') {
        if (braceDepth > 0) braceDepth--;
        cleaned.write(ch);
        index++;
        continue;
      }

      cleaned.write(ch);
      index++;
    }

    return (cleanedRule: cleaned.toString().trim(), putMap: putMap);
  }

  static TopLevelRuleSplit splitRuleByTopLevelOperator(
    String raw,
    List<String> operators,
  ) {
    final source = raw.trim();
    if (source.isEmpty) {
      return const TopLevelRuleSplit(
        parts: <String>[],
        operator: null,
      );
    }

    final operatorSet = operators
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (operatorSet.isEmpty) {
      return TopLevelRuleSplit(parts: <String>[source], operator: null);
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
        if (ch == quote) {
          quote = null;
        }
        index++;
        continue;
      }

      if (ch == '\\' && index + 1 < source.length) {
        buffer.write(ch);
        index++;
        buffer.write(source[index]);
        index++;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        buffer.write(ch);
        index++;
        continue;
      }

      if (ch == '(') {
        parenDepth++;
        buffer.write(ch);
        index++;
        continue;
      }
      if (ch == ')') {
        if (parenDepth > 0) parenDepth--;
        buffer.write(ch);
        index++;
        continue;
      }

      if (ch == '[') {
        bracketDepth++;
        buffer.write(ch);
        index++;
        continue;
      }
      if (ch == ']') {
        if (bracketDepth > 0) bracketDepth--;
        buffer.write(ch);
        index++;
        continue;
      }

      if (ch == '{') {
        braceDepth++;
        buffer.write(ch);
        index++;
        continue;
      }
      if (ch == '}') {
        if (braceDepth > 0) braceDepth--;
        buffer.write(ch);
        index++;
        continue;
      }

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel) {
        if (activeOperator == null) {
          for (final candidate in matchOrder) {
            if (source.startsWith(candidate, index)) {
              activeOperator = candidate;
              break;
            }
          }
        }

        if (activeOperator != null &&
            source.startsWith(activeOperator, index)) {
          flush();
          index += activeOperator.length;
          continue;
        }
      }

      buffer.write(ch);
      index++;
    }

    flush();
    if (parts.isEmpty) {
      parts.add(source);
    }
    return TopLevelRuleSplit(parts: parts, operator: activeOperator);
  }
}
