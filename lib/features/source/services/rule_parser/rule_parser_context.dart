import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import 'package:soupreader/features/source/services/rule_parser/book/book_detail_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_info_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_list_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/content_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/toc_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/runtime_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';
import 'package:soupreader/features/source/services/rule_parser/core/url_build_support.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_book_support.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_content_support.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_run_support.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/debug_toc_workflow.dart';
import 'package:soupreader/features/source/services/rule_parser/debug/toc_debug_support.dart';
import 'package:soupreader/features/source/services/rule_parser/fetch/cover_support.dart';
import 'package:soupreader/features/source/services/rule_parser/fetch/fetch_debug_failure.dart';
import 'package:soupreader/features/source/services/rule_parser/fetch/fetch_support.dart';
import 'package:soupreader/features/source/services/rule_parser/js/js_support.dart';
import 'package:soupreader/features/source/services/rule_parser/js/js_template_support.dart';
import 'package:soupreader/features/source/services/rule_parser/parse/rule_parse_support.dart';
import 'package:soupreader/features/source/services/rule_parser/parse/rule_query_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_codec_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_lifecycle_support.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_types.dart';
import 'package:soupreader/features/source/services/rule_parser/request/request_url_support.dart';
import 'package:soupreader/features/source/services/rule_parser/wiring/parser_wiring.dart';
import 'package:soupreader/features/source/services/rule_parser/workflow/discovery_workflow.dart';
import 'package:soupreader/features/source/services/rule_parser/workflow/read_workflow.dart';

/// 单一 DI 容器：装配并持有所有 [RuleParserEngine] 内部依赖的 Support。
///
/// 取代原先的 `RuleParserEngineBundle` + `RuleParserEngineWorkflowBundle`
/// 双层结构，让 `RuleParserEngine` 只暴露公开 API 即可，新增 Support
/// 时只需修改本文件以及 `wiring/parser_wiring.dart`。
///
/// 装配交给 [wireParserSupports]，按依赖图顺序构造所有 25 个 Support。
class RuleParserContext {
  RuleParserContext({
    required this.runtimeVariables,
    required this.bookInfoTocHtmlCache,
    required this.defaultHeaders,
    required this.httpHeaderTokenRegex,
    required this.concurrentRecordMap,
    required this.runtimeEvaluate,
    required this.tryDecodeJsonValue,
    required this.normalizeListRule,
    required this.selectDio,
    required this.loadCookiesForUrl,
  }) {
    wireParserSupports(this);
  }

  // ── 共享底层状态 ─────────────────────────────────────────
  final Map<String, String> runtimeVariables;
  final Map<String, String> bookInfoTocHtmlCache;
  final Map<String, String> defaultHeaders;
  final RegExp httpHeaderTokenRegex;
  final Map<String, ConcurrentRecord> concurrentRecordMap;
  final String Function(String script) runtimeEvaluate;
  final dynamic Function(String text) tryDecodeJsonValue;
  final NormalizedListRule Function(String? rawRule) normalizeListRule;
  final Dio Function({bool? enabledCookieJar}) selectDio;
  final Future<List<Cookie>> Function(String url) loadCookiesForUrl;

  // ── Support 实例（按依赖顺序晚绑定）──────────────────────
  late final RuleParserEngineRuntimeSupport runtimeSupport;
  late final RuleParserEngineJsSupport jsSupport;
  late final RuleParserEngineJsTemplateSupport jsTemplateSupport;
  late final RuleParserEngineRequestUrlSupport requestUrlSupport;
  late final RuleParserEngineRequestCodecSupport requestCodecSupport;
  late final RuleParserEngineRequestLifecycleSupport requestLifecycleSupport;
  late final RuleParserEngineUrlBuildSupport urlBuildSupport;
  late final RuleParserEngineSelectorSupport selectorSupport;
  late final RuleParserEngineRuleQuerySupport ruleQuerySupport;
  late final RuleParserEngineRuleParseSupport ruleParseSupport;
  late final RuleParserEngineBookDetailSupport bookDetailSupport;
  late final RuleParserEngineBookInfoSupport bookInfoSupport;
  late final RuleParserEngineBookListSupport bookListSupport;
  late final RuleParserEngineTocSupport tocSupport;
  late final RuleParserEngineTocDebugSupport tocDebugSupport;
  late final RuleParserEngineContentSupport contentSupport;
  late final RuleParserEngineFetchDebugFailureSupport fetchDebugFailureSupport;
  late final RuleParserEngineFetchSupport fetchSupport;
  late final RuleParserEngineCoverSupport coverSupport;
  late final RuleParserEngineDiscoveryWorkflowSupport discoveryWorkflowSupport;
  late final RuleParserEngineReadWorkflowSupport readWorkflowSupport;
  late final RuleParserEngineDebugContentSupport debugContentSupport;
  late final RuleParserEngineDebugTocWorkflowSupport debugTocWorkflowSupport;
  late final RuleParserEngineDebugBookSupport debugBookSupport;
  late final RuleParserEngineDebugRunSupport debugRunSupport;
}
