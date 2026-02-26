import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/services/webview_cookie_bridge.dart';
import '../services/rule_parser_engine.dart';

class SourceWebVerifyView extends StatefulWidget {
  final String initialUrl;
  final String sourceOrigin;
  final String sourceName;

  const SourceWebVerifyView({
    super.key,
    required this.initialUrl,
    this.sourceOrigin = '',
    this.sourceName = '',
  });

  @override
  State<SourceWebVerifyView> createState() => _SourceWebVerifyViewState();
}

class _SourceWebVerifyViewState extends State<SourceWebVerifyView> {
  late final SourceRepository _sourceRepo;
  late final ExceptionLogService _exceptionLogService;

  late final WebViewController _controller;
  int _progress = 0;
  String _currentUrl = '';
  bool _isFullScreen = false;

  String? _lastImportHint;
  String? _lastImportCookieHeaderValue;

  @override
  void initState() {
    super.initState();
    _sourceRepo = SourceRepository(DatabaseService());
    _exceptionLogService = ExceptionLogService();

    _currentUrl = widget.initialUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() => _currentUrl = url);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null) return;
            if (!mounted) return;
            setState(() => _currentUrl = url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  void dispose() {
    if (_isFullScreen) {
      unawaited(_restoreSystemUiForPage());
    }
    super.dispose();
  }

  Future<void> _setFullScreen(bool enabled) async {
    if (!mounted || _isFullScreen == enabled) return;
    setState(() => _isFullScreen = enabled);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: enabled
          ? const <SystemUiOverlay>[]
          : const <SystemUiOverlay>[
              SystemUiOverlay.top,
              SystemUiOverlay.bottom,
            ],
    );
  }

  Future<void> _toggleFullScreen() async {
    await _setFullScreen(!_isFullScreen);
  }

  Future<void> _restoreSystemUiForPage() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ],
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.of(context).pop(),
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
      uri = Uri.parse(_currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl);
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

    final names = cookies.map((c) => c.name).toSet().toList()..sort();
    final keyOnes = names
        .where((n) => n.toLowerCase().contains('cf') || n.contains('clearance'))
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _lastImportCookieHeaderValue = cookieHeader;
      _lastImportHint = [
        '已导入 Cookie：${cookies.length} 个（${names.length} 种）',
        if (keyOnes.isNotEmpty) '关键：${keyOnes.join(', ')}',
        '域名：$domain',
      ].join('\n');
    });

    await _showMessage(_lastImportHint!);
  }

  Future<void> _copyCookieHeader() async {
    final value = _lastImportCookieHeaderValue;
    if (value == null || value.trim().isEmpty) {
      await _showMessage('尚未导入 Cookie');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    await _showMessage('已复制 Cookie 值（可用于书源 header 的 Cookie 字段）');
  }

  Future<void> _openInBrowser() async {
    final initial = widget.initialUrl.trim();
    final current = _currentUrl.trim();
    final target = initial.isNotEmpty ? initial : current;
    final uri = Uri.tryParse(target);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
      ExceptionLogService().record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'target': target,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
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
      if (launched) {
        return;
      }
      ExceptionLogService().record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'target': target,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('open url error');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'target': target,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('open url error');
    }
  }

  Future<void> _copyBaseUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.initialUrl));
    await _showMessage('复制完成');
  }

  Future<void> _disableCurrentSource() async {
    final sourceUrl = widget.sourceOrigin.trim();
    if (sourceUrl.isEmpty) return;

    try {
      final current = _sourceRepo.getSourceByUrl(sourceUrl);
      if (current != null) {
        await _sourceRepo.updateSource(current.copyWith(enabled: false));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'source.web_view.menu_disable_source',
        message: '禁用书源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceUrl,
          'sourceName': widget.sourceName,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
    }
  }

  Future<void> _confirmDeleteCurrentSource() async {
    final sourceUrl = widget.sourceOrigin.trim();
    if (sourceUrl.isEmpty || !mounted) return;
    final sourceName = widget.sourceName.trim();

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n$sourceName'),
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
    final sourceUrl = widget.sourceOrigin.trim();
    if (sourceUrl.isEmpty) return;

    try {
      await _sourceRepo.deleteSource(sourceUrl);
      await SourceVariableStore.removeVariable(sourceUrl);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'source.web_view.menu_delete_source',
        message: '删除书源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceUrl,
          'sourceName': widget.sourceName,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
    }
  }

  void _confirmAndClose() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _showMoreMenu() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('操作'),
        message: Text(
          (_currentUrl.isEmpty ? widget.initialUrl : _currentUrl),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('浏览器打开'),
            onPressed: () async {
              Navigator.of(context).pop();
              await _openInBrowser();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('拷贝 URL'),
            onPressed: () async {
              Navigator.of(context).pop();
              await _copyBaseUrl();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('全屏'),
            onPressed: () async {
              Navigator.of(context).pop();
              await _toggleFullScreen();
            },
          ),
          if (widget.sourceOrigin.trim().isNotEmpty)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('禁用源'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _disableCurrentSource();
              },
            ),
          if (widget.sourceOrigin.trim().isNotEmpty)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('删除源'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmDeleteCurrentSource();
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('刷新'),
            onPressed: () {
              Navigator.of(context).pop();
              _controller.reload();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导入 Cookie 到解析引擎'),
            onPressed: () async {
              Navigator.of(context).pop();
              await _importCookies();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('复制 Cookie 值'),
            onPressed: () async {
              Navigator.of(context).pop();
              await _copyCookieHeader();
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('清空 WebView Cookie'),
            onPressed: () async {
              Navigator.of(context).pop();
              final ok = await WebViewCookieBridge.clearAllCookies();
              await _showMessage(ok ? '已清空 Cookie' : '清空失败或不支持');
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Color _accentColor(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  Widget _buildPageBody(BuildContext context, {required bool showProgress}) {
    final progress = _progress;
    return Column(
      children: [
        if (showProgress)
          SizedBox(
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress / 100.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _accentColor(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_lastImportHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              _lastImportHint!,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final showProgress = progress > 0 && progress < 100;
    return PopScope(
      canPop: !_isFullScreen,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isFullScreen) {
          await _toggleFullScreen();
          return;
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: _isFullScreen
          ? CupertinoPageScaffold(
              child: SafeArea(
                top: false,
                bottom: false,
                child: _buildPageBody(context, showProgress: showProgress),
              ),
            )
          : AppCupertinoPageScaffold(
              title: '网页验证',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(30, 30),
                    onPressed: _confirmAndClose,
                    child: const Icon(CupertinoIcons.check_mark),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(30, 30),
                    onPressed: _showMoreMenu,
                    child: const Icon(CupertinoIcons.ellipsis),
                  ),
                ],
              ),
              child: _buildPageBody(context, showProgress: showProgress),
            ),
    );
  }
}
