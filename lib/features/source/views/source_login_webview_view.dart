import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/webview_cookie_bridge.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';

/// 对标 legado `source_webview_login/menu_ok`：
/// - 顶栏一级动作“确认”
/// - 点击后提示“正在打开首页，成功自动返回主界面”
/// - 重载首页并在页面加载完成后自动返回
/// - 页面加载期间持续同步 Cookie 到解析引擎 CookieJar
class SourceLoginWebViewView extends StatefulWidget {
  final BookSource source;
  final String initialUrl;

  const SourceLoginWebViewView({
    super.key,
    required this.source,
    required this.initialUrl,
  });

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

  bool _checking = false;
  bool _closing = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _initialUrl = widget.initialUrl.trim();
    _headerMap = _buildHeaderMap(widget.source.header);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            unawaited(_syncCookies(url));
          },
          onPageFinished: (url) {
            unawaited(_handlePageFinished(url));
          },
          onUrlChange: (_) {},
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == 'http' || scheme == 'https') {
              return NavigationDecision.navigate;
            }
            if (uri == null) return NavigationDecision.prevent;
            final allowed = await _confirmOpenExternalApp(uri);
            if (allowed) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    if (_initialUrl.isNotEmpty) {
      unawaited(_loadUrl(_initialUrl));
    }
  }

  Future<void> _loadUrl(String url) async {
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
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
    if (_checking) return;
    if (_initialUrl.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _checking = true;
    });
    await _loadUrl(_initialUrl);
  }

  Future<bool> _confirmOpenExternalApp(Uri uri) async {
    if (!mounted) return false;
    // 对齐 legado WebViewLoginFragment：
    // 非 http(s) 仅二次确认是否跳转其它应用，不提供额外管理动作。
    final result = await showCupertinoBottomDialog<bool>(
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

  Map<String, String> _buildHeaderMap(String? rawHeader) {
    final headers = _parseHeaderMap(rawHeader);
    headers.putIfAbsent('User-Agent', () => _defaultUserAgent);
    return headers;
  }

  Map<String, String> _parseHeaderMap(String? rawHeader) {
    final text = (rawHeader ?? '').trim();
    if (text.isEmpty) return <String, String>{};

    dynamic payload = text;
    for (var i = 0; i < 2; i++) {
      if (payload is! String) break;
      final current = payload.trim();
      if (current.isEmpty) return <String, String>{};
      if (!(current.startsWith('{') && current.endsWith('}')) &&
          !(current.startsWith('"') && current.endsWith('"'))) {
        break;
      }
      try {
        payload = jsonDecode(current);
      } catch (_) {
        break;
      }
    }

    if (payload is Map) {
      final out = <String, String>{};
      payload.forEach((key, value) {
        if (key == null || value == null) return;
        final k = key.toString().trim();
        if (k.isEmpty) return;
        out[k] = value.toString();
      });
      return out;
    }

    if (payload is String) {
      final out = <String, String>{};
      final lines = payload.split(RegExp(r'[\r\n]+'));
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final index = trimmed.indexOf(':');
        if (index <= 0) continue;
        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        if (key.isEmpty) continue;
        out[key] = value;
      }
      return out;
    }

    return <String, String>{};
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
      ExceptionLogService().record(
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
    } catch (_) {
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

  Color _accentColor(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final showProgress = progress > 0 && progress < 100;
    final sourceName = widget.source.bookSourceName.trim();
    final title = sourceName.isEmpty ? '登录' : '登录 $sourceName';

    return AppCupertinoPageScaffold(
      title: title,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _confirmAndCheck,
        child: const Text('确认'),
        minimumSize: const Size(30, 30),
      ),
      child: Column(
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
                      decoration: BoxDecoration(color: _accentColor(context)),
                    ),
                  ),
                ),
              ),
            ),
          if (_checking)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Text(
                _checkHint,
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
      ),
    );
  }
}
