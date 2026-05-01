import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:intl/intl.dart';

import 'package:soupreader/core/services/source_login_store.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';
import 'package:soupreader/features/source/services/source_login/script_bridge.dart';
import 'package:soupreader/features/source/services/source_login/script_models.dart';
import 'package:soupreader/features/source/services/source_login/script_rewriter.dart';
import 'package:soupreader/features/source/services/source_login/script_utils.dart';

export 'package:soupreader/features/source/services/source_login/script_models.dart';

class SourceLoginScriptService {
  const SourceLoginScriptService({
    SourceLoginScriptRequestExecutor? requestExecutor,
  }) : _requestExecutor = requestExecutor;

  final SourceLoginScriptRequestExecutor? _requestExecutor;

  static const String _errorPrefix = '__SR_LOGIN_ERROR__';
  static const SourceLoginScriptRewriter _rewriter = SourceLoginScriptRewriter();

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
    return _rewriter.prepareScriptForAsyncNet(script);
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

    return _runScript(
      source: source,
      loginData: loginData,
      script: '''
        $loginJs
        if (typeof login === 'function') {
          await login.apply(this);
        } else {
          throw('Function login not implements!!!');
        }
      ''',
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

    return _runScript(
      source: source,
      loginData: loginData,
      script: '''
        $loginJs
        var result = __srToJavaMap(__srParseJsonMap(source.getLoginInfo()));
        $action
      ''',
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
      final raw = SourceLoginScriptUtils.readStringArg(args, 'value');
      final parsed = SourceLoginScriptUtils.parseHeaderPayload(raw);
      if (parsed == null) return false;
      currentHeaderMap
        ..clear()
        ..addAll(parsed);
      headerChanged = true;
      return true;
    });
    runtime.onMessage('SourceLog', (dynamic args) {
      final message = SourceLoginScriptUtils.readStringArg(args, 'message');
      if (message.isNotEmpty) logs.add(message);
      return true;
    });
    runtime.onMessage('JavaTimeFormatUTC', (dynamic args) {
      final timestampRaw = SourceLoginScriptUtils.readNumArg(args, 'timestamp');
      final pattern = SourceLoginScriptUtils.readStringArg(args, 'pattern');
      final offsetHours =
          SourceLoginScriptUtils.readNumArg(args, 'offset').round();
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
    runtime.onMessage(
      'JavaRandomUUID',
      (_) => SourceLoginScriptUtils.randomUuidV4(),
    );
    runtime.onMessage('JavaAjax', (dynamic args) async {
      final response = await _requestScriptHttp(source: source, args: args);
      return response.body;
    });
    runtime.onMessage('JavaConnect', (dynamic args) async {
      final response = await _requestScriptHttp(source: source, args: args);
      return jsonEncode(<String, dynamic>{
        'body': response.body,
        'code': response.statusCode,
        'message': response.statusMessage,
        'url': response.finalUrl,
        'headers': response.headers,
      });
    });

    final preparedScript = _rewriter.prepareScriptForAsyncNet(script);

    try {
      final result = runtime.evaluate('''
        (async function(){
          try {
            $sourceLoginScriptBridgeJs
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
      final output = SourceLoginScriptUtils.normalizePromiseOutput(
        settled.stringResult,
      ).trim();
      if (result.isError || output.startsWith(_errorPrefix)) {
        final message = output.startsWith(_errorPrefix)
            ? output.substring(_errorPrefix.length).trim()
            : output;
        final detail =
            message.isEmpty ? '登录脚本执行失败' : '登录脚本执行失败：$message';
        return SourceLoginScriptResult(
          success: false,
          executed: true,
          message: detail,
        );
      }
    } catch (error) {
      return SourceLoginScriptResult(
        success: false,
        executed: true,
        message: '登录脚本执行失败：$error',
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
          await SourceLoginScriptUtils.persistCookieHeader(
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
    final url = SourceLoginScriptUtils.readStringArg(args, 'url').trim();
    final headerRaw = SourceLoginScriptUtils.readStringArg(args, 'header');
    final headerOverride =
        SourceLoginScriptUtils.parseHeaderOverridePayload(headerRaw);
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
    } catch (error) {
      return ScriptHttpResponse(
        requestUrl: url,
        finalUrl: url,
        statusCode: 200,
        statusMessage: 'OK',
        headers: const <String, String>{},
        body: error.toString(),
      );
    }
  }
}
