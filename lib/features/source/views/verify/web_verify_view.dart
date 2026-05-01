import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:soupreader/app/widgets/app_cupertino_page_scaffold.dart';
import 'package:soupreader/app/widgets/app_nav_bar_button.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/features/source/views/verify/web_verify_actions.dart';
import 'package:soupreader/features/source/views/verify/web_verify_ui.dart';

class SourceWebVerifyView extends StatefulWidget {
  const SourceWebVerifyView({
    super.key,
    required this.initialUrl,
    this.sourceOrigin = '',
    this.sourceName = '',
  });

  final String initialUrl;
  final String sourceOrigin;
  final String sourceName;

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
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _navStateRefreshErrorLogged = false;
  String? _lastImportHint;
  String? _lastImportCookieHeaderValue;

  SourceWebVerifyActions get _actions => SourceWebVerifyActions(
        context: context,
        controller: _controller,
        sourceRepo: _sourceRepo,
        exceptionLogService: _exceptionLogService,
        initialUrl: widget.initialUrl,
        currentUrl: _currentUrl,
        sourceOrigin: widget.sourceOrigin,
        sourceName: widget.sourceName,
        lastImportCookieHeaderValue: _lastImportCookieHeaderValue,
        toggleFullScreen: _toggleFullScreen,
        closePage: _closePage,
        onCookiesImported: _handleCookieImported,
      );

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
            unawaited(_refreshNavState());
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            unawaited(_refreshNavState());
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || !mounted) return;
            setState(() => _currentUrl = url);
            unawaited(_refreshNavState());
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
        node: 'source.web_view.refresh_nav_state',
        message: '刷新 WebView 导航状态失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
          'isFullScreen': _isFullScreen,
          'isLoading': _isLoading,
        },
      );
    }
  }

  Future<void> _goBack() async {
    if (!await _controller.canGoBack()) return;
    await _controller.goBack();
    unawaited(_refreshNavState());
  }

  Future<void> _goForward() async {
    if (!await _controller.canGoForward()) return;
    await _controller.goForward();
    unawaited(_refreshNavState());
  }

  Future<void> _reloadOrStop() async {
    if (_isLoading) {
      try {
        await _controller.runJavaScript('window.stop();');
      } catch (error, stackTrace) {
        _exceptionLogService.record(
          node: 'source.web_view.stop_loading',
          message: '停止加载失败（window.stop）',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'initialUrl': widget.initialUrl,
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

  void _handleCookieImported(SourceWebVerifyCookieImportResult result) {
    if (!mounted) return;
    setState(() {
      _lastImportHint = result.hint;
      _lastImportCookieHeaderValue = result.cookieHeaderValue;
    });
  }

  void _closePage() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    final showProgress = _isLoading || (_progress > 0 && _progress < 100);

    return PopScope(
      canPop: !_isFullScreen && !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isFullScreen) {
          await _toggleFullScreen();
          return;
        }
        try {
          final canGoBack = await _controller.canGoBack();
          if (canGoBack) {
            await _controller.goBack();
            unawaited(_refreshNavState());
            return;
          }
        } catch (error, stackTrace) {
          _exceptionLogService.record(
            node: 'source.web_view.pop_go_back',
            message: '返回触发 WebView 后退失败',
            error: error,
            stackTrace: stackTrace,
            context: <String, dynamic>{
              'initialUrl': widget.initialUrl,
              'currentUrl': _currentUrl,
              'isFullScreen': _isFullScreen,
              'isLoading': _isLoading,
            },
          );
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: _isFullScreen
          ? CupertinoPageScaffold(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: SourceWebVerifyBody(
                        controller: _controller,
                        showProgress: showProgress,
                        progress: _progress,
                        isLoading: _isLoading,
                        importHint: _lastImportHint,
                        isFullScreen: true,
                        canGoBack: _canGoBack,
                        canGoForward: _canGoForward,
                        onBack: () => unawaited(_goBack()),
                        onForward: () => unawaited(_goForward()),
                        onReload: () => unawaited(_reloadOrStop()),
                        onToggleFullScreen: () => unawaited(_toggleFullScreen()),
                        onMore: () => unawaited(actions.showMoreMenu()),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SourceWebVerifyFullScreenOverlayControls(
                      onExitFullScreen: () => unawaited(_toggleFullScreen()),
                      onMore: () => unawaited(actions.showMoreMenu()),
                      onClose: _closePage,
                    ),
                  ),
                ],
              ),
            )
          : AppCupertinoPageScaffold(
              title: '网页验证',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppNavBarButton(
                    minimumSize: const Size(30, 30),
                    onPressed: _closePage,
                    child: const Icon(CupertinoIcons.check_mark),
                  ),
                  AppNavBarButton(
                    minimumSize: const Size(30, 30),
                    onPressed: () => unawaited(actions.showMoreMenu()),
                    child: const Icon(CupertinoIcons.ellipsis),
                  ),
                ],
              ),
              child: SourceWebVerifyBody(
                controller: _controller,
                showProgress: showProgress,
                progress: _progress,
                isLoading: _isLoading,
                importHint: _lastImportHint,
                isFullScreen: false,
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                onBack: () => unawaited(_goBack()),
                onForward: () => unawaited(_goForward()),
                onReload: () => unawaited(_reloadOrStop()),
                onToggleFullScreen: () => unawaited(_toggleFullScreen()),
                onMore: () => unawaited(actions.showMoreMenu()),
              ),
            ),
    );
  }
}
