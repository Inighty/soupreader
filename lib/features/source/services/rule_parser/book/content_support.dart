import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';
import 'package:soupreader/core/utils/html_text_formatter.dart';
import 'package:soupreader/features/source/services/source/rule_text_utils.dart';

class RuleParserEngineContentSupport {
  RuleParserEngineContentSupport(this._ctx);

  final RuleParserContext _ctx;

  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
  String? _buildNextChapterUrlKey({
    required String chapterEntryUrl,
    String? nextChapterUrl,
  }) =>
      _ctx.runtimeSupport.buildNextChapterUrlKey(
        chapterEntryUrl: chapterEntryUrl,
        nextChapterUrl: nextChapterUrl,
      );
  String _normalizeUrlVisitKey(String url) =>
      _ctx.runtimeSupport.normalizeUrlVisitKey(url);
  Future<String?> _fetch(
    String url, {
    String? header,
    String? jsLib,
    String? loginCheckJs,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
    CancelToken? cancelToken,
    void Function(String finalUrl)? onFinalUrl,
    void Function(bool isRedirect)? onIsRedirect,
  }) =>
      _ctx.fetchSupport.fetch(
        url,
        header: header,
        jsLib: jsLib,
        loginCheckJs: loginCheckJs,
        timeoutMs: timeoutMs,
        enabledCookieJar: enabledCookieJar,
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
        cancelToken: cancelToken,
        onFinalUrl: onFinalUrl,
        onIsRedirect: onIsRedirect,
      );
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
  String _applyStageResponseJs({
    required String responseText,
    required String? jsRule,
    required String currentUrl,
    String? jsLib,
    String stageLabel = '',
    void Function(String message)? onLog,
  }) =>
      _ctx.jsSupport.applyStageResponseJs(
        responseText: responseText,
        jsRule: jsRule,
        currentUrl: currentUrl,
        jsLib: jsLib,
        stageLabel: stageLabel,
        onLog: onLog,
      );
  dynamic _tryDecodeJsonValue(String text) => _ctx.tryDecodeJsonValue(text);
  bool _looksLikeJsonPath(String rule) =>
      _ctx.ruleParseSupport.looksLikeJsonPath(rule);
  String _parseValueOnNode(dynamic node, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseValueOnNode(node, rule, baseUrl);
  List<String> _parseStringListFromJson({
    required dynamic json,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) =>
      _ctx.ruleParseSupport.parseStringListFromJson(
        json: json,
        rule: rule,
        baseUrl: baseUrl,
        isUrl: isUrl,
      );
  String _parseRule(dynamic element, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseRule(element, rule, baseUrl);
  List<String> _parseStringListFromHtml({
    required dynamic root,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) =>
      _ctx.ruleParseSupport.parseStringListFromHtml(
        root: root,
        rule: rule,
        baseUrl: baseUrl,
        isUrl: isUrl,
      );
  String _applyReplaceRegex(String content, String replaceRegex) =>
      RuleTextUtils.applyReplaceRegex(content, replaceRegex);
  String _cleanContent(String content, {required String baseUrl}) =>
      HtmlTextFormatter.formatKeepImageTags(content, baseUrl: baseUrl);
  List<String> _collectNextUrlCandidates(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    Set<String>? queuedUrlKeys,
    String? blockedUrlKey,
  }) =>
      _ctx.runtimeSupport.collectNextUrlCandidates(
        candidates,
        currentUrl: currentUrl,
        visitedUrlKeys: visitedUrlKeys,
        queuedUrlKeys: queuedUrlKeys,
        blockedUrlKey: blockedUrlKey,
      );

  Future<String> getContent(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
    CancelToken? cancelToken,
  }) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) return '';
    if ((contentRule.content ?? '').trim().isEmpty) {
      return chapterUrl;
    }

    final visitedUrlKeys = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final nextChapterUrlKey = _buildNextChapterUrlKey(
      chapterEntryUrl: currentUrl,
      nextChapterUrl: nextChapterUrl,
    );
    var page = 0;
    const safetyMaxPages = 1000;
    final parts = <String>[];
    final pendingNextUrls = <String>[];
    final queuedUrlKeys = <String>{};

    while (currentUrl.trim().isNotEmpty) {
      final currentKey = _normalizeUrlVisitKey(currentUrl);
      if (currentKey.isEmpty || !visitedUrlKeys.add(currentKey)) break;
      queuedUrlKeys.remove(currentKey);

      final response = await _fetch(
        currentUrl,
        header: source.header,
        jsLib: source.jsLib,
        loginCheckJs: source.loginCheckJs,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
        cancelToken: cancelToken,
      );
      if (response == null) break;

      final stageBody = _applyStageResponseJs(
        responseText: response,
        jsRule: contentRule.webJs,
        currentUrl: currentUrl,
        jsLib: source.jsLib,
        stageLabel: 'webJs',
      );
      final parsed = _parseContentPageLikeLegado(
        stageBody: stageBody,
        currentUrl: currentUrl,
        contentRule: contentRule,
      );

      var processed = parsed.extracted;
      if (contentRule.replaceRegex != null &&
          contentRule.replaceRegex!.trim().isNotEmpty) {
        processed = _applyReplaceRegex(processed, contentRule.replaceRegex!);
      }
      final cleaned = _cleanContent(processed, baseUrl: currentUrl);
      if (cleaned.trim().isNotEmpty) parts.add(cleaned);

      if (parsed.nextCandidates.isNotEmpty) {
        final appendUrls = _collectNextUrlCandidates(
          parsed.nextCandidates,
          currentUrl: currentUrl,
          visitedUrlKeys: visitedUrlKeys,
          queuedUrlKeys: queuedUrlKeys,
          blockedUrlKey: nextChapterUrlKey,
        );
        for (final u in appendUrls) {
          final key = _normalizeUrlVisitKey(u);
          if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
          queuedUrlKeys.add(key);
          pendingNextUrls.add(u);
        }
      }

      if (pendingNextUrls.isEmpty) break;
      currentUrl = pendingNextUrls.removeAt(0);
      page++;
      if (page >= safetyMaxPages) break;
    }

    return parts.join('\n');
  }

  Future<ContentDebugResult> getContentDebug(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
  }) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) {
      return ContentDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: 'ruleContent 为空',
      );
    }
    if ((contentRule.content ?? '').trim().isEmpty) {
      return ContentDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: chapterUrl.length,
        cleanedLength: chapterUrl.length,
        content: chapterUrl,
        error: null,
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      jsLib: source.jsLib,
      loginCheckJs: source.loginCheckJs,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    if (fetch.body == null) {
      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: fetch.error ?? '请求失败',
      );
    }

    final visitedUrlKeys = <String>{};
    var currentUrl = fullUrl;
    final nextChapterUrlKey = _buildNextChapterUrlKey(
      chapterEntryUrl: fullUrl,
      nextChapterUrl: nextChapterUrl,
    );
    var page = 0;
    const safetyMaxPages = 1000;
    var totalExtracted = 0;
    final parts = <String>[];
    final pendingNextUrls = <String>[];
    final queuedUrlKeys = <String>{};

    while (currentUrl.trim().isNotEmpty) {
      final currentKey = _normalizeUrlVisitKey(currentUrl);
      if (currentKey.isEmpty || !visitedUrlKeys.add(currentKey)) break;
      queuedUrlKeys.remove(currentKey);

      final body = (currentUrl == fullUrl)
          ? fetch.body!
          : await _fetch(
              currentUrl,
              header: source.header,
              jsLib: source.jsLib,
              loginCheckJs: source.loginCheckJs,
              timeoutMs: source.respondTime,
              enabledCookieJar: source.enabledCookieJar,
              sourceKey: source.bookSourceUrl,
              concurrentRate: source.concurrentRate,
            );
      if (body == null) break;

      final stageBody = _applyStageResponseJs(
        responseText: body,
        jsRule: contentRule.webJs,
        currentUrl: currentUrl,
        jsLib: source.jsLib,
        stageLabel: 'webJs',
      );
      final parsed = _parseContentPageLikeLegado(
        stageBody: stageBody,
        currentUrl: currentUrl,
        contentRule: contentRule,
      );
      totalExtracted += parsed.extracted.length;

      var text = parsed.extracted;
      if (contentRule.replaceRegex != null &&
          contentRule.replaceRegex!.isNotEmpty) {
        text = _applyReplaceRegex(text, contentRule.replaceRegex!);
      }
      final cleaned = _cleanContent(text, baseUrl: currentUrl);
      if (cleaned.trim().isNotEmpty) parts.add(cleaned);

      if (parsed.nextCandidates.isNotEmpty) {
        final appendUrls = _collectNextUrlCandidates(
          parsed.nextCandidates,
          currentUrl: currentUrl,
          visitedUrlKeys: visitedUrlKeys,
          queuedUrlKeys: queuedUrlKeys,
          blockedUrlKey: nextChapterUrlKey,
        );
        for (final u in appendUrls) {
          final key = _normalizeUrlVisitKey(u);
          if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
          queuedUrlKeys.add(key);
          pendingNextUrls.add(u);
        }
      }

      if (pendingNextUrls.isEmpty) break;
      currentUrl = pendingNextUrls.removeAt(0);
      page++;
      if (page >= safetyMaxPages) break;
    }

    final cleanedAll = parts.join('\n');
    return ContentDebugResult(
      fetch: fetch,
      requestType: DebugRequestType.content,
      requestUrlRule: chapterUrl,
      extractedLength: totalExtracted,
      cleanedLength: cleanedAll.length,
      content: cleanedAll,
      error: null,
    );
  }

  ({String extracted, List<String> nextCandidates}) _parseContentPageLikeLegado({
    required String stageBody,
    required String currentUrl,
    required ContentRule contentRule,
  }) {
    final trimmed = stageBody.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(stageBody)
        : null;

    if (jsonRoot != null &&
        contentRule.content != null &&
        _looksLikeJsonPath(contentRule.content!)) {
      return (
        extracted: _parseValueOnNode(jsonRoot, contentRule.content, currentUrl),
        nextCandidates: contentRule.nextContentUrl != null &&
                contentRule.nextContentUrl!.trim().isNotEmpty
            ? _parseStringListFromJson(
                json: jsonRoot,
                rule: contentRule.nextContentUrl!,
                baseUrl: currentUrl,
                isUrl: true,
              )
            : const <String>[],
      );
    }

    final document = html_parser.parse(stageBody);
    final root = document.documentElement;
    if (root == null) {
      return (extracted: '', nextCandidates: const <String>[]);
    }
    return (
      extracted: _parseRule(root, contentRule.content, currentUrl),
      nextCandidates: contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty
          ? _parseStringListFromHtml(
              root: root,
              rule: contentRule.nextContentUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            )
          : const <String>[],
    );
  }
}
