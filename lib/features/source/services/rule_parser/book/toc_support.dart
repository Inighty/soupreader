import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineTocSupport {
  RuleParserEngineTocSupport(this._ctx);

  final RuleParserContext _ctx;

  NormalizedListRule _normalizeListRule(String? rawRule) =>
      _ctx.normalizeListRule(rawRule);
  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
  void _runPreUpdateJs({
    required String? jsRule,
    required String currentUrl,
    String? jsLib,
    void Function(String message)? onLog,
  }) =>
      _ctx.jsSupport.runPreUpdateJs(
        jsRule: jsRule,
        currentUrl: currentUrl,
        jsLib: jsLib,
        onLog: onLog,
      );
  String? _getCachedBookInfoTocHtml(String tocUrl) =>
      _ctx.runtimeSupport.getCachedBookInfoTocHtml(tocUrl);
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
  dynamic _tryDecodeJsonValue(String text) => _ctx.tryDecodeJsonValue(text);
  bool _looksLikeJsonPath(String rule) =>
      _ctx.ruleParseSupport.looksLikeJsonPath(rule);
  List<dynamic> _selectJsonList(dynamic root, String rule) =>
      _ctx.ruleParseSupport.selectJsonList(root, rule);
  String _parseValueOnNode(dynamic node, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseValueOnNode(node, rule, baseUrl);
  bool _isRuleTruthy(String? raw) => _ctx.runtimeSupport.isRuleTruthy(raw);
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
  List<Element> _selectAllElementsByRule(
    dynamic parent,
    String selectorRule, {
    String? rawHtml,
  }) =>
      _ctx.selectorSupport.selectAllElementsByRule(
        parent,
        selectorRule,
        rawHtml: rawHtml,
      );
  String _parseRule(dynamic element, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseRule(element, rule, baseUrl);
  String _parseRuleAsUrlLikeLegado(
    dynamic element,
    String? rule,
    String baseUrl, {
    bool fallbackToBaseUrlWhenEmpty = false,
  }) =>
      _ctx.ruleParseSupport.parseRuleAsUrlLikeLegado(
        element,
        rule,
        baseUrl,
        fallbackToBaseUrlWhenEmpty: fallbackToBaseUrlWhenEmpty,
      );
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
  String _normalizeUrlVisitKey(String url) =>
      _ctx.runtimeSupport.normalizeUrlVisitKey(url);
  List<TocItem> _applyTocFormatJs({
    required List<TocItem> toc,
    required String? formatJs,
    String? jsLib,
  }) =>
      _ctx.jsSupport
          .applyTocFormatJs(toc: toc, formatJs: formatJs, jsLib: jsLib);

  Future<List<TocItem>> getToc(
    BookSource source,
    String tocUrl, {
    CancelToken? cancelToken,
  }) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) return [];

    final normalized = _normalizeListRule(tocRule.chapterList);
    final chapters = <TocItem>[];
    final visitedUrlKeys = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    var page = 0;
    const safetyMaxPages = 1000;
    final pendingNextUrls = <String>[];
    final queuedUrlKeys = <String>{};

    _runPreUpdateJs(
      jsRule: tocRule.preUpdateJs,
      currentUrl: currentUrl,
      jsLib: source.jsLib,
    );

    while (currentUrl.trim().isNotEmpty) {
      final currentKey = _normalizeUrlVisitKey(currentUrl);
      if (currentKey.isEmpty || !visitedUrlKeys.add(currentKey)) break;
      queuedUrlKeys.remove(currentKey);

      var response = page == 0 ? _getCachedBookInfoTocHtml(currentUrl) : null;
      response ??= await _fetch(
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

      final trimmed = response.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(response)
          : null;

      List<String> nextCandidates = const <String>[];
      if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
        final nodes = _selectJsonList(jsonRoot, normalized.selector);
        for (var i = 0; i < nodes.length; i++) {
          final node = nodes[i];
          final name = _parseValueOnNode(node, tocRule.chapterName, currentUrl);
          final tag = _parseValueOnNode(node, tocRule.updateTime, currentUrl);
          final isVolume =
              _isRuleTruthy(_parseValueOnNode(node, tocRule.isVolume, currentUrl));
          final isVip =
              _isRuleTruthy(_parseValueOnNode(node, tocRule.isVip, currentUrl));
          final isPay =
              _isRuleTruthy(_parseValueOnNode(node, tocRule.isPay, currentUrl));
          var url = _parseValueOnNode(node, tocRule.chapterUrl, currentUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(currentUrl, url);
          }
          if (url.trim().isEmpty) {
            url = isVolume ? '$name$i' : currentUrl;
          }
          if (name.isEmpty || url.isEmpty) continue;
          chapters.add(
            TocItem(
              index: chapters.length,
              name: name,
              url: url,
              isVolume: isVolume,
              isVip: isVip,
              isPay: isPay,
              tag: tag.isEmpty ? null : tag,
            ),
          );
        }
        if (tocRule.nextTocUrl != null && tocRule.nextTocUrl!.trim().isNotEmpty) {
          nextCandidates = _parseStringListFromJson(
            json: jsonRoot,
            rule: tocRule.nextTocUrl!,
            baseUrl: currentUrl,
            isUrl: true,
          );
        }
      } else {
        final document = html_parser.parse(response);
        final root = document.documentElement;
        if (root == null) break;
        final chapterElements =
            _selectAllElementsByRule(document, normalized.selector);
        for (var i = 0; i < chapterElements.length; i++) {
          final element = chapterElements[i];
          final name = _parseRule(element, tocRule.chapterName, currentUrl);
          final tag = _parseRule(element, tocRule.updateTime, currentUrl);
          final isVolume =
              _isRuleTruthy(_parseRule(element, tocRule.isVolume, currentUrl));
          final isVip =
              _isRuleTruthy(_parseRule(element, tocRule.isVip, currentUrl));
          final isPay =
              _isRuleTruthy(_parseRule(element, tocRule.isPay, currentUrl));
          var url = _parseRuleAsUrlLikeLegado(
            element,
            tocRule.chapterUrl,
            currentUrl,
          );
          if (url.trim().isEmpty) {
            url = isVolume ? '$name$i' : currentUrl;
          }
          if (name.isEmpty || url.isEmpty) continue;
          chapters.add(
            TocItem(
              index: chapters.length,
              name: name,
              url: url,
              isVolume: isVolume,
              isVip: isVip,
              isPay: isPay,
              tag: tag.isEmpty ? null : tag,
            ),
          );
        }
        if (tocRule.nextTocUrl != null && tocRule.nextTocUrl!.trim().isNotEmpty) {
          nextCandidates = _parseStringListFromHtml(
            root: root,
            rule: tocRule.nextTocUrl!,
            baseUrl: currentUrl,
            isUrl: true,
          );
        }
      }

      if (nextCandidates.isNotEmpty) {
        final appendUrls = _collectNextUrlCandidates(
          nextCandidates,
          currentUrl: currentUrl,
          visitedUrlKeys: visitedUrlKeys,
          queuedUrlKeys: queuedUrlKeys,
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

    final reIndexed = postProcessTocLikeLegado(
      chapters: chapters,
      listRuleReverse: normalized.reverse,
    );
    return _applyTocFormatJs(
      toc: reIndexed,
      formatJs: tocRule.formatJs,
      jsLib: source.jsLib,
    );
  }

  List<TocItem> postProcessTocLikeLegado({
    required List<TocItem> chapters,
    required bool listRuleReverse,
  }) {
    if (chapters.isEmpty) return const <TocItem>[];

    var working = chapters;
    if (!listRuleReverse) {
      working = working.reversed.toList(growable: false);
    }
    var deduped = _dedupTocByUrlLikeLegado(working);
    deduped = deduped.reversed.toList(growable: false);

    return <TocItem>[
      for (var i = 0; i < deduped.length; i++)
        TocItem(
          index: i,
          name: deduped[i].name,
          url: deduped[i].url,
          isVolume: deduped[i].isVolume,
          isVip: deduped[i].isVip,
          isPay: deduped[i].isPay,
          tag: deduped[i].tag,
        ),
    ];
  }

  List<TocItem> _dedupTocByUrlLikeLegado(List<TocItem> toc) {
    if (toc.isEmpty) return const <TocItem>[];
    final seenUrls = <String>{};
    final out = <TocItem>[];
    for (final item in toc) {
      final url = item.url;
      if (url.trim().isEmpty) continue;
      if (!seenUrls.add(url)) continue;
      out.add(item);
    }
    return out;
  }
}
