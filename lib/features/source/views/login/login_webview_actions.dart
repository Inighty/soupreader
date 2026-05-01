import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:soupreader/app/widgets/app_action_list_sheet.dart';
import 'package:soupreader/app/widgets/app_toast.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/core/services/webview_cookie_bridge.dart';

enum SourceLoginWebviewAction {
  openInBrowser,
  copyUrl,
  reload,
  clearCookie,
}

class SourceLoginWebViewActions {
  const SourceLoginWebViewActions({
    required this.context,
    required this.exceptionLogService,
    required this.sourceKey,
    required this.initialUrl,
    required this.currentUrl,
    required this.reloadOrStop,
  });

  final BuildContext context;
  final ExceptionLogService exceptionLogService;
  final String sourceKey;
  final String initialUrl;
  final String currentUrl;
  final Future<void> Function() reloadOrStop;

  Future<void> showMoreMenu() async {
    if (!context.mounted) return;
    final menuUrl = currentUrl.isEmpty ? initialUrl : currentUrl;
    final action = await showAppActionListSheet<SourceLoginWebviewAction>(
      context: context,
      title: '操作',
      message: menuUrl,
      showCancel: true,
      items: const [
        AppActionListItem<SourceLoginWebviewAction>(
          value: SourceLoginWebviewAction.openInBrowser,
          icon: CupertinoIcons.globe,
          label: '浏览器打开',
        ),
        AppActionListItem<SourceLoginWebviewAction>(
          value: SourceLoginWebviewAction.copyUrl,
          icon: CupertinoIcons.doc_on_doc,
          label: '拷贝 URL',
        ),
        AppActionListItem<SourceLoginWebviewAction>(
          value: SourceLoginWebviewAction.reload,
          icon: CupertinoIcons.refresh,
          label: '刷新',
        ),
        AppActionListItem<SourceLoginWebviewAction>(
          value: SourceLoginWebviewAction.clearCookie,
          icon: CupertinoIcons.delete,
          label: '清空 WebView Cookie',
          isDestructiveAction: true,
        ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case SourceLoginWebviewAction.openInBrowser:
        await openInBrowser();
        return;
      case SourceLoginWebviewAction.copyUrl:
        await copyUrl();
        return;
      case SourceLoginWebviewAction.reload:
        await reloadOrStop();
        return;
      case SourceLoginWebviewAction.clearCookie:
        final ok = await WebViewCookieBridge.clearAllCookies();
        await _showMessage(ok ? '已清空 Cookie' : '清空失败或不支持');
        return;
    }
  }

  Future<void> openInBrowser() async {
    final raw = currentUrl.trim().isNotEmpty ? currentUrl.trim() : initialUrl;
    final uri = Uri.tryParse(raw);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
      exceptionLogService.record(
        node: 'source.webview_login.menu_open_in_browser',
        message: '浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'sourceKey': sourceKey,
          'target': raw,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
      await _showMessage('打开失败');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
      exceptionLogService.record(
        node: 'source.webview_login.menu_open_in_browser',
        message: '浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'sourceKey': sourceKey,
          'target': raw,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
      await _showMessage('打开失败');
    } catch (error, stackTrace) {
      exceptionLogService.record(
        node: 'source.webview_login.menu_open_in_browser',
        message: '浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceKey,
          'target': raw,
          'initialUrl': initialUrl,
          'currentUrl': currentUrl,
        },
      );
      await _showMessage('打开失败');
    }
  }

  Future<void> copyUrl() async {
    final url = currentUrl.trim().isNotEmpty ? currentUrl.trim() : initialUrl;
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    unawaited(showAppToast(context, message: '已复制 URL'));
  }

  Future<bool> confirmOpenExternalApp(Uri uri) async {
    if (!context.mounted) return false;
    final result = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('跳转其它应用'),
        content: Text('\n${uri.toString()}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}
