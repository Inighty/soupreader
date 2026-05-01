import 'dart:convert';

import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/core/runtime_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/syntax_helper.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineJsSupport {
  RuleParserEngineJsSupport(this._ctx);

  final RuleParserContext _ctx;

  RuleParserEngineRuntimeSupport get _runtimeSupport => _ctx.runtimeSupport;
  String _runtimeEvaluate(String script) => _ctx.runtimeEvaluate(script);
  dynamic _tryDecodeJsonValue(String text) => _ctx.tryDecodeJsonValue(text);

  bool _isValidJsIdentifier(String key) {
    return RegExp(r'^[A-Za-z_\$][A-Za-z0-9_\$]*$').hasMatch(key);
  }

  String _buildJsBindingDeclarations(Map<String, Object?> bindings) {
    final out = StringBuffer();
    final seen = <String>{};
    for (final entry in bindings.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || seen.contains(key) || !_isValidJsIdentifier(key)) {
        continue;
      }
      seen.add(key);
      out.writeln('var $key = __b[${jsonEncode(key)}];');
    }
    return out.toString();
  }

  String evalJsMaybeString({
    required String js,
    String? jsLib,
    Map<String, Object?> bindings = const {},
  }) {
    final safeLib = (jsLib ?? '').trim();
    final wrapped = '''
      (function(){
        try {
          ${safeLib.isEmpty ? '' : '$safeLib\n'}
          var __b = ${jsonEncode(bindings)} || {};
          for (var k in __b) {
            try {
              if (typeof globalThis !== 'undefined' && globalThis) {
                globalThis[String(k)] = __b[k];
              } else {
                this[String(k)] = __b[k];
              }
            } catch(e) {
              try { this[String(k)] = __b[k]; } catch(e2) {}
            }
          }
          ${_buildJsBindingDeclarations(bindings)}
          var __res;
          try {
            __res = eval(${jsonEncode(js)});
          } catch(_e) {
            __res = '';
          }
          if (__res === undefined || __res === null) {
            try {
              if (typeof chapter !== 'undefined' && chapter && typeof chapter.title === 'string' && chapter.title) {
                return chapter.title;
              }
            } catch(e) {}
            return '';
          }
          if (typeof __res === 'string') return __res;
          try { return JSON.stringify(__res); } catch(e) { return String(__res); }
        } catch (e) {
          return '';
        }
      })()
    ''';
    try {
      final out = _runtimeEvaluate(wrapped);
      return out == 'undefined' || out == 'null' ? '' : out;
    } catch (_) {
      return '';
    }
  }

  String evalTocFormatJs({
    required String js,
    required String title,
    required int index1Based,
    String? jsLib,
  }) {
    final out = evalJsMaybeString(
      js: js,
      jsLib: jsLib,
      bindings: <String, Object?>{
        'index': index1Based,
        'title': title,
        'chapter': <String, Object?>{'title': title},
      },
    ).trim();
    return out.isEmpty ? title : out;
  }

  List<TocItem> applyTocFormatJs({
    required List<TocItem> toc,
    required String? formatJs,
    String? jsLib,
  }) {
    final js = (formatJs ?? '').trim();
    if (js.isEmpty || toc.isEmpty) return toc;
    return [
      for (var i = 0; i < toc.length; i++)
        TocItem(
          index: toc[i].index,
          name: evalTocFormatJs(
            js: js,
            title: toc[i].name,
            index1Based: i + 1,
            jsLib: jsLib,
          ),
          url: toc[i].url,
          isVolume: toc[i].isVolume,
          isVip: toc[i].isVip,
          isPay: toc[i].isPay,
          tag: toc[i].tag,
        ),
    ];
  }

  String applyStageResponseJs({
    required String responseText,
    required String? jsRule,
    required String currentUrl,
    String? jsLib,
    String stageLabel = 'webJs',
    void Function(String message)? onLog,
  }) {
    final js = (jsRule ?? '').trim();
    if (js.isEmpty) return responseText;

    var transformed = evalJsMaybeString(
      js: js,
      jsLib: jsLib,
      bindings: <String, Object?>{
        'result': responseText,
        'content': responseText,
        'baseUrl': currentUrl,
        'url': currentUrl,
        'vars': _runtimeSupport.runtimeVariableSnapshot(desensitize: false),
      },
    );

    if (transformed.isEmpty) {
      transformed = _evalStageJsFallback(
        js: js,
        responseText: responseText,
        currentUrl: currentUrl,
      );
      if (transformed.isNotEmpty) {
        onLog?.call('$stageLabel 使用回退解析应用脚本');
      }
    }

    if (transformed.isEmpty) {
      onLog?.call('$stageLabel 执行返回空，保留原始响应');
      return responseText;
    }
    if (transformed != responseText) {
      onLog?.call('$stageLabel 已应用（长度 ${responseText.length} -> ${transformed.length}）');
    }
    return transformed;
  }

  void runPreUpdateJs({
    required String? jsRule,
    required String currentUrl,
    String? jsLib,
    void Function(String message)? onLog,
  }) {
    final js = (jsRule ?? '').trim();
    if (js.isEmpty) return;
    try {
      final vars = _runtimeSupport.runtimeVariableSnapshot(desensitize: false);
      evalJsMaybeString(
        js: js,
        jsLib: jsLib,
        bindings: <String, Object?>{
          'baseUrl': currentUrl,
          'url': currentUrl,
          'vars': vars,
        },
      );
      for (final entry in vars.entries) {
        _runtimeSupport.putRuntimeVariable(entry.key, entry.value);
      }
      onLog?.call('preUpdateJs 已执行（目录前置）');
    } catch (e) {
      onLog?.call('preUpdateJs 执行失败：$e');
    }
  }

  String _evalStageJsFallback({
    required String js,
    required String responseText,
    required String currentUrl,
  }) {
    final statements =
        RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(js, const [';'])
            .parts;
    final env = <String, String>{
      'result': responseText,
      'content': responseText,
      'baseUrl': currentUrl,
      'url': currentUrl,
    };
    var lastValue = '';

    for (final raw in statements.isEmpty ? <String>[js] : statements) {
      final statement = raw.trim();
      if (statement.isEmpty) continue;
      final assign = RegExp(r'^([A-Za-z_\$][A-Za-z0-9_\$]*)\s*=\s*([\s\S]+)$')
          .firstMatch(statement);
      if (assign != null) {
        final value = _evalStageJsExpressionFallback(
          assign.group(2)?.trim() ?? '',
          env,
        );
        if (value != null) {
          env[assign.group(1)?.trim() ?? ''] = value;
          lastValue = value;
        }
        continue;
      }
      final value = _evalStageJsExpressionFallback(statement, env);
      if (value != null) lastValue = value;
    }

    if (lastValue.trim().isNotEmpty) return lastValue;
    final resultValue = env['result'] ?? '';
    if (resultValue.trim().isNotEmpty && resultValue != responseText) {
      return resultValue;
    }
    final contentValue = env['content'] ?? '';
    if (contentValue.trim().isNotEmpty && contentValue != responseText) {
      return contentValue;
    }
    return '';
  }

  String? _evalStageJsExpressionFallback(
    String expression,
    Map<String, String> env,
  ) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) return '';

    final stringify = RegExp(
      r'^JSON\.stringify\s*\(([\s\S]*)\)\s*;?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (stringify != null) {
      final inner = stringify.group(1)?.trim() ?? '';
      if (inner.isEmpty) return '';
      final fromEnv = env[inner];
      if (fromEnv != null) {
        final decoded = _tryDecodeJsonValue(fromEnv);
        return jsonEncode(decoded ?? fromEnv);
      }
      final strLiteral = decodeSimpleJsStringLiteral(inner);
      if (strLiteral != null) return jsonEncode(strLiteral);
      return _normalizeLooseJsonLiteral(inner);
    }

    final concat = _evalSimpleJsConcat(
      trimmed,
      resolveAtom: (atom) => _resolveStageJsAtomFallback(atom, env),
    );
    return concat ?? _resolveStageJsAtomFallback(trimmed, env);
  }

  String? _resolveStageJsAtomFallback(String atom, Map<String, String> env) {
    final trimmed = atom.trim();
    if (trimmed.isEmpty) return '';
    final strLiteral = decodeSimpleJsStringLiteral(trimmed);
    if (strLiteral != null) return strLiteral;
    if (env.containsKey(trimmed)) return env[trimmed];
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
    return RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed) ? trimmed : null;
  }

  String? _normalizeLooseJsonLiteral(String source) {
    var text = source.trim();
    if (text.isEmpty || !(text.startsWith('{') || text.startsWith('['))) {
      return null;
    }
    text = text.replaceAllMapped(
      RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"),
      (match) => jsonEncode(_unescapeSingleQuotedJsString(match.group(1) ?? '')),
    );
    text = text.replaceAllMapped(
      RegExp(r'([\{\[, ]\s*)([A-Za-z_\$][A-Za-z0-9_\$]*)\s*:'),
      (match) => '${match.group(1)}"${match.group(2)}":',
    );
    text = text.replaceAll(RegExp(r'\bundefined\b'), 'null');
    final decoded = _tryDecodeJsonValue(text);
    if (decoded == null) return null;
    try {
      return jsonEncode(decoded);
    } catch (_) {
      return null;
    }
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
}
