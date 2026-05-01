import 'package:dio/dio.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_book_support.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_content_support.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_toc_workflow.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineDebugRunSupport {
  RuleParserEngineDebugRunSupport(this._ctx);

  final RuleParserContext _ctx;

  Future<FetchDebugResult> _fetchDebug(
    String url, {
    String? header,
    String? jsLib,
    String? loginCheckJs,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
    CancelToken? cancelToken,
  }) =>
      _ctx.fetchSupport.fetchDebug(
        url,
        header: header,
        jsLib: jsLib,
        loginCheckJs: loginCheckJs,
        timeoutMs: timeoutMs,
        enabledCookieJar: enabledCookieJar,
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
        cancelToken: cancelToken,
      );
  String? _getHeaderIgnoreCase(Map<String, String> headers, String name) =>
      _ctx.requestCodecSupport.getHeaderIgnoreCase(headers, name);
  String _formatRequestHeadersForLog(Map<String, String> headers) =>
      _ctx.requestLifecycleSupport.formatRequestHeadersForLog(headers);
  String _importantResponseHeaders(Map<String, String> headers) =>
      _ctx.requestLifecycleSupport.importantResponseHeaders(headers);
  RuleParserEngineDebugBookSupport get _debugBookSupport =>
      _ctx.debugBookSupport;
  RuleParserEngineDebugTocWorkflowSupport get _debugTocWorkflowSupport =>
      _ctx.debugTocWorkflowSupport;
  RuleParserEngineDebugContentSupport get _debugContentSupport =>
      _ctx.debugContentSupport;

  Future<void> debugRun(
    BookSource source,
    String key, {
    required void Function(SourceDebugEvent event) onEvent,
    CancelToken? cancelToken,
  }) async {
    final started = DateTime.now();

    String formatTimePrefix() {
      final ms = DateTime.now().difference(started).inMilliseconds;
      final mm = ((ms ~/ 60000) % 60).toString().padLeft(2, '0');
      final ss = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
      final sss = (ms % 1000).toString().padLeft(3, '0');
      return '[$mm:$ss.$sss]';
    }

    void log(String msg, {int state = 1, bool showTime = true}) {
      onEvent(
        SourceDebugEvent(
          state: state,
          message: showTime ? '${formatTimePrefix()} $msg' : msg,
        ),
      );
    }

    void rawHtml(int state, String html) {
      onEvent(SourceDebugEvent(state: state, message: html, isRaw: true));
    }

    void rawText(int state, String text) {
      onEvent(SourceDebugEvent(state: state, message: text, isRaw: true));
    }

    bool isAbsUrl(String input) {
      final trimmed = input.trim();
      return trimmed.startsWith('http://') || trimmed.startsWith('https://');
    }

    Future<FetchDebugResult> fetchStage(
      String url, {
      required int rawState,
    }) async {
      final res = await _fetchDebug(
        url,
        header: source.header,
        jsLib: source.jsLib,
        loginCheckJs: source.loginCheckJs,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
        cancelToken: cancelToken,
      );
      if (res.headersWarning != null && res.headersWarning!.trim().isNotEmpty) {
        log('└请求头解析提示：${res.headersWarning}', showTime: false);
      }
      log(
        '└请求头（CookieJar=${(source.enabledCookieJar ?? true) ? '开' : '关'}）\n'
        '${_formatRequestHeadersForLog(res.requestHeaders)}',
        showTime: false,
      );
      if (res.retryCount > 0) log('└重试次数：${res.retryCount}', showTime: false);
      log('└并发率：${res.concurrentDecision}；等待=${res.concurrentWaitMs}ms', showTime: false);
      log('└请求决策：${res.methodDecision}', showTime: false);
      log('└重试决策：${res.retryDecision}；实际重试=${res.retryCount}', showTime: false);
      log('└请求编码：${res.requestCharsetDecision}', showTime: false);
      final bodyPolicy = res.bodyEncoding == 'none'
          ? res.bodyDecision
          : '${res.bodyDecision}（bodyEncoding=${res.bodyEncoding}）';
      log('└请求体决策：$bodyPolicy', showTime: false);
      final requestContentType = _getHeaderIgnoreCase(res.requestHeaders, 'Content-Type');
      if (requestContentType != null && requestContentType.trim().isNotEmpty) {
        log('└Content-Type：$requestContentType', showTime: false);
      }
      if (res.requestBodySnippet != null && res.requestBodySnippet!.trim().isNotEmpty) {
        log('└请求体（${res.method}）\n${res.requestBodySnippet}', showTime: false);
      } else {
        log('└请求方法：${res.method}', showTime: false);
      }

      final status = res.statusCode;
      final statusText = status != null ? ' ($status)' : '';
      final isBadStatus = status != null && status >= 400;
      if (res.body != null) {
        log(
          '≡获取${isBadStatus ? '完成' : '成功'}:${res.finalUrl ?? res.requestUrl}$statusText ${res.elapsedMs}ms',
          state: isBadStatus ? -1 : 1,
        );
        if (res.responseCharset != null && res.responseCharset!.trim().isNotEmpty) {
          log('└响应编码：${res.responseCharset}', showTime: false);
        }
        if (res.responseCharsetDecision != null &&
            res.responseCharsetDecision!.trim().isNotEmpty) {
          log('└响应解码决策：${res.responseCharsetDecision}', showTime: false);
        }
        rawHtml(rawState, res.body!);
        if (isBadStatus) {
          log('└HTTP 状态码异常：$status', state: -1, showTime: false);
          final headerHint = _importantResponseHeaders(res.responseHeaders);
          if (headerHint.isNotEmpty) log('└响应头：$headerHint', state: -1, showTime: false);
          if (status == 403) {
            log(
              '└提示：403 多为反爬/需要 Referer/Cookie。可在书源 header 里补 Referer/Origin/Cookie，或开启 enabledCookieJar。',
              state: -1,
              showTime: false,
            );
          }
        }
      } else {
        log('≡请求失败:${res.requestUrl}$statusText ${res.elapsedMs}ms', state: -1);
        if (res.error != null && res.error!.trim().isNotEmpty) {
          log('└${res.error}', state: -1, showTime: false);
        }
      }
      return res;
    }

    try {
      log('︾开始解析');
      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        log('key 不能为空', state: -1);
        return;
      }

      if (isAbsUrl(trimmed)) {
        log('⇒开始访问详情页:$trimmed');
        final ok = await _debugBookSupport.debugInfoTocContent(
          source: source,
          bookUrl: trimmed,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (ok) log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.contains('::')) {
        final url = trimmed.substring(trimmed.indexOf('::') + 2).trim();
        log('⇒开始访问发现页:$url');
        final firstBookUrl = await _debugBookSupport.debugBookListThenPickFirst(
          source: source,
          keyOrUrl: url,
          mode: RuleParserDebugListMode.explore,
          exploreUrlOverride: url,
          fetchStage: fetchStage,
          log: log,
        );
        if (firstBookUrl == null) {
          log('︽未获取到书籍', state: -1);
          return;
        }
        final ok = await _debugBookSupport.debugInfoTocContent(
          source: source,
          bookUrl: firstBookUrl,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (ok) log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.startsWith('++')) {
        final url = trimmed.substring(2).trim();
        log('⇒开始访目录页:$url');
        final ok = await _debugTocWorkflowSupport.debugTocThenContent(
          source: source,
          tocUrl: url,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (ok) log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.startsWith('--')) {
        final url = trimmed.substring(2).trim();
        log('⇒开始访正文页:$url');
        final ok = await _debugContentSupport.debugContentOnly(
          source: source,
          chapterUrl: url,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (ok) log('︽解析完成', state: 1000);
        return;
      }

      log('⇒开始搜索关键字:$trimmed');
      final firstBookUrl = await _debugBookSupport.debugBookListThenPickFirst(
        source: source,
        keyOrUrl: trimmed,
        mode: RuleParserDebugListMode.search,
        fetchStage: fetchStage,
        log: log,
      );
      if (firstBookUrl == null) {
        log('︽未获取到书籍', state: -1);
        return;
      }
      final ok = await _debugBookSupport.debugInfoTocContent(
        source: source,
        bookUrl: firstBookUrl,
        fetchStage: fetchStage,
        emitRaw: rawText,
        log: log,
      );
      if (ok) log('︽解析完成', state: 1000);
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) log('调试异常: $e', state: -1);
    } catch (e, st) {
      log('调试异常: $e', state: -1);
      log(st.toString(), state: -1, showTime: false);
    }
  }
}
