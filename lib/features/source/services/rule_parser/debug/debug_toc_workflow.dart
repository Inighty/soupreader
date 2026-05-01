import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_content_support.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';

class RuleParserEngineDebugTocWorkflowSupport {
  RuleParserEngineDebugTocWorkflowSupport(this._ctx);

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
  ({List<String> urls, List<String> debugLines, bool hasBlockedCandidate})
      _collectNextUrlCandidatesWithDebug(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    Set<String>? queuedUrlKeys,
    String? blockedUrlKey,
    int maxLogItems = 20,
  }) =>
          _ctx.runtimeSupport.collectNextUrlCandidatesWithDebug(
            candidates,
            currentUrl: currentUrl,
            visitedUrlKeys: visitedUrlKeys,
            queuedUrlKeys: queuedUrlKeys,
            blockedUrlKey: blockedUrlKey,
            maxLogItems: maxLogItems,
          );
  String _normalizeUrlVisitKey(String url) =>
      _ctx.runtimeSupport.normalizeUrlVisitKey(url);
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
  bool _markVisitedUrl(Set<String> visitedUrlKeys, String url) =>
      _ctx.runtimeSupport.markVisitedUrl(visitedUrlKeys, url);
  Future<bool> _debugContentOnly({
    required BookSource source,
    required String chapterUrl,
    String? nextChapterUrl,
    required RuleParserDebugStageFetcher fetchStage,
    required RuleParserDebugRawEmitter emitRaw,
    required RuleParserDebugLogger log,
  }) =>
      _ctx.debugContentSupport.debugContentOnly(
        source: source,
        chapterUrl: chapterUrl,
        nextChapterUrl: nextChapterUrl,
        fetchStage: fetchStage,
        emitRaw: emitRaw,
        log: log,
      );

  Future<bool> debugTocThenContent({
    required BookSource source,
    required String tocUrl,
    required RuleParserDebugStageFetcher fetchStage,
    required RuleParserDebugRawEmitter emitRaw,
    required RuleParserDebugLogger log,
  }) async {
    log('︾开始解析目录页');
    final tocRule = source.ruleToc;
    if (tocRule == null) {
      log('⇒目录规则为空', state: -1);
      return false;
    }

    final normalized = _normalizeListRule(tocRule.chapterList);
    final toc = <TocItem>[];
    final visitedUrlKeys = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    var page = 0;
    final pendingNextUrls = <String>[];
    final queuedUrlKeys = <String>{};

    _runPreUpdateJs(
      jsRule: tocRule.preUpdateJs,
      currentUrl: currentUrl,
      jsLib: source.jsLib,
      onLog: (msg) => log('└$msg', showTime: false),
    );

    while (currentUrl.trim().isNotEmpty) {
      if (!_markVisitedUrl(visitedUrlKeys, currentUrl)) break;
      queuedUrlKeys.remove(_normalizeUrlVisitKey(currentUrl));
      log('≡目录页请求:${page + 1}');

      final cached = page == 0 ? _getCachedBookInfoTocHtml(currentUrl) : null;
      final body = cached ?? (await fetchStage(currentUrl, rawState: 30)).body;
      if (body == null) break;
      if (cached != null) log('└复用详情页源码作为目录页', showTime: false);
      emitRaw(30, body);

      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;
      List<String> nextCandidates = const <String>[];

      log('┌获取章节列表');
      if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
        final nodes = _selectJsonList(jsonRoot, normalized.selector);
        log('└列表大小:${nodes.length}');
        for (var i = 0; i < nodes.length; i++) {
          final node = nodes[i];
          final name = _parseValueOnNode(node, tocRule.chapterName, currentUrl);
          final tag = _parseValueOnNode(node, tocRule.updateTime, currentUrl);
          final isVolume = _isRuleTruthy(_parseValueOnNode(node, tocRule.isVolume, currentUrl));
          final isVip = _isRuleTruthy(_parseValueOnNode(node, tocRule.isVip, currentUrl));
          final isPay = _isRuleTruthy(_parseValueOnNode(node, tocRule.isPay, currentUrl));
          var url = _parseValueOnNode(node, tocRule.chapterUrl, currentUrl);
          if (url.isNotEmpty && !url.startsWith('http')) url = _absoluteUrl(currentUrl, url);
          if (url.trim().isEmpty) {
            url = isVolume ? '$name$i' : currentUrl;
            log(
              isVolume ? '⇒一级目录$i未获取到url,使用标题替代' : '⇒目录$i未获取到url,使用baseUrl替代',
              showTime: false,
            );
          }
          if (toc.isEmpty && i == 0) {
            _logChapterSample(log, name: name, url: url, tag: tag, isVip: isVip, isPay: isPay);
          }
          if (name.isEmpty || url.isEmpty) continue;
          toc.add(TocItem(
            index: toc.length,
            name: name,
            url: url,
            isVolume: isVolume,
            isVip: isVip,
            isPay: isPay,
            tag: tag.isEmpty ? null : tag,
          ));
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
        final document = html_parser.parse(body);
        final elements = _selectAllElementsByRule(document, normalized.selector);
        log('└列表大小:${elements.length}');
        for (var i = 0; i < elements.length; i++) {
          final element = elements[i];
          final name = _parseRule(element, tocRule.chapterName, currentUrl);
          final tag = _parseRule(element, tocRule.updateTime, currentUrl);
          final isVolume = _isRuleTruthy(_parseRule(element, tocRule.isVolume, currentUrl));
          final isVip = _isRuleTruthy(_parseRule(element, tocRule.isVip, currentUrl));
          final isPay = _isRuleTruthy(_parseRule(element, tocRule.isPay, currentUrl));
          var url = _parseRuleAsUrlLikeLegado(element, tocRule.chapterUrl, currentUrl);
          if (url.trim().isEmpty) {
            url = isVolume ? '$name$i' : currentUrl;
            log(
              isVolume ? '⇒一级目录$i未获取到url,使用标题替代' : '⇒目录$i未获取到url,使用baseUrl替代',
              showTime: false,
            );
          }
          if (toc.isEmpty && i == 0) {
            _logChapterSample(log, name: name, url: url, tag: tag, isVip: isVip, isPay: isPay);
          }
          if (name.isEmpty || url.isEmpty) continue;
          toc.add(TocItem(
            index: toc.length,
            name: name,
            url: url,
            isVolume: isVolume,
            isVip: isVip,
            isPay: isPay,
            tag: tag.isEmpty ? null : tag,
          ));
        }
        if (tocRule.nextTocUrl != null && tocRule.nextTocUrl!.trim().isNotEmpty) {
          final root = document.documentElement;
          if (root != null) {
            nextCandidates = _parseStringListFromHtml(
              root: root,
              rule: tocRule.nextTocUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
          }
        }
      }

      if (nextCandidates.isNotEmpty) {
        log('┌获取目录下一页');
        log('└${nextCandidates.join('\n')}');
        final collect = _collectNextUrlCandidatesWithDebug(
          nextCandidates,
          currentUrl: currentUrl,
          visitedUrlKeys: visitedUrlKeys,
          queuedUrlKeys: queuedUrlKeys,
        );
        log('┌目录下一页候选决策');
        log('└${collect.debugLines.join('\n')}');
        for (final url in collect.urls) {
          final key = _normalizeUrlVisitKey(url);
          if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
          queuedUrlKeys.add(key);
          pendingNextUrls.add(url);
        }
        if (collect.urls.isNotEmpty) {
          log('┌目录下一页入队结果');
          log('└${pendingNextUrls.join('\n')}');
        }
      }

      if (pendingNextUrls.isEmpty) {
        log('≡目录翻页结束：无可用下一页');
        break;
      }
      currentUrl = pendingNextUrls.removeAt(0);
      page++;
      if (page >= 1000) {
        log('≡目录翻页达到安全上限（1000），停止继续翻页');
        break;
      }
    }

    var out = _postProcessTocLikeLegado(
      chapters: toc,
      listRuleReverse: normalized.reverse,
    );
    out = _applyTocFormatJs(toc: out, formatJs: tocRule.formatJs, jsLib: source.jsLib);
    log('◇章节总数:${out.length}');
    if (out.isEmpty) {
      log('≡没有正文章节', state: -1);
      return false;
    }

    log('︽目录页解析完成', showTime: false);
    log('', showTime: false);
    final readable =
        out.where((item) => !(item.isVolume && item.url.startsWith(item.name))).toList(growable: false);
    if (readable.isEmpty) {
      log('≡没有正文章节');
      return true;
    }
    return _debugContentOnly(
      source: source,
      chapterUrl: readable.first.url,
      nextChapterUrl: readable.length > 1 ? readable[1].url : readable.first.url,
      fetchStage: fetchStage,
      emitRaw: emitRaw,
      log: log,
    );
  }

  void _logChapterSample(
    RuleParserDebugLogger log, {
    required String name,
    required String url,
    required String tag,
    required bool isVip,
    required bool isPay,
  }) {
    log('┌获取章节名');
    log('└$name');
    log('┌获取章节链接');
    log('└$url');
    log('┌获取章节信息');
    log('└$tag');
    log('┌是否VIP');
    log('└$isVip');
    log('┌是否购买');
    log('└$isPay');
  }
}
