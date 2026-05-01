import 'package:html/parser.dart' as html_parser;

import 'package:soupreader/core/utils/html_text_formatter.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/models.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';
import 'package:soupreader/features/source/services/source/rule_text_utils.dart';

typedef RuleParserDebugStageFetcher = Future<FetchDebugResult> Function(
  String url, {
  required int rawState,
});
typedef RuleParserDebugLogger = void Function(
  String msg, {
  int state,
  bool showTime,
});
typedef RuleParserDebugRawEmitter = void Function(int state, String payload);

class RuleParserEngineDebugContentSupport {
  RuleParserEngineDebugContentSupport(this._ctx);

  final RuleParserContext _ctx;

  String _absoluteUrl(String baseUrl, String url) =>
      _ctx.urlBuildSupport.absoluteUrl(baseUrl, url);
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
  String? _buildNextChapterUrlKey({
    required String chapterEntryUrl,
    String? nextChapterUrl,
  }) =>
      _ctx.runtimeSupport.buildNextChapterUrlKey(
        chapterEntryUrl: chapterEntryUrl,
        nextChapterUrl: nextChapterUrl,
      );
  bool _markVisitedUrl(Set<String> visitedUrlKeys, String url) =>
      _ctx.runtimeSupport.markVisitedUrl(visitedUrlKeys, url);
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
  String _applyReplaceRegex(String content, String replaceRegex) =>
      RuleTextUtils.applyReplaceRegex(content, replaceRegex);
  String _cleanContent(String content, {required String baseUrl}) =>
      HtmlTextFormatter.formatKeepImageTags(content, baseUrl: baseUrl);
  String _parseRule(dynamic element, String? rule, String baseUrl) =>
      _ctx.ruleParseSupport.parseRule(element, rule, baseUrl);

  Future<bool> debugContentOnly({
    required BookSource source,
    required String chapterUrl,
    String? nextChapterUrl,
    required RuleParserDebugStageFetcher fetchStage,
    required RuleParserDebugRawEmitter emitRaw,
    required RuleParserDebugLogger log,
  }) async {
    log('︾开始解析正文页');
    final rule = source.ruleContent;
    if (rule == null) {
      log('⇒正文规则为空', state: -1);
      return false;
    }
    if ((rule.content ?? '').trim().isEmpty) {
      log('⇒正文规则为空,使用章节链接:$chapterUrl');
      emitRaw(41, chapterUrl);
      log('︽正文页解析完成');
      return true;
    }

    final visitedUrlKeys = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final nextChapterUrlKey = _buildNextChapterUrlKey(
      chapterEntryUrl: currentUrl,
      nextChapterUrl: nextChapterUrl,
    );
    var page = 0;
    final parts = <String>[];
    var totalExtracted = 0;
    final pendingNextUrls = <String>[];
    final queuedUrlKeys = <String>{};

    while (currentUrl.trim().isNotEmpty) {
      if (!_markVisitedUrl(visitedUrlKeys, currentUrl)) break;
      queuedUrlKeys.remove(_normalizeUrlVisitKey(currentUrl));
      log('≡正文页请求:${page + 1}');

      final body = (await fetchStage(currentUrl, rawState: 40)).body;
      if (body == null) {
        log('⇒正文页请求失败', state: -1);
        break;
      }
      final stageBody = _applyStageResponseJs(
        responseText: body,
        jsRule: rule.webJs,
        currentUrl: currentUrl,
        jsLib: source.jsLib,
        stageLabel: 'webJs',
        onLog: (msg) => log('└$msg', showTime: false),
      );
      emitRaw(40, stageBody);

      final trimmed = stageBody.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(stageBody)
          : null;

      String extracted;
      List<String> nextCandidates = const <String>[];
      if (jsonRoot != null && rule.content != null && _looksLikeJsonPath(rule.content!)) {
        extracted = _parseValueOnNode(jsonRoot, rule.content, currentUrl);
        if (rule.nextContentUrl != null && rule.nextContentUrl!.trim().isNotEmpty) {
          nextCandidates = _parseStringListFromJson(
            json: jsonRoot,
            rule: rule.nextContentUrl!,
            baseUrl: currentUrl,
            isUrl: true,
          );
        }
      } else {
        final root = html_parser.parse(stageBody).documentElement;
        if (root == null) {
          log('⇒页面无 documentElement', state: -1);
          return false;
        }
        extracted = _parseRule(root, rule.content, currentUrl);
        if (rule.nextContentUrl != null && rule.nextContentUrl!.trim().isNotEmpty) {
          nextCandidates = _parseStringListFromHtml(
            root: root,
            rule: rule.nextContentUrl!,
            baseUrl: currentUrl,
            isUrl: true,
          );
        }
      }

      if (nextCandidates.isNotEmpty) {
        log('┌获取正文下一页');
        log('└${nextCandidates.join('\n')}');
      }

      totalExtracted += extracted.length;
      var processed = extracted;
      if (rule.replaceRegex != null && rule.replaceRegex!.trim().isNotEmpty) {
        processed = _applyReplaceRegex(processed, rule.replaceRegex!);
      }
      final cleaned = _cleanContent(processed, baseUrl: currentUrl);
      if (cleaned.trim().isNotEmpty) parts.add(cleaned);

      if (nextCandidates.isNotEmpty) {
        final collect = _collectNextUrlCandidatesWithDebug(
          nextCandidates,
          currentUrl: currentUrl,
          visitedUrlKeys: visitedUrlKeys,
          queuedUrlKeys: queuedUrlKeys,
          blockedUrlKey: nextChapterUrlKey,
        );
        log('┌正文下一页候选决策');
        log('└${collect.debugLines.join('\n')}');
        if (collect.urls.isEmpty) {
          if (collect.hasBlockedCandidate) log('≡命中下一章链接，停止正文翻页');
        } else {
          for (final url in collect.urls) {
            final key = _normalizeUrlVisitKey(url);
            if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
            queuedUrlKeys.add(key);
            pendingNextUrls.add(url);
          }
          log('┌正文下一页入队结果');
          log('└${pendingNextUrls.join('\n')}');
        }
      }

      if (pendingNextUrls.isEmpty) {
        log('≡正文翻页结束：无可用下一页');
        break;
      }
      currentUrl = pendingNextUrls.removeAt(0);
      page++;
      if (page >= 1000) {
        log('≡正文翻页达到安全上限（1000），停止继续翻页');
        break;
      }
    }

    final cleanedAll = parts.join('\n');
    emitRaw(41, cleanedAll);
    log('◇分页:${parts.length} 提取总长:$totalExtracted 清理后总长:${cleanedAll.length}');
    log('┌获取正文内容');
    final preview = cleanedAll.length <= 2000
        ? cleanedAll
        : '${cleanedAll.substring(0, 2000)}\n…（已截断，查看“正文结果”可看全文）';
    log('└\n$preview');
    if (cleanedAll.trim().isEmpty) {
      log('≡内容为空', state: -1);
      return false;
    }
    log('︽正文页解析完成');
    return true;
  }
}
