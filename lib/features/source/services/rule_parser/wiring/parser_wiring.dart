import 'package:soupreader/features/source/services/rule_parser/book/book_detail_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_info_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/book_list_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/content_support.dart';
import 'package:soupreader/features/source/services/rule_parser/book/toc_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/runtime_support.dart';
import 'package:soupreader/features/source/services/rule_parser/core/selector_support.dart';
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
import 'package:soupreader/features/source/services/rule_parser/request/request_url_support.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_context.dart';
import 'package:soupreader/features/source/services/rule_parser/workflow/discovery_workflow.dart';
import 'package:soupreader/features/source/services/rule_parser/workflow/read_workflow.dart';

/// 在 [RuleParserContext] 构造时按依赖图顺序装配所有 Support。
///
/// 25 个 Support 都遵循 `Support(this._ctx)` 形态，互相通过 ctx 取得对方
/// 引用，因此装配代码就是一行实例化 + 依赖图顺序。新增 Support 时只需要：
/// 1. 在 [RuleParserContext] 加 `late final XxxSupport xxxSupport;`
/// 2. 在本文件按拓扑顺序加 `ctx.xxxSupport = XxxSupport(ctx);`
///
/// 顺序约束：晚绑定 (`late final`) 让循环依赖只会在方法调用时被触发，
/// 因此构造期只需保证「不会在构造体里调用对方方法」即可。
void wireParserSupports(RuleParserContext ctx) {
  // ── 核心层：runtime / js / request / urlBuild ─────────────
  ctx.runtimeSupport = RuleParserEngineRuntimeSupport(ctx);
  ctx.jsSupport = RuleParserEngineJsSupport(ctx);
  ctx.jsTemplateSupport = RuleParserEngineJsTemplateSupport(ctx);
  ctx.requestUrlSupport = RuleParserEngineRequestUrlSupport(ctx);
  ctx.requestCodecSupport = RuleParserEngineRequestCodecSupport(ctx);
  ctx.requestLifecycleSupport = RuleParserEngineRequestLifecycleSupport(ctx);
  ctx.urlBuildSupport = RuleParserEngineUrlBuildSupport(ctx);

  // ── 解析层：selector / ruleQuery / ruleParse ──────────────
  ctx.selectorSupport = RuleParserEngineSelectorSupport(ctx);
  ctx.ruleQuerySupport = RuleParserEngineRuleQuerySupport(ctx);
  ctx.ruleParseSupport = RuleParserEngineRuleParseSupport(ctx);

  // ── 请求层：fetchDebugFailure / fetch / cover ────────────
  ctx.fetchDebugFailureSupport = RuleParserEngineFetchDebugFailureSupport(ctx);
  ctx.fetchSupport = RuleParserEngineFetchSupport(ctx);
  ctx.coverSupport = RuleParserEngineCoverSupport(ctx);

  // ── 书籍层：bookDetail / bookInfo / bookList /
  //           toc / tocDebug / content ────────────────────
  ctx.bookDetailSupport = RuleParserEngineBookDetailSupport(ctx);
  ctx.bookInfoSupport = RuleParserEngineBookInfoSupport(ctx);
  ctx.bookListSupport = RuleParserEngineBookListSupport(ctx);
  ctx.tocSupport = RuleParserEngineTocSupport(ctx);
  ctx.tocDebugSupport = RuleParserEngineTocDebugSupport(ctx);
  ctx.contentSupport = RuleParserEngineContentSupport(ctx);

  // ── 流程层：discovery / read ─────────────────────────────
  ctx.discoveryWorkflowSupport = RuleParserEngineDiscoveryWorkflowSupport(ctx);
  ctx.readWorkflowSupport = RuleParserEngineReadWorkflowSupport(ctx);

  // ── 调试层：debugContent / debugTocWorkflow /
  //           debugBook / debugRun ──────────────────────────
  ctx.debugContentSupport = RuleParserEngineDebugContentSupport(ctx);
  ctx.debugTocWorkflowSupport = RuleParserEngineDebugTocWorkflowSupport(ctx);
  ctx.debugBookSupport = RuleParserEngineDebugBookSupport(ctx);
  ctx.debugRunSupport = RuleParserEngineDebugRunSupport(ctx);
}
