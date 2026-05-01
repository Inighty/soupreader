import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:soupreader/app/widgets/app_webview_toolbar.dart';
import 'package:soupreader/features/source/views/shared/webview_common.dart';

class SourceWebVerifyBody extends StatelessWidget {
  const SourceWebVerifyBody({
    super.key,
    required this.controller,
    required this.showProgress,
    required this.progress,
    required this.isLoading,
    required this.importHint,
    required this.isFullScreen,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    required this.onToggleFullScreen,
    required this.onMore,
  });

  final WebViewController controller;
  final bool showProgress;
  final int progress;
  final bool isLoading;
  final String? importHint;
  final bool isFullScreen;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback onToggleFullScreen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SourceWebViewProgressBar(
          showProgress: showProgress,
          progress: progress,
          isLoading: isLoading,
        ),
        if (importHint != null)
          SourceWebViewHintBanner(text: importHint!),
        Expanded(
          child: WebViewWidget(controller: controller),
        ),
        if (!isFullScreen)
          AppWebViewToolbar(
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            isLoading: isLoading,
            onBack: onBack,
            onForward: onForward,
            onReload: onReload,
            onToggleFullScreen: onToggleFullScreen,
            onMore: onMore,
          ),
      ],
    );
  }
}

class SourceWebVerifyFullScreenOverlayControls extends StatelessWidget {
  const SourceWebVerifyFullScreenOverlayControls({
    super.key,
    required this.onExitFullScreen,
    required this.onMore,
    required this.onClose,
  });

  static const double _overlayBgAlpha = 0.72;
  static const double _overlayRadius = 12;
  static const double _buttonSize = 34;
  static const double _iconSize = 18;

  final VoidCallback onExitFullScreen;
  final VoidCallback onMore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoColors.systemBackground
        .resolveFrom(context)
        .withValues(alpha: _overlayBgAlpha);
    final iconColor = CupertinoColors.label.resolveFrom(context);

    Widget buildIconButton({
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(_buttonSize, _buttonSize),
        onPressed: onTap,
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(_overlayRadius),
          ),
          child: Icon(
            icon,
            size: _iconSize,
            color: iconColor,
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            buildIconButton(
              icon: CupertinoIcons.chevron_down,
              onTap: onExitFullScreen,
            ),
            const Spacer(),
            buildIconButton(
              icon: CupertinoIcons.ellipsis,
              onTap: onMore,
            ),
            const SizedBox(width: 8),
            buildIconButton(
              icon: CupertinoIcons.xmark,
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
