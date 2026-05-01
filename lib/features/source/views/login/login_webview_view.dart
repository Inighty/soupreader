import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:soupreader/app/widgets/app_cupertino_page_scaffold.dart';
import 'package:soupreader/app/widgets/app_nav_bar_button.dart';
import 'package:soupreader/app/widgets/app_webview_toolbar.dart';
import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/core/services/webview_cookie_bridge.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';
import 'package:soupreader/features/source/views/login/login_webview_actions.dart';
import 'package:soupreader/features/source/views/login/login_webview_headers.dart';
import 'package:soupreader/features/source/views/shared/webview_common.dart';

/// 对标 legado `source_webview_login/menu_ok`：
/// - 顶栏一级动作“确认”
/// - 点击后提示“正在打开首页，成功自动返回主界面”
/// - 重载首页并在页面加载完成后自动返回
/// - 页面加载期间持续同步 Cookie 到解析引擎 CookieJar
class SourceLoginWebViewView extends StatefulWidget {
  const SourceLoginWebViewView({
    super.key,
    required this.source,
    required this.initialUrl,
  });

  final BookSource source;
  final String initialUrl;

  @override
  State<SourceLoginWebViewView> createState() => _SourceLoginWebViewViewState();
}

class _SourceLoginWebViewViewState extends State<SourceLoginWebViewView> {
  static const String _checkHint = '正在打开首页，成功自动返回主界面';
  static const String _defaultUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 '
      'Safari/604.1';

  late final WebViewController _controller;
  late final Map<String, String> _headerMap;
  late final String _initialUrl;
  late final ExceptionLogService _exceptionLogService;

  bool _checking = false;
  bool _closing = false;
  int _progress = 0;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  bool _navStateRefreshErrorLogged = false;
  bool _cookieFromJsErrorLogged = false;

  SourceLoginWebViewActions get _actions => SourceLoginWebViewActions(
        context: context,
        exceptionLogService: _exceptionLogService,
        sourceKey: widget.source.bookSourceUrl,
        initialUrl: _initialUrl,
        currentUrl: _currentUrl,
        reloadOrStop: _reloadOrStop,
      );

  @override
  void initState() {
    super.initState();
    _initialUrl = widget.initialUrl.trim();
    _headerMap = SourceLoginWebViewHeaderParser.buildHeaderMap(
      widget.source.header,
      defaultUserAgent: _defaultUserAgent,
    );
    _exceptionLogService = ExceptionLogService();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            unawaited(_syncCookies(url));
            unawaited(_refreshNavState());
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            unawaited(_handlePageFinished(url));
            unawaited(_refreshNavState());
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || !mounted) return;
            setState(() => _currentUrl = url);
            unawaited(_refreshNavState());
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == 'http' || scheme == 'https') {
              return NavigationDecision.navigate;
            }
            if (uri == null) return NavigationDecision.prevent;
            final allowed = await _actions.confirmOpenExternalApp(uri);
            if (allowed) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    if (_initialUrl.isNotEmpty) {
      _currentUrl = _initialUrl;
      unawaited(_loadUrl(_initialUrl));
    }
  }

  Future<void> _refreshNavState() async {
    try {
      final canGoBack = await _controller.canGoBack();
      final canGoForward = await _controller.canGoForward();
      if (!mounted) return;
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    } catch (error, stackTrace) {
      if (_navStateRefreshErrorLogged) return;
      _navStateRefreshErrorLogged = true;
      _exceptionLogService.record(
        node: 'source.webview_login.refresh_nav_state',
        message: '刷新 WebView 导航状态失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'initialUrl': _initialUrl,
          'currentUrl': _currentUrl,
          'isLoading': _isLoading,
        },
      );
    }
  }

  Future<void> _goBack() async {
    if (!await _controller.canGoBack()) return;
    await _controller.goBack();
  }

  Future<void> _goForward() async {
    if (!await _controller.canGoForward()) return;
    await _controller.goForward();
  }

  Future<void> _reloadOrStop() async {
    if (_isLoading) {
      try {
        await _controller.runJavaScript('window.stop();');
      } catch (error, stackTrace) {
        _exceptionLogService.record(
          node: 'source.webview_login.stop_loading',
          message: '停止加载失败（window.stop）',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'sourceKey': widget.source.bookSourceUrl,
            'initialUrl': _initialUrl,
            'currentUrl': _currentUrl,
          },
        );
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    await _controller.reload();
  }

  Future<void> _loadUrl(String url) async {
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
      _exceptionLogService.record(
        node: 'source.webview_login.load_url',
        message: '加载 URL 失败（URL 无效）',
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'target': url,
          'initialUrl': _initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      return;
    }
    await _controller.loadRequest(uri, headers: _headerMap);
  }

  Future<void> _handlePageFinished(String url) async {
    await _syncCookies(url);
    if (!mounted || !_checking || _closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _confirmAndCheck() async {
    if (_checking || _initialUrl.isEmpty || !mounted) return;
    setState(() => _checking = true);
    await _loadUrl(_initialUrl);
  }

  Future<void> _syncCookies(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.trim().isEmpty) return;

    try {
      final cookies = await _readCookies(uri);
      if (cookies.isEmpty) return;

      await RuleParserEngine.saveCookiesForUrl(uri.toString(), cookies);

      final sourceBaseUrl = _resolveSourceBaseUrl();
      if (sourceBaseUrl != null && sourceBaseUrl != uri.toString()) {
        await RuleParserEngine.saveCookiesForUrl(sourceBaseUrl, cookies);
      }
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'source.webview_login.cookie_sync',
        message: '同步 WebView Cookie 失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'currentUrl': rawUrl,
        },
      );
    }
  }

  Future<List<Cookie>> _readCookies(Uri uri) async {
    final cookies = await WebViewCookieBridge.getCookiesForUrl(uri.toString());
    if (cookies.isNotEmpty) return cookies;
    return _readCookiesFromJs(uri);
  }

  Future<List<Cookie>> _readCookiesFromJs(Uri uri) async {
    try {
      final raw =
          await _controller.runJavaScriptReturningResult('document.cookie');
      final cookieHeader = _normalizeJsResult(raw).trim();
      if (cookieHeader.isEmpty) return const <Cookie>[];
      return _parseCookieHeader(cookieHeader, uri.host);
    } catch (error, stackTrace) {
      if (!_cookieFromJsErrorLogged) {
        _cookieFromJsErrorLogged = true;
        _exceptionLogService.record(
          node: 'source.webview_login.cookie_read_js',
          message: '读取 document.cookie 失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'sourceKey': widget.source.bookSourceUrl,
            'host': uri.host,
            'currentUrl': _currentUrl,
          },
        );
      }
      return const <Cookie>[];
    }
  }

  String _normalizeJsResult(Object raw) {
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    if ((text.startsWith('"') && text.endsWith('"')) ||
        (text.startsWith("'") && text.endsWith("'"))) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is String) return decoded;
      } catch (_) {
        return text.substring(1, text.length - 1);
      }
    }
    return text;
  }

  List<Cookie> _parseCookieHeader(String header, String host) {
    final out = <Cookie>[];
    final parts = header.split(';');
    for (final part in parts) {
      final pair = part.trim();
      if (pair.isEmpty) continue;
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final name = pair.substring(0, index).trim();
      if (name.isEmpty) continue;
      final value = pair.substring(index + 1).trim();
      final cookie = Cookie(name, value);
      cookie.domain = host;
      cookie.path = '/';
      out.add(cookie);
    }
    return out;
  }

  String? _resolveSourceBaseUrl() {
    final sourceKey = widget.source.bookSourceUrl.trim();
    if (sourceKey.isEmpty) return null;
    final first = sourceKey.split(',').first.trim();
    final uri = Uri.tryParse(first);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return null;
    }
    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    final showProgress = _isLoading || (_progress > 0 && _progress < 100);
    final sourceName = widget.source.bookSourceName.trim();
    final title = sourceName.isEmpty ? '登录' : '登录 $sourceName';

    return AppCupertinoPageScaffold(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            minimumSize: const Size(30, 30),
            onPressed: () => unawaited(actions.showMoreMenu()),
            child: const Icon(CupertinoIcons.ellipsis),
          ),
          AppNavBarButton(
            onPressed: () => unawaited(_confirmAndCheck()),
            minimumSize: const Size(30, 30),
            child: const Text('确认'),
          ),
        ],
      ),
      child: Column(
        children: [
          SourceWebViewProgressBar(
            showProgress: showProgress,
            progress: _progress,
            isLoading: _isLoading,
          ),
          if (_checking)
            const SourceWebViewHintBanner(text: _checkHint),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          AppWebViewToolbar(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            isLoading: _isLoading,
            onBack: () => unawaited(_goBack()),
            onForward: () => unawaited(_goForward()),
            onReload: () => unawaited(_reloadOrStop()),
            onMore: () => unawaited(actions.showMoreMenu()),
          ),
        ],
      ),
    );
  }
}
