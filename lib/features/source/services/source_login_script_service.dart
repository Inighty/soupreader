import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:intl/intl.dart';

import '../../../core/services/cookie_store.dart';
import '../../../core/services/source_login_store.dart';
import '../models/book_source.dart';
import 'rule_parser_engine.dart';

typedef SourceLoginScriptRequestExecutor = Future<ScriptHttpResponse> Function({
  required BookSource source,
  required String requestUrl,
  Map<String, String>? headerOverride,
});

class SourceLoginScriptResult {
  final bool success;
  final bool executed;
  final String message;

  const SourceLoginScriptResult({
    required this.success,
    required this.executed,
    required this.message,
  });
}

class SourceLoginScriptService {
  const SourceLoginScriptService({
    SourceLoginScriptRequestExecutor? requestExecutor,
  }) : _requestExecutor = requestExecutor;

  final SourceLoginScriptRequestExecutor? _requestExecutor;

  static const String _errorPrefix = '__SR_LOGIN_ERROR__';

  static String resolveLoginScript(String? loginUrl) {
    final raw = (loginUrl ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('@js:')) {
      return raw.substring(4).trim();
    }
    if (raw.toLowerCase().startsWith('<js>')) {
      final lower = raw.toLowerCase();
      final end = lower.lastIndexOf('</js>');
      if (end > 4) {
        return raw.substring(4, end).trim();
      }
      return raw.substring(4).trim();
    }
    return raw;
  }

  @visibleForTesting
  String debugPrepareScriptForTest(String script) {
    return _prepareScriptForAsyncNet(script);
  }

  @visibleForTesting
  Future<ScriptHttpResponse> debugRequestForTest({
    required BookSource source,
    required String requestUrl,
    String? headerRaw,
  }) {
    return _requestScriptHttp(
      source: source,
      args: <String, dynamic>{
        'url': requestUrl,
        if (headerRaw != null) 'header': headerRaw,
      },
    );
  }

  Future<SourceLoginScriptResult> runLoginScript({
    required BookSource source,
    required Map<String, String> loginData,
  }) async {
    final loginJs = resolveLoginScript(source.loginUrl);
    if (loginJs.isEmpty) {
      return const SourceLoginScriptResult(
        success: true,
        executed: false,
        message: '未配置登录脚本，已保存登录信息',
      );
    }

    final wrapped = '''
      $loginJs
      if (typeof login === 'function') {
        await login.apply(this);
      } else {
        throw('Function login not implements!!!');
      }
    ''';
    return _runScript(
      source: source,
      loginData: loginData,
      script: wrapped,
    );
  }

  Future<SourceLoginScriptResult> runButtonScript({
    required BookSource source,
    required Map<String, String> loginData,
    required String actionScript,
  }) async {
    final action = actionScript.trim();
    if (action.isEmpty) {
      return const SourceLoginScriptResult(
        success: true,
        executed: false,
        message: '',
      );
    }

    final loginJs = resolveLoginScript(source.loginUrl);
    if (loginJs.isEmpty) {
      return const SourceLoginScriptResult(
        success: true,
        executed: false,
        message: '当前未配置登录脚本',
      );
    }

    final wrapped = '''
      $loginJs
      var result = __srToJavaMap(__srParseJsonMap(source.getLoginInfo()));
      $action
    ''';
    return _runScript(
      source: source,
      loginData: loginData,
      script: wrapped,
    );
  }

  Future<SourceLoginScriptResult> _runScript({
    required BookSource source,
    required Map<String, String> loginData,
    required String script,
  }) async {
    final sourceKey = source.bookSourceUrl.trim();
    if (sourceKey.isEmpty) {
      return const SourceLoginScriptResult(
        success: false,
        executed: false,
        message: '书源地址为空，无法执行登录脚本',
      );
    }

    final runtime = getJavascriptRuntime(xhr: false);
    final logs = <String>[];
    final initialLoginInfo = jsonEncode(loginData);
    final currentHeaderMap = Map<String, String>.from(
      await SourceLoginStore.getLoginHeaderMap(sourceKey) ?? const {},
    );
    var headerChanged = false;

    runtime.onMessage('SourceGetLoginInfo', (_) => initialLoginInfo);
    runtime.onMessage(
      'SourceGetLoginHeader',
      (_) => jsonEncode(currentHeaderMap),
    );
    runtime.onMessage('SourceRemoveLoginHeader', (_) {
      currentHeaderMap.clear();
      headerChanged = true;
      return true;
    });
    runtime.onMessage('SourcePutLoginHeader', (dynamic args) {
      final raw = _readStringArg(args, 'value');
      final parsed = _parseHeaderPayload(raw);
      if (parsed == null) return false;
      currentHeaderMap
        ..clear()
        ..addAll(parsed);
      headerChanged = true;
      return true;
    });
    runtime.onMessage('SourceLog', (dynamic args) {
      final msg = _readStringArg(args, 'message');
      if (msg.isNotEmpty) logs.add(msg);
      return true;
    });
    runtime.onMessage('JavaTimeFormatUTC', (dynamic args) {
      final timestampRaw = _readNumArg(args, 'timestamp');
      final pattern = _readStringArg(args, 'pattern');
      final offsetHours = _readNumArg(args, 'offset').round();
      final timestamp = timestampRaw.round();
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
          .add(Duration(hours: offsetHours));
      final fmt = pattern.isEmpty ? "yyyy-MM-dd'T'HH:mm:ss'Z'" : pattern;
      try {
        return DateFormat(fmt).format(dt);
      } catch (_) {
        return dt.toIso8601String();
      }
    });
    runtime.onMessage('JavaRandomUUID', (_) => _randomUuidV4());
    runtime.onMessage('JavaAjax', (dynamic args) async {
      final response = await _requestScriptHttp(
        source: source,
        args: args,
      );
      return response.body;
    });
    runtime.onMessage('JavaConnect', (dynamic args) async {
      final response = await _requestScriptHttp(
        source: source,
        args: args,
      );
      return jsonEncode(<String, dynamic>{
        'body': response.body,
        'code': response.statusCode,
        'message': response.statusMessage,
        'url': response.finalUrl,
        'headers': response.headers,
      });
    });

    final helperJs = '''
      function __srParseJsonMap(raw) {
        if (raw === null || raw === undefined) return {};
        if (typeof raw === 'string') {
          var t = String(raw).trim();
          if (!t) return {};
          try {
            var parsed = JSON.parse(t);
            return (parsed && typeof parsed === 'object') ? parsed : {};
          } catch (e) {
            return {};
          }
        }
        if (typeof raw === 'object') return raw;
        return {};
      }

      function __srToJavaMap(obj) {
        var m = (obj && typeof obj === 'object') ? obj : {};
        m.get = function(k) { return this[k]; };
        m.put = function(k, v) { this[k] = v; return v; };
        m.remove = function(k) {
          var v = this[k];
          try { delete this[k]; } catch (e) {}
          return v;
        };
        m.containsKey = function(k) {
          return Object.prototype.hasOwnProperty.call(this, k);
        };
        return m;
      }

      function __srHeaderArg(header) {
        if (header === null || header === undefined) return '';
        if (typeof header === 'string') return header;
        try {
          return JSON.stringify(header);
        } catch (e) {
          return String(header);
        }
      }

      function __srBuildHeadersProxy(rawHeaders) {
        var headers = __srParseJsonMap(rawHeaders);
        return {
          get: function(name) {
            var target = String(name || '').toLowerCase();
            var value = '';
            Object.keys(headers).forEach(function(k) {
              if (!value && String(k).toLowerCase() === target) {
                value = String(headers[k] || '');
              }
            });
            return value;
          },
          toString: function() {
            try {
              return JSON.stringify(headers);
            } catch (e) {
              return '';
            }
          }
        };
      }

      var source = {
        getLoginInfo: function() {
          return sendMessage('SourceGetLoginInfo', '{}') || '';
        },
        getLoginInfoMap: function() {
          return __srToJavaMap(__srParseJsonMap(source.getLoginInfo()));
        },
        getLoginHeader: function() {
          return sendMessage('SourceGetLoginHeader', '{}') || '';
        },
        getLoginHeaderMap: function() {
          return __srToJavaMap(__srParseJsonMap(source.getLoginHeader()));
        },
        putLoginHeader: function(value) {
          return sendMessage('SourcePutLoginHeader', JSON.stringify({value: value}));
        },
        removeLoginHeader: function() {
          return sendMessage('SourceRemoveLoginHeader', '{}');
        },
        log: function(message) {
          return sendMessage('SourceLog', JSON.stringify({message: String(message || '')}));
        }
      };

      var java = {
        ajax: async function(url, header) {
          var raw = await sendMessage('JavaAjax', JSON.stringify({
            url: String(url || ''),
            header: __srHeaderArg(header)
          }));
          return raw === null || raw === undefined ? '' : String(raw);
        },
        connect: async function(url, header) {
          var raw = await sendMessage('JavaConnect', JSON.stringify({
            url: String(url || ''),
            header: __srHeaderArg(header)
          }));
          var parsed = {};
          try {
            parsed = JSON.parse(String(raw || '{}'));
          } catch (e) {
            parsed = {};
          }
          var bodyText = String(parsed.body || '');
          var statusCode = Number(parsed.code || 0);
          var statusMessage = String(parsed.message || '');
          var finalUrl = String(parsed.url || String(url || ''));
          var headerProxy = __srBuildHeadersProxy(parsed.headers || {});
          return {
            body: function() { return bodyText; },
            code: function() { return statusCode; },
            message: function() { return statusMessage; },
            url: function() { return finalUrl; },
            headers: function() { return headerProxy; },
            isSuccessful: function() { return statusCode >= 200 && statusCode < 300; },
            toString: function() { return bodyText; }
          };
        },
        randomUUID: function() {
          return sendMessage('JavaRandomUUID', '{}');
        },
        timeFormatUTC: function(timestamp, pattern, offset) {
          return sendMessage('JavaTimeFormatUTC', JSON.stringify({
            timestamp: timestamp,
            pattern: pattern,
            offset: offset
          }));
        }
      };
    ''';
    final preparedScript = _prepareScriptForAsyncNet(script);

    try {
      final result = runtime.evaluate('''
        (async function(){
          try {
            $helperJs
            $preparedScript
            return '';
          } catch (e) {
            return '$_errorPrefix' + String(e && (e.stack || e.message || e));
          }
        })()
      ''');
      final timeout = Duration(
        milliseconds: source.respondTime > 0 ? source.respondTime * 2 : 120000,
      );
      final settled = await runtime.handlePromise(result, timeout: timeout);
      final output = _normalizePromiseOutput(settled.stringResult).trim();
      if (result.isError || output.startsWith(_errorPrefix)) {
        final msg = output.startsWith(_errorPrefix)
            ? output.substring(_errorPrefix.length).trim()
            : output;
        final detail = msg.isEmpty ? '登录脚本执行失败' : '登录脚本执行失败：$msg';
        return SourceLoginScriptResult(
          success: false,
          executed: true,
          message: detail,
        );
      }
    } catch (e) {
      return SourceLoginScriptResult(
        success: false,
        executed: true,
        message: '登录脚本执行失败：$e',
      );
    } finally {
      try {
        runtime.dispose();
      } catch (_) {
        // ignore dispose errors
      }
      if (headerChanged) {
        if (currentHeaderMap.isEmpty) {
          await SourceLoginStore.removeLoginHeader(sourceKey);
        } else {
          await SourceLoginStore.putLoginHeaderMap(sourceKey, currentHeaderMap);
          await _persistCookieHeader(
            sourceUrl: source.bookSourceUrl,
            headers: currentHeaderMap,
          );
        }
      }
    }

    if (logs.isNotEmpty) {
      return SourceLoginScriptResult(
        success: true,
        executed: true,
        message: logs.last,
      );
    }
    return const SourceLoginScriptResult(
      success: true,
      executed: true,
      message: '登录脚本执行完成',
    );
  }

  Future<ScriptHttpResponse> _requestScriptHttp({
    required BookSource source,
    required dynamic args,
  }) async {
    final url = _readStringArg(args, 'url').trim();
    final headerRaw = _readStringArg(args, 'header');
    final headerOverride = _parseHeaderOverridePayload(headerRaw);
    if (url.isEmpty) {
      return const ScriptHttpResponse(
        requestUrl: '',
        finalUrl: '',
        statusCode: 200,
        statusMessage: 'OK',
        headers: <String, String>{},
        body: '',
      );
    }
    try {
      final executor = _requestExecutor;
      if (executor != null) {
        return await executor(
          source: source,
          requestUrl: url,
          headerOverride: headerOverride,
        );
      }
      return RuleParserEngine().fetchForLoginScript(
        source: source,
        requestUrl: url,
        headerOverride: headerOverride,
      );
    } catch (e) {
      return ScriptHttpResponse(
        requestUrl: url,
        finalUrl: url,
        statusCode: 200,
        statusMessage: 'OK',
        headers: const <String, String>{},
        body: e.toString(),
      );
    }
  }

  String _prepareScriptForAsyncNet(String script) {
    final connect = _awaitifyJavaCall(script, callToken: 'java.connect(');
    final ajax = _awaitifyJavaCall(connect.script, callToken: 'java.ajax(');
    if (!connect.changed && !ajax.changed) {
      return script;
    }
    return _markFunctionDeclarationsAsync(ajax.script);
  }

  _RewriteResult _awaitifyJavaCall(
    String script, {
    required String callToken,
  }) {
    final out = StringBuffer();
    var changed = false;
    var i = 0;
    var inSingle = false;
    var inDouble = false;
    var inTemplate = false;
    var inLineComment = false;
    var inBlockComment = false;

    while (i < script.length) {
      final char = script[i];
      final next = i + 1 < script.length ? script[i + 1] : '';

      if (inLineComment) {
        out.write(char);
        if (char == '\n') {
          inLineComment = false;
        }
        i += 1;
        continue;
      }
      if (inBlockComment) {
        out.write(char);
        if (char == '*' && next == '/') {
          out.write(next);
          i += 2;
          inBlockComment = false;
          continue;
        }
        i += 1;
        continue;
      }
      if (inSingle) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == "'") {
          inSingle = false;
        }
        i += 1;
        continue;
      }
      if (inDouble) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '"') {
          inDouble = false;
        }
        i += 1;
        continue;
      }
      if (inTemplate) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '`') {
          inTemplate = false;
        }
        i += 1;
        continue;
      }

      if (char == '/' && next == '/') {
        out.write(char);
        out.write(next);
        i += 2;
        inLineComment = true;
        continue;
      }
      if (char == '/' && next == '*') {
        out.write(char);
        out.write(next);
        i += 2;
        inBlockComment = true;
        continue;
      }
      if (char == "'") {
        out.write(char);
        inSingle = true;
        i += 1;
        continue;
      }
      if (char == '"') {
        out.write(char);
        inDouble = true;
        i += 1;
        continue;
      }
      if (char == '`') {
        out.write(char);
        inTemplate = true;
        i += 1;
        continue;
      }

      if (_startsWithToken(script, i, callToken) &&
          !_hasAwaitBefore(script, i)) {
        final openParen = i + callToken.length - 1;
        final closeParen = _findMatchingParen(script, openParen);
        if (closeParen > openParen) {
          out.write('(await ');
          out.write(script.substring(i, closeParen + 1));
          out.write(')');
          changed = true;
          i = closeParen + 1;
          continue;
        }
      }

      out.write(char);
      i += 1;
    }

    return _RewriteResult(script: out.toString(), changed: changed);
  }

  String _markFunctionDeclarationsAsync(String script) {
    final out = StringBuffer();
    var i = 0;
    var inSingle = false;
    var inDouble = false;
    var inTemplate = false;
    var inLineComment = false;
    var inBlockComment = false;

    while (i < script.length) {
      final char = script[i];
      final next = i + 1 < script.length ? script[i + 1] : '';

      if (inLineComment) {
        out.write(char);
        if (char == '\n') inLineComment = false;
        i += 1;
        continue;
      }
      if (inBlockComment) {
        out.write(char);
        if (char == '*' && next == '/') {
          out.write(next);
          i += 2;
          inBlockComment = false;
          continue;
        }
        i += 1;
        continue;
      }
      if (inSingle) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == "'") inSingle = false;
        i += 1;
        continue;
      }
      if (inDouble) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '"') inDouble = false;
        i += 1;
        continue;
      }
      if (inTemplate) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '`') inTemplate = false;
        i += 1;
        continue;
      }

      if (char == '/' && next == '/') {
        out.write(char);
        out.write(next);
        i += 2;
        inLineComment = true;
        continue;
      }
      if (char == '/' && next == '*') {
        out.write(char);
        out.write(next);
        i += 2;
        inBlockComment = true;
        continue;
      }
      if (char == "'") {
        out.write(char);
        inSingle = true;
        i += 1;
        continue;
      }
      if (char == '"') {
        out.write(char);
        inDouble = true;
        i += 1;
        continue;
      }
      if (char == '`') {
        out.write(char);
        inTemplate = true;
        i += 1;
        continue;
      }

      if (_startsWithToken(script, i, 'function') &&
          !_hasAsyncBefore(script, i) &&
          _isFunctionTail(script, i + 'function'.length)) {
        out.write('async ');
      }
      out.write(char);
      i += 1;
    }
    return out.toString();
  }

  int _findMatchingParen(String text, int openIndex) {
    if (openIndex < 0 || openIndex >= text.length || text[openIndex] != '(') {
      return -1;
    }
    var depth = 0;
    var inSingle = false;
    var inDouble = false;
    var inTemplate = false;
    var inLineComment = false;
    var inBlockComment = false;

    for (var i = openIndex; i < text.length; i += 1) {
      final char = text[i];
      final next = i + 1 < text.length ? text[i + 1] : '';

      if (inLineComment) {
        if (char == '\n') inLineComment = false;
        continue;
      }
      if (inBlockComment) {
        if (char == '*' && next == '/') {
          inBlockComment = false;
          i += 1;
        }
        continue;
      }
      if (inSingle) {
        if (char == '\\' && next.isNotEmpty) {
          i += 1;
          continue;
        }
        if (char == "'") inSingle = false;
        continue;
      }
      if (inDouble) {
        if (char == '\\' && next.isNotEmpty) {
          i += 1;
          continue;
        }
        if (char == '"') inDouble = false;
        continue;
      }
      if (inTemplate) {
        if (char == '\\' && next.isNotEmpty) {
          i += 1;
          continue;
        }
        if (char == '`') inTemplate = false;
        continue;
      }

      if (char == '/' && next == '/') {
        inLineComment = true;
        i += 1;
        continue;
      }
      if (char == '/' && next == '*') {
        inBlockComment = true;
        i += 1;
        continue;
      }
      if (char == "'") {
        inSingle = true;
        continue;
      }
      if (char == '"') {
        inDouble = true;
        continue;
      }
      if (char == '`') {
        inTemplate = true;
        continue;
      }

      if (char == '(') {
        depth += 1;
        continue;
      }
      if (char == ')') {
        depth -= 1;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  bool _startsWithToken(String text, int index, String token) {
    if (index < 0 || index + token.length > text.length) {
      return false;
    }
    if (text.substring(index, index + token.length) != token) {
      return false;
    }
    if (index > 0 && _isIdentifierChar(text.codeUnitAt(index - 1))) {
      return false;
    }
    return true;
  }

  bool _isFunctionTail(String text, int index) {
    if (index >= text.length) return true;
    final char = text[index];
    return char == '(' ||
        char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == '\r';
  }

  bool _hasAsyncBefore(String text, int functionIndex) {
    var i = functionIndex - 1;
    while (i >= 0) {
      final char = text[i];
      if (char == ' ' || char == '\n' || char == '\t' || char == '\r') {
        i -= 1;
        continue;
      }
      break;
    }
    if (i < 4) return false;
    final start = i - 4;
    if (text.substring(start, i + 1) != 'async') {
      return false;
    }
    if (start > 0 && _isIdentifierChar(text.codeUnitAt(start - 1))) {
      return false;
    }
    return true;
  }

  bool _hasAwaitBefore(String text, int callIndex) {
    var i = callIndex - 1;
    while (i >= 0) {
      final char = text[i];
      if (char == ' ' || char == '\n' || char == '\t' || char == '\r') {
        i -= 1;
        continue;
      }
      break;
    }
    if (i < 4) return false;
    final start = i - 4;
    if (text.substring(start, i + 1) != 'await') {
      return false;
    }
    if (start > 0 && _isIdentifierChar(text.codeUnitAt(start - 1))) {
      return false;
    }
    return true;
  }

  bool _isIdentifierChar(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 95 ||
        codeUnit == 36;
  }

  String _normalizePromiseOutput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    try {
      final decoded = jsonDecode(text);
      if (decoded == null) return '';
      if (decoded is String) return decoded;
    } catch (_) {
      // keep raw result
    }
    return text;
  }

  String _readStringArg(dynamic args, String key) {
    if (args is Map) {
      final value = args[key];
      if (value == null) return '';
      return value.toString();
    }
    return '';
  }

  num _readNumArg(dynamic args, String key) {
    if (args is Map) {
      final value = args[key];
      if (value is num) return value;
      return num.tryParse(value?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  Map<String, String>? _parseHeaderPayload(String payload) {
    final raw = payload.trim();
    if (raw.isEmpty) return <String, String>{};
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final out = <String, String>{};
    decoded.forEach((k, v) {
      if (k == null || v == null) return;
      final key = k.toString().trim();
      if (key.isEmpty) return;
      out[key] = v.toString();
    });
    return out;
  }

  Map<String, String>? _parseHeaderOverridePayload(String payload) {
    final raw = payload.trim();
    if (raw.isEmpty) return null;
    return _parseHeaderPayload(raw);
  }

  Future<void> _persistCookieHeader({
    required String sourceUrl,
    required Map<String, String> headers,
  }) async {
    String? cookieHeader;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'cookie') {
        cookieHeader = entry.value.trim();
        break;
      }
    }
    if (cookieHeader == null || cookieHeader.isEmpty) return;
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.host.trim().isEmpty) return;

    final cookies = <Cookie>[];
    for (final segment in cookieHeader.split(';')) {
      final pair = segment.trim();
      if (pair.isEmpty) continue;
      final sep = pair.indexOf('=');
      if (sep <= 0) continue;
      final name = pair.substring(0, sep).trim();
      final value = pair.substring(sep + 1).trim();
      if (name.isEmpty) continue;
      final cookie = Cookie(name, value);
      cookie.domain = uri.host;
      cookies.add(cookie);
    }
    if (cookies.isEmpty) return;
    await CookieStore.saveFromResponse(uri, cookies);
  }

  String _randomUuidV4() {
    final r = Random();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(bytes[0])}${h(bytes[1])}${h(bytes[2])}${h(bytes[3])}-'
        '${h(bytes[4])}${h(bytes[5])}-'
        '${h(bytes[6])}${h(bytes[7])}-'
        '${h(bytes[8])}${h(bytes[9])}-'
        '${h(bytes[10])}${h(bytes[11])}${h(bytes[12])}${h(bytes[13])}${h(bytes[14])}${h(bytes[15])}';
  }
}

class _RewriteResult {
  final String script;
  final bool changed;

  const _RewriteResult({
    required this.script,
    required this.changed,
  });
}
