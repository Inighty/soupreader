import 'dart:convert';

import 'package:soupreader/features/source/services/rule_parser/request/request_types.dart';
import 'package:soupreader/features/source/services/rule_parser/core/syntax_helper.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineRequestUrlSupport {
  RuleParserEngineRequestUrlSupport(this._ctx);

  static final RegExp _httpHeaderTokenRegex =
      RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  final RuleParserContext _ctx;

  String _evalJsMaybeString({required String js, String? jsLib}) =>
      _ctx.jsSupport.evalJsMaybeString(js: js, jsLib: jsLib);
  String _runtimeEvaluate(String script) => _ctx.runtimeEvaluate(script);
  String? _decodeSimpleJsStringLiteral(String token) =>
      _ctx.jsTemplateSupport.decodeSimpleJsStringLiteral(token);

  ParsedHeaders parseRequestHeaders(
    String? header, {
    String? jsLib,
  }) {
    if (header == null) return ParsedHeaders.empty;
    final raw = header.trim();
    if (raw.isEmpty) return ParsedHeaders.empty;

    String? warning;

    String? evalHeaderJs(String js) {
      final out = _evalJsMaybeString(js: js, jsLib: jsLib).trim();
      return out.isEmpty ? null : out;
    }

    Map<String, String> mapToHeaders(Map decoded) {
      final map = <String, String>{};
      decoded.forEach((key, value) {
        final normalizedKey = key.toString().trim();
        if (normalizedKey.isEmpty || value == null) return;
        if (_httpHeaderTokenRegex.hasMatch(normalizedKey)) {
          map[normalizedKey] = value.toString();
        } else {
          warning ??= '存在非法 header key（已忽略）: $normalizedKey';
        }
      });
      return map;
    }

    String? normalizeMaybeDoubleEncoded(String text) {
      final trimmed = text.trim();
      if (trimmed.length >= 2 &&
          trimmed.startsWith('"') &&
          trimmed.endsWith('"')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is String) return decoded;
        } catch (_) {
          // ignore
        }
      }
      return null;
    }

    String? unescapeWeirdJsonObjectText(String text) {
      final trimmed = text.trim();
      if (!(trimmed.startsWith('{') && trimmed.contains(r'\"'))) return null;
      var fixed = trimmed;
      fixed = fixed.replaceAll(r'\\', '\\');
      fixed = fixed.replaceAll(r'\"', '"');
      return fixed == trimmed ? null : fixed;
    }

    var normalizedRaw = raw;
    if (raw.length >= 4 && raw.toLowerCase().startsWith('@js:')) {
      final js = raw.substring(4).trim();
      final out = js.isEmpty ? null : evalHeaderJs(js);
      if (out != null) {
        warning ??= 'header 使用 @js: 生成';
        normalizedRaw = out;
      } else {
        warning ??= 'header @js: 执行失败（将按原文本解析）';
      }
    } else if (raw.length >= 4 && raw.toLowerCase().startsWith('<js>')) {
      var js = raw.substring(4);
      final lastTag = js.lastIndexOf('<');
      if (lastTag > 0) js = js.substring(0, lastTag);
      js = js.trim();
      final out = js.isEmpty ? null : evalHeaderJs(js);
      if (out != null) {
        warning ??= 'header 使用 <js> 生成';
        normalizedRaw = out;
      } else {
        warning ??= 'header <js> 执行失败（将按原文本解析）';
      }
    }

    final doubleDecoded = normalizeMaybeDoubleEncoded(normalizedRaw);
    normalizedRaw = doubleDecoded ?? normalizedRaw;
    if (normalizedRaw.startsWith('{') && normalizedRaw.endsWith('}')) {
      try {
        final decoded = jsonDecode(normalizedRaw);
        if (decoded is Map) {
          return ParsedHeaders(
            headers: mapToHeaders(decoded),
            warning: warning,
          );
        }
      } catch (_) {
        // fallthrough
      }

      final fixed = unescapeWeirdJsonObjectText(normalizedRaw);
      if (fixed != null) {
        try {
          final decoded = jsonDecode(fixed);
          if (decoded is Map) {
            warning ??= 'header 似乎被二次转义，已自动修复解析';
            return ParsedHeaders(
              headers: mapToHeaders(decoded),
              warning: warning,
            );
          }
        } catch (_) {
          warning ??= 'header 看起来像 JSON，但解析失败（将尝试其它格式）';
        }
      } else {
        warning ??= 'header 看起来像 JSON，但解析失败（将尝试其它格式）';
      }

      final inner = normalizedRaw.substring(1, normalizedRaw.length - 1).trim();
      if (inner.isNotEmpty && !inner.contains('"')) {
        final map = <String, String>{};
        for (final part in inner.split(',')) {
          final item = part.trim();
          if (item.isEmpty) continue;
          final idx = item.indexOf(':');
          if (idx <= 0) continue;
          final key = item.substring(0, idx).trim();
          final value = item.substring(idx + 1).trim();
          if (key.isEmpty) continue;
          if (!_httpHeaderTokenRegex.hasMatch(key)) continue;
          map[key] = value;
        }
        if (map.isNotEmpty) {
          return ParsedHeaders(headers: map, warning: warning);
        }
      }
    }

    final headers = <String, String>{};
    for (final line in normalizedRaw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final idx = trimmed.indexOf(':');
      if (idx <= 0) continue;
      final key = trimmed.substring(0, idx).trim();
      final value = trimmed.substring(idx + 1).trim();
      if (key.isEmpty) continue;
      if (!_httpHeaderTokenRegex.hasMatch(key)) {
        warning ??= '存在非法 header key（已忽略）: $key';
        continue;
      }
      headers[key] = value;
    }
    return ParsedHeaders(headers: headers, warning: warning);
  }

  LegadoUrlParsed parseLegadoStyleUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return const LegadoUrlParsed(url: '', option: null);

    final idx = _findLegadoUrlOptionSplitIndex(trimmed);
    if (idx <= 0) {
      return LegadoUrlParsed(url: trimmed, option: null);
    }

    final urlPart = trimmed.substring(0, idx).trim();
    final optPart = trimmed.substring(idx + 1).trim();
    if (!optPart.startsWith('{') || !optPart.endsWith('}')) {
      return LegadoUrlParsed(url: trimmed, option: null);
    }

    try {
      final decoded = jsonDecode(optPart);
      if (decoded is! Map) {
        return LegadoUrlParsed(url: trimmed, option: null);
      }
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      return LegadoUrlParsed(
        url: urlPart.isEmpty ? trimmed : urlPart,
        option: LegadoUrlOption.fromJson(map),
      );
    } catch (_) {
      return LegadoUrlParsed(url: trimmed, option: null);
    }
  }

  int findLegadoUrlOptionSplitIndex(String source) {
    return _findLegadoUrlOptionSplitIndex(source);
  }

  UrlJsPatchResult? applyLegadoUrlOptionJs({
    required String js,
    required String url,
    required Map<String, String> headerMap,
  }) {
    final safeUrl = jsonEncode(url);
    final safeHeaders = jsonEncode(headerMap);
    final wrapped = '''
      (function(){
        var java = {};
        java.url = $safeUrl;
        java.headerMap = $safeHeaders;
        java.headerMap.put = function(k,v){ this[String(k)] = String(v); };
        java.headerMap.putAll = function(obj){
          if(!obj) return;
          for (var key in obj) { this[String(key)] = String(obj[key]); }
        };
        java.log = function(){ try { console.log.apply(console, arguments); } catch(e) {} };
        try {
          (function(){ $js })();
        } catch (e) {
          return JSON.stringify({ok:false, error: String(e && (e.stack||e.message||e)), url: java.url, headers: java.headerMap});
        }
        return JSON.stringify({ok:true, url: java.url, headers: java.headerMap});
      })()
    ''';

    try {
      final text = _runtimeEvaluate(wrapped).trim();
      if (text.isEmpty || text == 'null' || text == 'undefined') {
        return _applyLegadoUrlOptionJsFallback(
          js: js,
          url: url,
          headerMap: headerMap,
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return _applyLegadoUrlOptionJsFallback(
          js: js,
          url: url,
          headerMap: headerMap,
        );
      }
      final ok = decoded['ok'] == true;
      final patchedUrl = decoded['url']?.toString() ?? url;
      final headersRaw = decoded['headers'];
      final patchedHeaders = <String, String>{};
      if (headersRaw is Map) {
        headersRaw.forEach((key, value) {
          if (key == null || value == null) return;
          patchedHeaders[key.toString()] = value.toString();
        });
      }
      return UrlJsPatchResult(
        ok: ok,
        url: patchedUrl,
        headers: patchedHeaders.isEmpty ? headerMap : patchedHeaders,
        error: decoded['error']?.toString(),
      );
    } catch (error) {
      final fallback = _applyLegadoUrlOptionJsFallback(
        js: js,
        url: url,
        headerMap: headerMap,
      );
      if (fallback != null) return fallback;
      return UrlJsPatchResult(
        ok: false,
        url: url,
        headers: headerMap,
        error: error.toString(),
      );
    }
  }

  int _findLegadoUrlOptionSplitIndex(String source) {
    if (source.trim().isEmpty) return -1;

    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    for (var i = 0; i < source.length; i++) {
      final ch = source[i];

      if (quote != null) {
        if (ch == '\\' && i + 1 < source.length) {
          i++;
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '\\' && i + 1 < source.length) {
        i++;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        continue;
      }

      if (ch == '(') {
        parenDepth++;
        continue;
      }
      if (ch == ')') {
        if (parenDepth > 0) parenDepth--;
        continue;
      }
      if (ch == '[') {
        bracketDepth++;
        continue;
      }
      if (ch == ']') {
        if (bracketDepth > 0) bracketDepth--;
        continue;
      }
      if (ch == '{') {
        braceDepth++;
        continue;
      }
      if (ch == '}') {
        if (braceDepth > 0) braceDepth--;
        continue;
      }

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (!atTopLevel || ch != ',') continue;

      var j = i + 1;
      while (j < source.length && source[j].trim().isEmpty) {
        j++;
      }
      if (j >= source.length || source[j] != '{') continue;

      final closeBrace =
          RuleParserEngineSyntaxHelper.findBalancedBraceEnd(source, j);
      if (closeBrace <= j) continue;

      final tail = source.substring(closeBrace + 1).trim();
      if (tail.isEmpty) {
        return i;
      }
    }

    return -1;
  }

  UrlJsPatchResult? _applyLegadoUrlOptionJsFallback({
    required String js,
    required String url,
    required Map<String, String> headerMap,
  }) {
    final split =
        RuleParserEngineSyntaxHelper.splitRuleByTopLevelOperator(
      js,
      const [';'],
    );
    final statements = split.parts.isEmpty ? <String>[js] : split.parts;

    var patchedUrl = url;
    final patchedHeaders = <String, String>{}..addAll(headerMap);
    var changed = false;

    for (final raw in statements) {
      final statement = raw.trim();
      if (statement.isEmpty) continue;

      final lower = statement.toLowerCase();

      final appendMatch = RegExp(
        r'^java\.url\s*=\s*java\.url\s*\+\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(statement);
      if (appendMatch != null) {
        final rhs = appendMatch.group(1)?.trim() ?? '';
        final suffix = _decodeSimpleJsStringLiteral(rhs) ?? '';
        if (suffix.isNotEmpty) {
          patchedUrl = '$patchedUrl$suffix';
          changed = true;
        }
        continue;
      }

      final setMatch = RegExp(
        r'^java\.url\s*=\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(statement);
      if (setMatch != null) {
        final rhs = setMatch.group(1)?.trim() ?? '';
        if (rhs.toLowerCase() != 'java.url') {
          final absolute = _decodeSimpleJsStringLiteral(rhs);
          if (absolute != null) {
            patchedUrl = absolute;
            changed = true;
          }
        }
        continue;
      }

      if (lower.startsWith('java.headermap.putall')) {
        final match = RegExp(
          r'^java\.headerMap\.putAll\s*\((.*)\)$',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(statement);
        final args = match?.group(1)?.trim() ?? '';
        if (args.isEmpty) continue;
        final map = <String, String>{};
        RuleParserEngineSyntaxHelper.mergePutMapFromText(args, map);
        if (map.isNotEmpty) {
          patchedHeaders.addAll(map);
          changed = true;
        }
        continue;
      }

      if (!lower.startsWith('java.headermap.put')) continue;
      final match = RegExp(
        r'^java\.headerMap\.put\s*\((.*)\)$',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(statement);
      final args = match?.group(1)?.trim() ?? '';
      if (args.isEmpty) continue;
      final pairs = RuleParserEngineSyntaxHelper.splitByTopLevelComma(args);
      if (pairs.length < 2) continue;

      final key = _decodeSimpleJsStringLiteral(pairs[0].trim()) ??
          RuleParserEngineSyntaxHelper.stripPairedQuotes(pairs[0].trim());
      final value = _decodeSimpleJsStringLiteral(pairs[1].trim()) ??
          RuleParserEngineSyntaxHelper.stripPairedQuotes(pairs[1].trim());
      if (key.isEmpty) continue;
      patchedHeaders[key] = value;
      changed = true;
    }

    if (!changed) return null;
    return UrlJsPatchResult(
      ok: true,
      url: patchedUrl,
      headers: patchedHeaders,
      error: 'urlOption.js 使用回退解析',
    );
  }
}
