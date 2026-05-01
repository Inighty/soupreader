import 'dart:convert';

import 'package:soupreader/features/source/services/rule_parser/core/runtime_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/syntax_helper.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineJsTemplateSupport {
  RuleParserEngineJsTemplateSupport(this._ctx);

  final RuleParserContext _ctx;

  RuleParserEngineRuntimeSupport get _runtimeSupport => _ctx.runtimeSupport;
  String _evalJsMaybeString({
    required String js,
    String? jsLib,
    Map<String, Object?> bindings = const {},
  }) =>
      _ctx.jsSupport
          .evalJsMaybeString(js: js, jsLib: jsLib, bindings: bindings);

  bool _looksLikeXPath(String rule) {
    final trimmed = rule.trimLeft();
    return trimmed.startsWith('@XPath:') || trimmed.startsWith('//');
  }

  bool _looksLikeJsonPath(String rule) {
    final trimmed = rule.trimLeft();
    return trimmed.startsWith('@Json:') ||
        trimmed == r'$' ||
        trimmed.startsWith(r'$.') ||
        trimmed.startsWith(r'$[') ||
        trimmed.startsWith(r'$..');
  }

  bool _looksLikeRegexRule(String rule) => rule.trimLeft().startsWith(':');

  Map<String, Object?> _buildUrlJsBindings({
    required String baseUrl,
    required String result,
    required Map<String, String> params,
  }) {
    final bindings = <String, Object?>{
      'baseUrl': baseUrl,
      'result': result,
      'vars': _runtimeSupport.runtimeVariableSnapshot(desensitize: false),
      'params': Map<String, String>.from(params),
    };
    for (final entry in params.entries) {
      final key = entry.key.trim();
      if (key.isNotEmpty) bindings[key] = entry.value;
    }
    return bindings;
  }

  String? _resolveUrlJsAtom(
    String atom, {
    required String baseUrl,
    required String result,
    required Map<String, String> params,
  }) {
    final trimmed = atom.trim();
    if (trimmed.isEmpty) return '';
    final literal = decodeSimpleJsStringLiteral(trimmed);
    if (literal != null) return literal;
    if (trimmed == '@result' || trimmed == 'result') return result;
    if (trimmed == 'baseUrl') return baseUrl;
    if (trimmed.startsWith('params[') && trimmed.endsWith(']')) {
      return params[decodeJsIndexKey(trimmed.substring(7, trimmed.length - 1).trim())] ?? '';
    }
    final paramsDot =
        RegExp(r'^params\.([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(trimmed);
    if (paramsDot != null) return params[paramsDot.group(1) ?? ''] ?? '';
    if (trimmed.startsWith('vars[') && trimmed.endsWith(']')) {
      return _runtimeSupport.getRuntimeVariable(
        decodeJsIndexKey(trimmed.substring(5, trimmed.length - 1).trim()),
      );
    }
    final varsDot =
        RegExp(r'^vars\.([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(trimmed);
    if (varsDot != null) {
      return _runtimeSupport.getRuntimeVariable(varsDot.group(1) ?? '');
    }
    final fromParams = params[trimmed];
    if (fromParams != null) return fromParams;
    final fromRuntime = _runtimeSupport.getRuntimeVariable(trimmed);
    if (fromRuntime.isNotEmpty) return fromRuntime;
    return RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed) ? trimmed : null;
  }

  String? _evalUrlJsFallback(
    String jsCode, {
    required String baseUrl,
    required String result,
    required Map<String, String> params,
  }) {
    final parts =
        RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(jsCode, const ['+'])
            .parts;
    if (parts.isEmpty) return null;
    final out = StringBuffer();
    for (final part in parts) {
      final value = _resolveUrlJsAtom(
        part,
        baseUrl: baseUrl,
        result: result,
        params: params,
      );
      if (value == null) return null;
      out.write(value);
    }
    return out.toString();
  }

  String evalUrlJsSegment(
    String jsCode, {
    required String baseUrl,
    required String result,
    required Map<String, String> params,
    String? jsLib,
  }) {
    var output = _evalJsMaybeString(
      js: jsCode,
      jsLib: jsLib,
      bindings: _buildUrlJsBindings(
        baseUrl: baseUrl,
        result: result,
        params: params,
      ),
    ).trim();
    if (output.isEmpty) {
      output = _evalSimpleJsLibFunctionCall(
            jsCode,
            jsLib: jsLib,
            resolveAtom: (atom) => _resolveUrlJsAtom(
              atom,
              baseUrl: baseUrl,
              result: result,
              params: params,
            ),
          )?.trim() ??
          '';
    }
    if (output.isEmpty) {
      output = _evalUrlJsFallback(
            jsCode,
            baseUrl: baseUrl,
            result: result,
            params: params,
          )?.trim() ??
          '';
    }
    if (output.isEmpty) return result;
    return output.replaceAll('@result', result);
  }

  String applyUrlJsSegments(
    String rawRule, {
    required String baseUrl,
    required Map<String, String> params,
    String? jsLib,
  }) {
    if (rawRule.isEmpty ||
        (!rawRule.contains('@js:') && !rawRule.toLowerCase().contains('<js>'))) {
      return rawRule;
    }

    var index = 0;
    var segmentStart = 0;
    var hasToken = false;
    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;
    var result = '';
    var initialized = false;

    void applyLiteralSegment(int start, int end) {
      if (end <= start) return;
      final segment = rawRule.substring(start, end).trim();
      if (segment.isEmpty) return;
      if (!initialized) {
        result = segment;
      } else if (segment.contains('@result')) {
        result = segment.replaceAll('@result', result);
      } else {
        result = '$result$segment';
      }
      initialized = true;
    }

    while (index < rawRule.length) {
      final ch = rawRule[index];
      if (quote != null) {
        if (ch == '\\' && index + 1 < rawRule.length) {
          index += 2;
          continue;
        }
        if (ch == quote) quote = null;
        index++;
        continue;
      }
      if (ch == '\\' && index + 1 < rawRule.length) {
        index += 2;
        continue;
      }
      if (ch == '"' || ch == "'") quote = ch;
      if (ch == '(') parenDepth++;
      if (ch == ')') parenDepth = parenDepth > 0 ? parenDepth - 1 : 0;
      if (ch == '[') bracketDepth++;
      if (ch == ']') bracketDepth = bracketDepth > 0 ? bracketDepth - 1 : 0;
      if (ch == '{') braceDepth++;
      if (ch == '}') braceDepth = braceDepth > 0 ? braceDepth - 1 : 0;

      if (quote == null && parenDepth == 0 && bracketDepth == 0 && braceDepth == 0) {
        if (rawRule.substring(index).toLowerCase().startsWith('<js>')) {
          final closeIndex = rawRule.toLowerCase().indexOf('</js>', index + 4);
          if (closeIndex >= 0) {
            hasToken = true;
            applyLiteralSegment(segmentStart, index);
            result = evalUrlJsSegment(
              rawRule.substring(index + 4, closeIndex).trim(),
              baseUrl: baseUrl,
              result: result,
              params: params,
              jsLib: jsLib,
            );
            initialized = true;
            index = closeIndex + 5;
            segmentStart = index;
            continue;
          }
        }
        if (rawRule.substring(index).toLowerCase().startsWith('@js:')) {
          hasToken = true;
          applyLiteralSegment(segmentStart, index);
          result = evalUrlJsSegment(
            rawRule.substring(index + 4).trim(),
            baseUrl: baseUrl,
            result: result,
            params: params,
            jsLib: jsLib,
          );
          initialized = true;
          segmentStart = rawRule.length;
          break;
        }
      }
      index++;
    }

    if (!hasToken) return rawRule;
    applyLiteralSegment(segmentStart, rawRule.length);
    return initialized ? result : rawRule;
  }

  String _unescapeSingleQuotedJsString(String text) {
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\\' && i + 1 < text.length) {
        switch (text[++i]) {
          case 'n':
            out.write('\n');
          case 'r':
            out.write('\r');
          case 't':
            out.write('\t');
          case '\\':
            out.write('\\');
          case "'":
            out.write("'");
          case '"':
            out.write('"');
          default:
            out.write(text[i]);
        }
        continue;
      }
      out.write(ch);
    }
    return out.toString();
  }

  String? decodeSimpleJsStringLiteral(String token) {
    final trimmed = token.trim();
    if (trimmed.length < 2) return null;
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      try {
        final decoded = jsonDecode(trimmed);
        return decoded is String ? decoded : null;
      } catch (_) {
        return trimmed.substring(1, trimmed.length - 1);
      }
    }
    if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
      return _unescapeSingleQuotedJsString(trimmed.substring(1, trimmed.length - 1));
    }
    return null;
  }

  String decodeJsIndexKey(String raw) {
    return decodeSimpleJsStringLiteral(raw) ?? raw.trim();
  }

  String? _evalSimpleTemplateAtom(String atom) {
    final trimmed = atom.trim();
    if (trimmed.isEmpty) return '';
    final literal = decodeSimpleJsStringLiteral(trimmed);
    if (literal != null) return literal;
    if (trimmed.startsWith('vars[') && trimmed.endsWith(']')) {
      return _runtimeSupport.getRuntimeVariable(
        decodeJsIndexKey(trimmed.substring(5, trimmed.length - 1).trim()),
      );
    }
    final varsDot =
        RegExp(r'^vars\.([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(trimmed);
    if (varsDot != null) {
      return _runtimeSupport.getRuntimeVariable(varsDot.group(1) ?? '');
    }
    final directVar = _runtimeSupport.getRuntimeVariable(trimmed);
    if (directVar.isNotEmpty) return directVar;
    return trimmed == 'baseUrl' || trimmed == 'result' ? '' : null;
  }

  String? _evalSimpleTemplateExpression(String code) {
    final split =
        RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(code, const ['+']);
    if (split.parts.isEmpty) return null;
    if (split.operator == null) return _evalSimpleTemplateAtom(split.parts.first);
    final out = StringBuffer();
    for (final part in split.parts) {
      final value = _evalSimpleTemplateAtom(part);
      if (value == null) return null;
      out.write(value);
    }
    return out.toString();
  }

  String? _evalSimpleJsConcat(
    String code, {
    required String? Function(String atom) resolveAtom,
  }) {
    final split =
        RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(code, const ['+']);
    if (split.parts.isEmpty) return null;
    if (split.operator == null) return resolveAtom(split.parts.first);
    final out = StringBuffer();
    for (final part in split.parts) {
      final value = resolveAtom(part);
      if (value == null) return null;
      out.write(value);
    }
    return out.toString();
  }

  Map<String, ({List<String> args, String returnExpr})> _parseSimpleJsLibFunctions(
    String? jsLib,
  ) {
    final source = (jsLib ?? '').trim();
    if (source.isEmpty) {
      return const <String, ({List<String> args, String returnExpr})>{};
    }
    final out = <String, ({List<String> args, String returnExpr})>{};
    final matches = RegExp(
      r'function\s+([A-Za-z_\$][A-Za-z0-9_\$]*)\s*\(([^)]*)\)\s*\{([\s\S]*?)\}',
      multiLine: true,
    ).allMatches(source);
    for (final match in matches) {
      final name = match.group(1)?.trim() ?? '';
      final body = match.group(3)?.trim() ?? '';
      if (name.isEmpty || body.isEmpty) continue;
      final returnMatch =
          RegExp(r'^return\s+([\s\S]*?);?\s*$', dotAll: true).firstMatch(body);
      final returnExpr = returnMatch?.group(1)?.trim() ?? '';
      if (returnExpr.isEmpty) continue;
      final argsRaw = match.group(2)?.trim() ?? '';
      out[name] = (
        args: argsRaw.isEmpty
            ? const <String>[]
            : argsRaw
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false),
        returnExpr: returnExpr,
      );
    }
    return out;
  }

  String? _evalSimpleJsLibFunctionCall(
    String jsCode, {
    String? jsLib,
    required String? Function(String atom) resolveAtom,
  }) {
    final functions = _parseSimpleJsLibFunctions(jsLib);
    if (functions.isEmpty) return null;
    final call = RegExp(
      r'^([A-Za-z_\$][A-Za-z0-9_\$]*)\s*\((.*)\)\s*;?$',
      dotAll: true,
    ).firstMatch(jsCode.trim());
    if (call == null) return null;
    final fn = functions[call.group(1)?.trim() ?? ''];
    if (fn == null) return null;
    final argsRaw = call.group(2)?.trim() ?? '';
    final callArgs = argsRaw.isEmpty
        ? const <String>[]
        : RuleParserEngineSyntaxHelper.splitByTopLevelComma(argsRaw);
    final local = <String, String>{};
    for (var i = 0; i < fn.args.length; i++) {
      final key = fn.args[i].trim();
      if (key.isEmpty) continue;
      local[key] = _evalSimpleJsConcat(
            i < callArgs.length ? callArgs[i].trim() : '',
            resolveAtom: resolveAtom,
          ) ??
          '';
    }
    return _evalSimpleJsConcat(
      fn.returnExpr,
      resolveAtom: (atom) {
        final trimmed = atom.trim();
        return local.containsKey(trimmed) ? local[trimmed] : resolveAtom(atom);
      },
    );
  }

  String applyTemplateJsTokens(
    String input, {
    required String baseUrl,
    String? jsLib,
  }) {
    if (input.isEmpty || !input.contains('{{')) return input;
    return input.replaceAllMapped(RegExp(r'\{\{([\s\S]*?)\}\}'), (match) {
      final code = match.group(1)?.trim() ?? '';
      if (code.isEmpty) return '';

      final directVar = _runtimeSupport.getRuntimeVariable(code);
      if (directVar.isNotEmpty) return directVar;
      if (_looksLikeJsonPath(code) || _looksLikeXPath(code) || _looksLikeRegexRule(code)) {
        final value = _runtimeSupport.getRuntimeVariable(code);
        if (value.isNotEmpty) return value;
      }

      final simple = _evalSimpleTemplateExpression(code);
      if (simple != null) return simple;

      final jsOut = _evalJsMaybeString(
        js: code,
        jsLib: jsLib,
        bindings: <String, Object?>{
          'baseUrl': baseUrl,
          'result': input,
          'vars': _runtimeSupport.runtimeVariableSnapshot(desensitize: false),
        },
      ).trim();
      if (jsOut.isNotEmpty) return jsOut;

      return _evalSimpleJsLibFunctionCall(
            code,
            jsLib: jsLib,
            resolveAtom: (atom) {
              final trimmed = atom.trim();
              if (trimmed == 'baseUrl') return baseUrl;
              if (trimmed == 'result') return input;
              return _evalSimpleTemplateAtom(trimmed);
            },
          ) ??
          '';
    });
  }
}
