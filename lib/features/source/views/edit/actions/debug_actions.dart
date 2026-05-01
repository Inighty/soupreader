import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/app/widgets/app_action_list_sheet.dart';
import 'package:soupreader/app/widgets/app_toast.dart';
import 'package:soupreader/core/services/qr_scan_service.dart';
import 'package:soupreader/features/source/constants/source_help_texts.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/services/source/quick_test_helper.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_bundle.dart';
import 'package:soupreader/features/source/views/verify/web_verify_view.dart';

enum _DebugMenuAction {
  scanKeyFromQr,
  openListSource,
  openBookSource,
  openTocSource,
  openContentSource,
  refreshExploreEntries,
  openHelp,
}

enum _DebugToolsAction {
  openWebVerify,
  openStructuredSummary,
  copyStructuredSummary,
  openRuntimeSnapshot,
  copyRuntimeSnapshot,
  copyConsole,
  copyMinimalRepro,
  clearConsole,
}

class SourceEditDebugActions extends SourceEditViewActions {
  SourceEditDebugActions({
    required super.context,
    required super.ref,
    required super.args,
    required super.setTab,
  });

  Future<void> startDebug() => notifier.startDebug();

  Future<void> showLegacyMenuSheet() async {
    final selected = await showAppActionListSheet<_DebugMenuAction>(
      context: context,
      title: '菜单',
      showCancel: true,
      items: const [
        AppActionListItem<_DebugMenuAction>(
          value: _DebugMenuAction.scanKeyFromQr,
          icon: CupertinoIcons.qrcode_viewfinder,
          label: '扫码填充 Key',
        ),
        AppActionListItem<_DebugMenuAction>(
          value: _DebugMenuAction.openListSource,
          icon: CupertinoIcons.search,
          label: '查看列表源码',
        ),
        AppActionListItem<_DebugMenuAction>(
          value: _DebugMenuAction.openBookSource,
          icon: CupertinoIcons.book,
          label: '查看详情源码',
        ),
        AppActionListItem<_DebugMenuAction>(
          value: _DebugMenuAction.openTocSource,
          icon: CupertinoIcons.list_bullet,
          label: '查看目录源码',
        ),
        AppActionListItem<_DebugMenuAction>(
          value: _DebugMenuAction.openContentSource,
          icon: CupertinoIcons.doc_text,
          label: '查看正文源码',
        ),
        AppActionListItem<_DebugMenuAction>(
          value: _DebugMenuAction.refreshExploreEntries,
          icon: CupertinoIcons.refresh,
          label: '刷新发现快捷项',
        ),
        AppActionListItem<_DebugMenuAction>(
          value: _DebugMenuAction.openHelp,
          icon: CupertinoIcons.question_circle,
          label: '调试帮助',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _DebugMenuAction.scanKeyFromQr:
        await scanDebugKeyFromQr();
        return;
      case _DebugMenuAction.openListSource:
        _openDebugSource('列表页源码', state.debugListSrcHtml);
        return;
      case _DebugMenuAction.openBookSource:
        _openDebugSource('详情页源码', state.debugBookSrcHtml);
        return;
      case _DebugMenuAction.openTocSource:
        _openDebugSource('目录页源码', state.debugTocSrcHtml);
        return;
      case _DebugMenuAction.openContentSource:
        _openDebugSource('正文页源码', state.debugContentSrcHtml);
        return;
      case _DebugMenuAction.refreshExploreEntries:
        await refreshExploreQuickEntries();
        return;
      case _DebugMenuAction.openHelp:
        await openDebugText(title: '调试帮助', text: SourceHelpTexts.debug);
        return;
    }
  }

  Future<void> showMoreToolsSheet() async {
    final selected = await showAppActionListSheet<_DebugToolsAction>(
      context: context,
      title: '高级工具',
      showCancel: true,
      items: const [
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.openWebVerify,
          icon: CupertinoIcons.cloud,
          label: '网页验证',
        ),
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.openStructuredSummary,
          icon: CupertinoIcons.doc_text_search,
          label: '结构化调试摘要',
        ),
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.copyStructuredSummary,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制调试摘要',
        ),
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.openRuntimeSnapshot,
          icon: CupertinoIcons.clock,
          label: '变量快照',
        ),
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.copyRuntimeSnapshot,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '复制变量快照',
        ),
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.copyConsole,
          icon: CupertinoIcons.text_bubble,
          label: '复制控制台',
        ),
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.copyMinimalRepro,
          icon: CupertinoIcons.info_circle,
          label: '复制最小复现信息',
        ),
        AppActionListItem<_DebugToolsAction>(
          value: _DebugToolsAction.clearConsole,
          icon: CupertinoIcons.delete,
          label: '清空控制台',
          isDestructiveAction: true,
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _DebugToolsAction.openWebVerify:
        openWebVerify();
        return;
      case _DebugToolsAction.openStructuredSummary:
        final text = SourceEditDebugHelper.structuredSummaryText(state);
        if (text == null) {
          showMessage('暂无调试摘要，请先执行调试');
          return;
        }
        await openDebugText(title: '结构化调试摘要', text: text);
        return;
      case _DebugToolsAction.copyStructuredSummary:
        final text = SourceEditDebugHelper.structuredSummaryText(state);
        if (text == null) {
          showMessage('暂无调试摘要，请先执行调试');
          return;
        }
        await Clipboard.setData(ClipboardData(text: text));
        await showAppToast(context, message: '已复制调试摘要');
        return;
      case _DebugToolsAction.openRuntimeSnapshot:
        final text = SourceEditDebugHelper.runtimeSnapshotText(state);
        if (text == null) {
          showMessage('暂无变量快照');
          return;
        }
        await openDebugText(title: '运行时变量快照', text: text);
        return;
      case _DebugToolsAction.copyRuntimeSnapshot:
        final text = SourceEditDebugHelper.runtimeSnapshotText(state);
        if (text == null) {
          showMessage('暂无变量快照');
          return;
        }
        await Clipboard.setData(ClipboardData(text: text));
        await showAppToast(context, message: '已复制变量快照');
        return;
      case _DebugToolsAction.copyConsole:
        await copyDebugConsole();
        return;
      case _DebugToolsAction.copyMinimalRepro:
        await copyMinimalReproInfo();
        return;
      case _DebugToolsAction.clearConsole:
        notifier.clearDebugConsole();
        return;
    }
  }

  Future<void> scanDebugKeyFromQr() async {
    final text = await QrScanService.scanText(
      context,
      title: '扫码填充调试 Key',
    );
    final value = text?.trim();
    if (value == null || value.isEmpty) return;
    notifier.updateDebugKey(value);
  }

  Future<void> refreshExploreQuickEntries() async {
    await notifier.refreshExploreQuickActions();
    final total = collectExploreQuickEntries().length;
    if (total == 0) {
      showMessage('当前未解析到发现快捷项，请检查 exploreUrl/exploreScreen');
      return;
    }
    await showAppToast(context, message: '已刷新发现快捷项（$total 项）');
  }

  List<MapEntry<String, String>> collectExploreQuickEntries() {
    final entries = <MapEntry<String, String>>[
      ...state.cachedExploreQuickEntries,
      ...SourceEditDebugHelper.parseExploreEntries(source: state.source),
    ];
    final seen = <String>{};
    return entries.where((entry) => seen.add(entry.key)).toList();
  }

  Future<void> showExploreQuickPicker() async {
    final entries = collectExploreQuickEntries();
    if (entries.isEmpty) {
      showMessage('暂无发现快捷项');
      return;
    }
    final selected = await showAppActionListSheet<int>(
      context: context,
      title: '选择发现入口',
      showCancel: true,
      items: [
        for (var i = 0; i < entries.length; i++)
          AppActionListItem<int>(
            value: i,
            icon: CupertinoIcons.compass,
            label: entries[i].value,
          ),
      ],
    );
    if (selected == null || selected < 0 || selected >= entries.length) return;
    notifier.updateDebugKey(entries[selected].key);
    await startDebug();
  }

  void setDebugKey(String key) {
    notifier.updateDebugKey(key);
  }

  Future<void> runQuickSearchRuleTest() async {
    if (state.debugLoading) {
      showMessage('调试运行中，请稍后再试');
      return;
    }
    setTab(3);
    notifier.updateDebugKey(
      SourceQuickTestHelper.buildSearchKey(
        checkKeyword: state.source.ruleSearch?.checkKeyWord ?? '',
      ),
    );
    await startDebug();
  }

  Future<void> runQuickContentRuleTest() async {
    if (state.debugLoading) {
      showMessage('调试运行中，请稍后再试');
      return;
    }
    final key = SourceQuickTestHelper.buildContentKey(
      previewChapterUrl: state.previewChapterUrl,
    );
    if (key == null) {
      showMessage('请先调试搜索/目录拿到 chapterUrl，再测试正文规则');
      return;
    }
    setTab(3);
    notifier.updateDebugKey(key);
    await startDebug();
  }

  Future<void> prefixKeyAndRun(String prefix) async {
    final current = state.debugKey.trim();
    final next = current.startsWith(prefix) ? current : '$prefix$current';
    notifier.updateDebugKey(next);
    if (!state.debugLoading) {
      await startDebug();
    }
  }

  Future<void> runCurrentKey() async {
    if (state.debugKey.trim().isEmpty) {
      showMessage('请先输入调试 key');
      return;
    }
    if (!state.debugLoading) {
      await startDebug();
    }
  }

  void openWebVerify() {
    final source = state.source;
    if (source.bookSourceUrl.trim().isEmpty) {
      showMessage('bookSourceUrl 不能为空');
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(
          initialUrl: SourceEditDebugHelper.resolveWebVerifyUrl(
            source,
            state.debugKey,
          ),
          sourceOrigin: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        ),
      ),
    );
  }

  Future<void> copyDebugConsole() async {
    if (state.debugLinesAll.isEmpty) {
      showMessage('暂无日志可复制');
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: state.debugLinesAll.map((line) => line.text).join('\n')),
    );
    await showAppToast(context, message: '已复制全部日志');
  }

  Future<void> copyMinimalReproInfo() async {
    await Clipboard.setData(
      ClipboardData(text: SourceEditDebugHelper.buildMinimalReproText(state)),
    );
    await showAppToast(context, message: '已复制最小复现信息');
  }

  Map<String, dynamic> buildStructuredDebugSummary() {
    return SourceEditDebugHelper.buildStructuredDebugSummary(state);
  }

  String? structuredSummaryText() {
    return SourceEditDebugHelper.structuredSummaryText(state);
  }

  String? runtimeSnapshotText() {
    return SourceEditDebugHelper.runtimeSnapshotText(state);
  }

  List<String> diagnosisLabels() {
    return SourceEditDebugHelper.diagnosisLabels(
      buildStructuredDebugSummary(),
    );
  }

  List<String> diagnosisHints() {
    return SourceEditDebugHelper.diagnosisHints(
      buildStructuredDebugSummary(),
    );
  }

  Color labelColor(String code) {
    return SourceEditDebugHelper.labelColor(context, code);
  }

  String labelText(String code) {
    return SourceEditDebugHelper.labelText(code);
  }

  void _openDebugSource(String title, String? content) {
    final text = content?.trim();
    if (text == null || text.isEmpty) {
      showMessage('$title 暂无内容，请先执行调试');
      return;
    }
    unawaited(openDebugText(title: title, text: text));
  }
}
