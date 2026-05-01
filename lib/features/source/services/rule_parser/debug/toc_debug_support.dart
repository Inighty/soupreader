import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineTocDebugSupport {
  RuleParserEngineTocDebugSupport(this._ctx);

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
  Future<FetchDebugResult> _fetchDebug(
    String url, {
    String? header,
    String? jsLib,
    String? loginCheckJs,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
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
  List<TocItem> _postProcessTocLikeLegado({
    required List<TocItem> chapters,
    required bool listRuleReverse,
  }) =>
      _ctx.tocSupport.postProcessTocLikeLegado(
        chapters: chapters,
        listRuleReverse: listRuleReverse,
      );
  List<TocItem> _applyTocFormatJs({
    required List<TocItem> toc,
    required String? formatJs,
    String? jsLib,
  }) =>
      _ctx.jsSupport
          .applyTocFormatJs(toc: toc, formatJs: formatJs, jsLib: jsLib);

  Future<TocDebugResult> getTocDebug(BookSource source, String tocUrl) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) {
      return TocDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: null,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: 'ruleToc 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
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
      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: tocRule.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    final normalized = _normalizeListRule(tocRule.chapterList);
    final chapters = <TocItem>[];
    Map<String, String> sample = const {};
    var listCount = 0;
    final body = fetch.body!;

    _runPreUpdateJs(
      jsRule: tocRule.preUpdateJs,
      currentUrl: fullUrl,
      jsLib: source.jsLib,
    );
    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
      final nodes = _selectJsonList(jsonRoot, normalized.selector);
      listCount = nodes.length;
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final name = _parseValueOnNode(node, tocRule.chapterName, fullUrl);
        final tag = _parseValueOnNode(node, tocRule.updateTime, fullUrl);
        final isVolume =
            _isRuleTruthy(_parseValueOnNode(node, tocRule.isVolume, fullUrl));
        final isVip =
            _isRuleTruthy(_parseValueOnNode(node, tocRule.isVip, fullUrl));
        final isPay =
            _isRuleTruthy(_parseValueOnNode(node, tocRule.isPay, fullUrl));
        var url = _parseValueOnNode(node, tocRule.chapterUrl, fullUrl);
        if (url.isNotEmpty && !url.startsWith('http')) {
          url = _absoluteUrl(fullUrl, url);
        }
        if (url.trim().isEmpty) {
          url = isVolume ? '$name$i' : fullUrl;
        }
        if (chapters.isEmpty) {
          sample = <String, String>{
            'name': name,
            'url': url,
            'tag': tag,
            'isVolume': '$isVolume',
            'isVip': '$isVip',
            'isPay': '$isPay',
          };
        }
        if (name.isNotEmpty && url.isNotEmpty) {
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
      }
      if (tocRule.nextTocUrl != null && tocRule.nextTocUrl!.trim().isNotEmpty) {
        final nextList = _parseStringListFromJson(
          json: jsonRoot,
          rule: tocRule.nextTocUrl!,
          baseUrl: fullUrl,
          isUrl: true,
        );
        if (nextList.isNotEmpty) {
          sample = <String, String>{...sample, 'nextTocUrl': nextList.join('\n')};
        }
      }
    } else {
      final document = html_parser.parse(body);
      final chapterElements =
          _selectAllElementsByRule(document, normalized.selector);
      listCount = chapterElements.length;
      for (var i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final name = _parseRule(element, tocRule.chapterName, fullUrl);
        final tag = _parseRule(element, tocRule.updateTime, fullUrl);
        final isVolume =
            _isRuleTruthy(_parseRule(element, tocRule.isVolume, fullUrl));
        final isVip =
            _isRuleTruthy(_parseRule(element, tocRule.isVip, fullUrl));
        final isPay =
            _isRuleTruthy(_parseRule(element, tocRule.isPay, fullUrl));
        var url = _parseRuleAsUrlLikeLegado(element, tocRule.chapterUrl, fullUrl);
        if (url.trim().isEmpty) {
          url = isVolume ? '$name$i' : fullUrl;
        }
        if (chapters.isEmpty) {
          sample = <String, String>{
            'name': name,
            'url': url,
            'tag': tag,
            'isVolume': '$isVolume',
            'isVip': '$isVip',
            'isPay': '$isPay',
          };
        }
        if (name.isNotEmpty && url.isNotEmpty) {
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
      }

      final root = document.documentElement;
      if (root != null &&
          tocRule.nextTocUrl != null &&
          tocRule.nextTocUrl!.trim().isNotEmpty) {
        final nextList = _parseStringListFromHtml(
          root: root,
          rule: tocRule.nextTocUrl!,
          baseUrl: fullUrl,
          isUrl: true,
        );
        if (nextList.isNotEmpty) {
          sample = <String, String>{...sample, 'nextTocUrl': nextList.join('\n')};
        }
      }
    }

    final reIndexed = _postProcessTocLikeLegado(
      chapters: chapters,
      listRuleReverse: normalized.reverse,
    );
    final formatted = _applyTocFormatJs(
      toc: reIndexed,
      formatJs: tocRule.formatJs,
      jsLib: source.jsLib,
    );
    if (formatted.isNotEmpty && sample.isNotEmpty) {
      sample = <String, String>{...sample, 'nameAfterFormat': formatted.first.name};
    }

    return TocDebugResult(
      fetch: fetch,
      requestType: DebugRequestType.toc,
      requestUrlRule: tocUrl,
      listRule: normalized.selector,
      listCount: listCount,
      toc: formatted,
      fieldSample: sample,
      error: null,
    );
  }
}
