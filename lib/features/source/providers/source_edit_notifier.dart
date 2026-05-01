import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/cookie_store.dart';
import 'package:soupreader/core/services/source_login_store.dart';
import 'package:soupreader/core/services/source_variable_store.dart';
import 'package:soupreader/core/utils/legado_json.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';
import 'package:soupreader/features/source/services/source/cookie_scope_resolver.dart';
import 'package:soupreader/features/source/services/source_debug/key_parser.dart';
import 'package:soupreader/features/source/services/source_debug/orchestrator.dart';
import 'package:soupreader/features/source/services/source_debug/summary_parser.dart';
import 'package:soupreader/features/source/services/source_debug/summary_store.dart';
import 'package:soupreader/features/source/services/source/explore_kinds_service.dart';
import 'package:soupreader/features/source/services/source/legacy_save_service.dart';
import 'package:soupreader/features/source/services/source_rule/rule_lint_service.dart';
import 'package:soupreader/features/source/providers/source_edit_state.dart';

export 'package:soupreader/features/source/providers/source_edit_state.dart';

final sourceEditProvider =
    NotifierProvider.family<SourceEditNotifier, SourceEditState, SourceEditArgs>(
  SourceEditNotifier.new,
);

// ── Notifier ────────────────────────────────────────────────────
class SourceEditNotifier extends Notifier<SourceEditState> {
  SourceEditNotifier(this.arg);
  final SourceEditArgs arg;

  late final SourceLegacySaveService _saveService;
  late final SourceDebugOrchestrator _debugOrchestrator;
  final SourceExploreKindsService _exploreKindsService = SourceExploreKindsService();
  final SourceRuleLintService _ruleLintService = const SourceRuleLintService();

  @override
  SourceEditState build() {
    final db = DatabaseService();
    final repo = SourceRepository(db);
    final currentOriginalUrl = (arg.originalUrl ?? '').trim().isEmpty
        ? null
        : arg.originalUrl!.trim();
    final rawJson = _prettyJson(arg.initialRawJson ?? '{}');
    final initialMap = _tryDecodeJsonMap(rawJson);
    final source = initialMap != null
        ? BookSource.fromJson(initialMap)
        : const BookSource(bookSourceUrl: '', bookSourceName: '');
    _saveService = SourceLegacySaveService(
      upsertSourceRawJson: ({String? originalUrl, required String rawJson}) =>
          repo.upsertSourceRawJson(originalUrl: originalUrl, rawJson: rawJson),
      clearExploreKindsCache: _exploreKindsService.clearExploreKindsCache,
      clearJsLibScope: (_) {},
      removeSourceVariable: SourceVariableStore.removeVariable,
    );
    _debugOrchestrator = SourceDebugOrchestrator();
    return SourceEditState(
      source: source,
      savedSource: source.bookSourceUrl.isEmpty ? null : source,
      currentOriginalUrl: currentOriginalUrl,
      rawJson: rawJson,
    );
  }

  // ── JSON helpers ─────────────────────────────────────────────
  static Map<String, dynamic>? _tryDecodeJsonMap(String text) {
    try {
      final decoded = jsonDecode(text.trim());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) { return null; }
  }

  static String _prettyJson(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) { return raw; }
  }

  // ── BookSource update ────────────────────────────────────────
  void updateSource(BookSource Function(BookSource) updater) {
    final updated = updater(state.source);
    final rawJson = _prettyJson(LegadoJson.encode(updated.toJson()));
    state = state.copyWith(source: updated, rawJson: rawJson, jsonError: null);
  }

  void updateRawJson(String rawJson) {
    state = state.copyWith(rawJson: rawJson);
    final map = _tryDecodeJsonMap(rawJson);
    if (map != null) {
      state = state.copyWith(source: BookSource.fromJson(map), jsonError: null);
    } else {
      state = state.copyWith(jsonError: 'JSON 格式错误');
    }
  }

  String? validateJson() {
    try {
      final text = state.rawJson.trim();
      if (text.isEmpty) { state = state.copyWith(jsonError: 'JSON 不能为空'); return state.jsonError; }
      final decoded = jsonDecode(text);
      if (decoded is! Map) { state = state.copyWith(jsonError: 'JSON 必须是对象'); return state.jsonError; }
      state = state.copyWith(jsonError: null);
      return null;
    } catch (e) {
      state = state.copyWith(jsonError: 'JSON 格式错误：$e');
      return state.jsonError;
    }
  }

  // ── Save ────────────────────────────────────────────────────
  Future<String?> save() async {
    final error = validateJson();
    if (error != null) return error;
    try {
      final saved = await _saveService.save(
        source: state.source,
        originalSource: state.savedSource,
      );
      final rawJson = _prettyJson(LegadoJson.encode(saved.toJson()));
      state = state.copyWith(
        savedSource: saved,
        currentOriginalUrl: saved.bookSourceUrl,
        source: saved,
        rawJson: rawJson,
        jsonError: null,
      );
      await saveLoginState();
      return null;
    } catch (e) {
      return '保存失败：$e';
    }
  }

  // ── Login state ──────────────────────────────────────────────
  Future<void> loadLoginState() async {
    final key = state.source.bookSourceUrl.trim();
    if (key.isEmpty) {
      state = state.copyWith(loginHeaderCache: '', loginInfo: '');
      return;
    }
    state = state.copyWith(loginStateLoading: true);
    final headerMap = await SourceLoginStore.getLoginHeaderMap(key);
    final loginInfo = await SourceLoginStore.getLoginInfo(key);
    state = state.copyWith(
      loginStateLoading: false,
      loginHeaderCache: headerMap == null || headerMap.isEmpty
          ? '' : _prettyJson(jsonEncode(headerMap)),
      loginInfo: loginInfo ?? '',
    );
  }

  Future<void> saveLoginState() async {
    final key = state.source.bookSourceUrl.trim();
    if (key.isEmpty) return;
    if (state.loginHeaderCache.trim().isEmpty) {
      await SourceLoginStore.removeLoginHeader(key);
    } else {
      await SourceLoginStore.putLoginHeaderJson(key, state.loginHeaderCache.trim());
    }
    if (state.loginInfo.trim().isEmpty) {
      await SourceLoginStore.removeLoginInfo(key);
    } else {
      await SourceLoginStore.putLoginInfo(key, state.loginInfo.trim());
    }
  }

  void updateLoginHeaderCache(String v) => state = state.copyWith(loginHeaderCache: v);
  void updateLoginInfo(String v) => state = state.copyWith(loginInfo: v);

  Future<void> clearLoginState() async {
    final key = state.source.bookSourceUrl.trim();
    if (key.isEmpty) return;
    await SourceLoginStore.removeLoginHeader(key);
    await SourceLoginStore.removeLoginInfo(key);
    state = state.copyWith(loginHeaderCache: '', loginInfo: '');
  }

  Future<void> clearCookie() async {
    final url = state.source.bookSourceUrl.trim();
    if (url.isEmpty) return;
    final candidates = SourceCookieScopeResolver.resolveClearCandidates(url);
    for (final c in candidates) {
      await CookieStore.jar.delete(c);
    }
  }

  // ── Rule lint ────────────────────────────────────────────────
  Future<String> runRuleLint() async {
    final map = state.source.toJson();
    final report = _ruleLintService.lintFromJson(map);
    final lines = [
      '规则体检报告',
      '错误：${report.errorCount}',
      '警告：${report.warningCount}',
      '建议：${report.infoCount}',
      '',
      if (!report.hasIssues) '✅ 未发现问题',
      ...report.issues.where((e) => e.level.name == 'error').map((e) => '❌ [ERROR] ${e.field}: ${e.message}'),
      ...report.issues.where((e) => e.level.name == 'warning').map((e) => '⚠️ [WARN] ${e.field}: ${e.message}'),
      ...report.issues.where((e) => e.level.name == 'info').map((e) => 'ℹ️ [INFO] ${e.field}: ${e.message}'),
    ];
    return lines.join('\n');
  }

  // ── Explore quick actions ────────────────────────────────────
  Future<void> refreshExploreQuickActions() async {
    state = state.copyWith(refreshingExploreQuickActions: true);
    try {
      final kinds = await _exploreKindsService.exploreKinds(
        state.source,
      );
      final entries = kinds
          .map((k) => MapEntry(k.url ?? '', k.title))
          .toList();
      state = state.copyWith(
        cachedExploreQuickEntries: entries,
        refreshingExploreQuickActions: false,
      );
    } catch (_) {
      state = state.copyWith(refreshingExploreQuickActions: false);
    }
  }

  // ── Debug ────────────────────────────────────────────────────
  void updateDebugKey(String key) => state = state.copyWith(debugKey: key);
  void toggleDebugAutoFollow() =>
      state = state.copyWith(debugAutoFollowLogs: !state.debugAutoFollowLogs);
  void setShowDebugQuickHelp(bool v) =>
      state = state.copyWith(showDebugQuickHelp: v);
  void stopDebug() {} // SourceDebugOrchestrator does not expose cancel
  void clearDebugConsole() => state = state.copyWith(
    debugLines: const [], debugLinesAll: const [],
    debugError: null, debugListSrcHtml: null, debugBookSrcHtml: null,
    debugTocSrcHtml: null, debugContentSrcHtml: null, debugContentResult: null,
    debugMethodDecision: null, debugRetryDecision: null,
    debugRequestCharsetDecision: null, debugBodyDecision: null,
    debugResponseCharset: null, debugResponseCharsetDecision: null,
    debugRuntimeVarsSnapshot: const {}, previewChapterName: null, previewChapterUrl: null,
  );

  Future<void> startDebug() async {
    final source = state.source;
    if (source.bookSourceUrl.trim().isEmpty) {
      state = state.copyWith(debugError: 'bookSourceUrl 不能为空');
      return;
    }
    var key = state.debugKey.trim();
    if (key.isEmpty) {
      key = (source.searchUrl ?? '').trim().isNotEmpty ? '斗罗大陆' : '';
      state = state.copyWith(debugKey: key);
    }
    final parsed = _debugOrchestrator.parseKey(key);
    final intent = parsed.intent;
    if (intent == null) {
      state = state.copyWith(debugError: parsed.error ?? '请输入有效 key');
      return;
    }
    clearDebugConsole();
    state = state.copyWith(debugLoading: true, debugIntentType: intent.type);
    final result = await _debugOrchestrator.run(
      source: source, key: key,
      onEvent: _onDebugEvent,
    );
    _publishDebugSummary(source: source, intent: intent, runResult: result);
    state = state.copyWith(debugLoading: false);
  }

  void _onDebugEvent(SourceDebugEvent event) {
    if (event.isRaw) {
      switch (event.state) {
        case 10: state = state.copyWith(debugListSrcHtml: event.message); break;
        case 20: state = state.copyWith(debugBookSrcHtml: event.message); break;
        case 30: state = state.copyWith(debugTocSrcHtml: event.message); break;
        case 40: state = state.copyWith(debugContentSrcHtml: event.message); break;
        case 41: state = state.copyWith(debugContentResult: event.message); break;
      }
      return;
    }
    final line = DebugLine(state: event.state, text: event.message);
    _updateDecisionsFromEvent(event.message);
    final allLines = [...state.debugLinesAll, line];
    var uiLines = [...state.debugLines, line];
    const maxUiLines = 600;
    if (uiLines.length > maxUiLines) {
      uiLines = uiLines.sublist(uiLines.length - maxUiLines);
    }
    state = state.copyWith(debugLines: uiLines, debugLinesAll: allLines);
    if (event.state == -1) state = state.copyWith(debugError: event.message);
  }

  void _updateDecisionsFromEvent(String message) {
    final plain = _stripTimePrefix(message).trimLeft();
    String v(String p) => plain.substring(p.length).trim();
    if (plain.startsWith('└请求决策：')) { state = state.copyWith(debugMethodDecision: v('└请求决策：')); return; }
    if (plain.startsWith('└重试决策：')) { state = state.copyWith(debugRetryDecision: v('└重试决策：')); return; }
    if (plain.startsWith('└请求编码：')) { state = state.copyWith(debugRequestCharsetDecision: v('└请求编码：')); return; }
    if (plain.startsWith('└请求体决策：')) { state = state.copyWith(debugBodyDecision: v('└请求体决策：')); return; }
    if (plain.startsWith('└响应编码：')) { state = state.copyWith(debugResponseCharset: v('└响应编码：')); return; }
    if (plain.startsWith('└响应解码决策：')) { state = state.copyWith(debugResponseCharsetDecision: v('└响应解码决策：')); return; }
    _updatePreviewFromEvent(plain);
  }

  void _updatePreviewFromEvent(String plain) {
    if (!plain.startsWith('└')) return;
    final value = plain.substring(1).trim();
    if (state.debugAwaitingChapterNameValue) {
      state = state.copyWith(previewChapterName: value, debugAwaitingChapterNameValue: false);
    } else if (state.debugAwaitingChapterUrlValue) {
      state = state.copyWith(previewChapterUrl: value, debugAwaitingChapterUrlValue: false);
    }
  }

  static String _stripTimePrefix(String text) {
    final t = text.trimLeft();
    if (!t.startsWith('[')) return t;
    final idx = t.indexOf('] ');
    return idx < 0 ? t : t.substring(idx + 2);
  }

  void _publishDebugSummary({
    required BookSource source,
    required SourceDebugIntent intent,
    required SourceDebugRunResult? runResult,
  }) {
    final logLines = state.debugLinesAll.map((l) => l.text).toList();
    final errorLines = state.debugLinesAll
        .where((l) => l.state == -1).map((l) => l.text).toList();
    final summary = SourceDebugSummaryParser.build(
      logLines: logLines,
      debugError: state.debugError,
      errorLines: errorLines,
    );
    final diagnosisRaw = summary['diagnosis'];
    final diagnosis = diagnosisRaw is Map
        ? diagnosisRaw.map((k, v) => MapEntry('$k', v))
        : const <String, dynamic>{};
    final primary = (diagnosis['primary'] ?? 'no_data').toString();
    final labels = (diagnosis['labels'] is List)
        ? (diagnosis['labels'] as List).map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];
    final hints = (diagnosis['hints'] is List)
        ? (diagnosis['hints'] as List).map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty).toList()
        : const <String>[];
    final success = runResult?.success ??
        (state.debugError == null &&
         !labels.contains('request_failure') &&
         !labels.contains('parse_failure'));
    SourceDebugSummaryStore.instance.push(SourceDebugSummary(
      finishedAt: DateTime.now(),
      sourceUrl: source.bookSourceUrl,
      sourceName: source.bookSourceName,
      key: state.debugKey,
      intentType: intent.type,
      success: success,
      debugError: state.debugError,
      primaryDiagnosis: primary,
      diagnosisLabels: labels,
      diagnosisHints: hints,
    ));
  }
}
