import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:soupreader/app/widgets/app_action_list_sheet.dart';
import 'package:soupreader/app/widgets/app_toast.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/core/services/source_variable_store.dart';
import 'package:soupreader/core/services/webview_cookie_bridge.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';

enum SourceWebVerifyMenuAction {
  openInBrowser,
  copyUrl,
  fullScreen,
  disableSource,
  deleteSource,
  reload,
  importCookies,
  copyCookieHeader,
  clearCookie,
}

class SourceWebVerifyCookieImportResult {
  const SourceWebVerifyCookieImportResult({
    required this.hint,
    required this.cookieHeaderValue,
  });

  final String hint;
  final String cookieHeaderValue;
}

class SourceWebVerifyActions {
  const SourceWebVerifyActions({
    required this.context,
    required this.controller,
    required this.sourceRepo,
    required this.exceptionLogService,
    required this.initialUrl,
    required this.currentUrl,
    required this.sourceOrigin,
    required this.sourceName,
    required this.lastImportCookieHeaderValue,
    required this.toggleFullScreen,
    required this.closePage,
    required this.onCookiesImported,
  });

  final BuildContext context;
  final WebViewController controller;
  final SourceRepository sourceRepo;
  final ExceptionLogService exceptionLogService;
  final String initialUrl;
  final String currentUrl;
  final String sourceOrigin;
  final String sourceName;
  final String? lastImportCookieHeaderValue;
  final Future<void> Function() toggleFullScreen;
  final VoidCallback closePage;
  final ValueChanged<SourceWebVerifyCookieImportResult> onCookiesImported;

  Future<void> showMoreMenu() async {
    if (!context.mounted) return;
    final hasSource = sourceOrigin.trim().isNotEmpty;
    final menuUrl = currentUrl.isEmpty ? initialUrl : currentUrl;
    final action = await showAppActionListSheet<SourceWebVerifyMenuAction>(
      context: context,
      title: '操作',
      message: menuUrl,
      showCancel: true,
      items: <AppActionListItem<SourceWebVerifyMenuAction>>[
        const AppActionListItem<SourceWebVerifyMenuAction>(
          value: SourceWebVerifyMenuAction.openInBrowser,
          icon: CupertinoIcons.globe,
          label: '浏览器打开',
        ),
        const AppActionListItem<SourceWebVerifyMenuAction>(
          value: SourceWebVerifyMenuAction.copyUrl,
          icon: CupertinoIcons.doc_on_doc,
          label: '拷贝 URL',
        ),
        const AppActionListItem<SourceWebVerifyMenuAction>(
          value: SourceWebVerifyMenuAction.fullScreen,
          icon: CupertinoIcons.fullscreen,
          label: '全屏',
        ),
        if (hasSource)
          const AppActionListItem<SourceWebVerifyMenuAction>(
            value: SourceWebVerifyMenuAction.disableSource,
            icon: CupertinoIcons.pause_circle,
            label: '禁用源',
            isDestructiveAction: true,
          ),
        if (hasSource)
          const AppActionListItem<SourceWebVerifyMenuAction>(
            value: SourceWebVerifyMenuAction.deleteSource,
            icon: CupertinoIcons.delete,
            label: '删除源',
            isDestructiveAction: true,
          ),
        const AppActionListItem<SourceWebVerifyMenuAction>(
          value: SourceWebVerifyMenuAction.reload,
          icon: CupertinoIcons.refresh,
          label: '刷新',
        ),
        const AppActionListItem<SourceWebVerifyMenuAction>(
          value: SourceWebVerifyMenuAction.importCookies,
          icon: CupertinoIcons.square_arrow_down,
          label: '导入 Cookie 到解析引擎',
        ),
        const AppActionListItem<SourceWebVerifyMenuAction>(
          value: SourceWebVerifyMenuAction.copyCookieHeader,
          icon: CupertinoIcons.doc_text,
          label: '复制 Cookie 值',
        ),
        const AppActionListItem<SourceWebVerifyMenuAction>(
          value: SourceWebVerifyMenuAction.clearCookie,
          icon: CupertinoIcons.delete_solid,
          label: '清空 WebView Cookie',
          isDestructiveAction: true,
        ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case SourceWebVerifyMenuAction.openInBrowser:
        await _openInBrowser();
        return;
      case SourceWebVerifyMenuAction.copyUrl:
        await _copyBaseUrl();
        return;
      case SourceWebVerifyMenuAction.fullScreen:
        await toggleFullScreen();
        return;
      case SourceWebVerifyMenuAction.disableSource:
        await _disableCurrentSource();
        return;
      case SourceWebVerifyMenuAction.deleteSource:
        await _confirmDeleteCurrentSource();
        return;
      case SourceWebVerifyMenuAction.reload:
        await controller.reload();
        return;
      case SourceWebVerifyMenuAction.importCookies:
        await _importCookies();
        return;
      case SourceWebVerifyMenuAction.copyCookieHeader:
        await _copyCookieHeader();
        return;
      case SourceWebVerifyMenuAction.clearCookie:
        final ok = await WebViewCookieBridge.clearAllCookies();
        await _showMessage(ok ? '已清空 Cookie' : '清空失败或不支持');
        return;
    }
  }

  Future<void> _showMessage(String message) async {
    if (!context.mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _importCookies() async {
    if (!WebViewCookieBridge.isSupported) {
      await _showMessage('当前平台不支持从 WebView 导入 Cookie');
      return;
    }

    Uri? uri;
    try {
      uri = Uri.parse(currentUrl.isNotEmpty ? currentUrl : initialUrl);
    } catch (_) {
      uri = null;
    }
    if (uri == null || uri.host.trim().isEmpty) {
      await _showMessage('URL 无效，无法解析域名');
      return;
    }

    final domain = uri.host;
    final cookies = await WebViewCookieBridge.getCookiesForDomain(
      domain,
      includeSubdomains: true,
    );
    if (cookies.isEmpty) {
      await _showMessage('未读取到 Cookie（可能尚未通过验证）');
      return;
    }

    await RuleParserEngine.saveCookiesForUrl(uri.toString(), cookies);

    final cookieHeader = WebViewCookieBridge.toCookieHeaderValue(cookies);
    final names = cookies.map((cookie) => cookie.name).toSet().toList()..sort();
    final keyOnes = names
        .where((name) => name.toLowerCase().contains('cf') || name.contains('clearance'))
        .toList(growable: false);
    final hint = [
      '已导入 Cookie：${cookies.length} 个（${names.length} 种）',
      if (keyOnes.isNotEmpty) '关键：${keyOnes.join(', ')}',
      '域名：$domain',
    ].join('\n');

    onCookiesImported(
      SourceWebVerifyCookieImportResult(
        hint: hint,
        cookieHeaderValue: cookieHeader,
      ),
    );
    await _showMessage(hint);
  }

  Future<void> _copyCookieHeader() async {
    final value = lastImportCookieHeaderValue;
    if (value == null || value.trim().isEmpty) {
      await _showMessage('尚未导入 Cookie');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    unawaited(
      showAppToast(
        context,
        message: '已复制 Cookie 值（可用于书源 header 的 Cookie 字段）',
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final initial = initialUrl.trim();
    final current = currentUrl.trim();
    final target = initial.isNotEmpty ? initial : current;
    final uri = Uri.tryParse(target);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
      exceptionLogService.record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'target': target,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
      await _showMessage('open url error');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
      exceptionLogService.record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'target': target,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
      await _showMessage('open url error');
    } catch (error, stackTrace) {
      exceptionLogService.record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'target': target,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
      await _showMessage('open url error');
    }
  }

  Future<void> _copyBaseUrl() async {
    final current = currentUrl.trim();
    final initial = initialUrl.trim();
    final target = current.isNotEmpty ? current : initial;
    if (target.isEmpty) {
      await _showMessage('URL 为空');
      return;
    }
    await Clipboard.setData(ClipboardData(text: target));
    await _showMessage('复制完成');
  }

  Future<void> _disableCurrentSource() async {
    final sourceUrl = sourceOrigin.trim();
    if (sourceUrl.isEmpty) return;

    try {
      final current = sourceRepo.getSourceByUrl(sourceUrl);
      if (current != null) {
        await sourceRepo.updateSource(current.copyWith(enabled: false));
      }
      if (!context.mounted) return;
      closePage();
    } catch (error, stackTrace) {
      exceptionLogService.record(
        node: 'source.web_view.menu_disable_source',
        message: '禁用书源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceUrl,
          'sourceName': sourceName,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
    }
  }

  Future<void> _confirmDeleteCurrentSource() async {
    final sourceUrl = sourceOrigin.trim();
    if (sourceUrl.isEmpty || !context.mounted) return;
    final name = sourceName.trim();

    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n$name'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteCurrentSource();
  }

  Future<void> _deleteCurrentSource() async {
    final sourceUrl = sourceOrigin.trim();
    if (sourceUrl.isEmpty) return;

    try {
      await sourceRepo.deleteSource(sourceUrl);
      await SourceVariableStore.removeVariable(sourceUrl);
      if (!context.mounted) return;
      closePage();
    } catch (error, stackTrace) {
      exceptionLogService.record(
        node: 'source.web_view.menu_delete_source',
        message: '删除书源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceUrl,
          'sourceName': sourceName,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
    }
  }
}
