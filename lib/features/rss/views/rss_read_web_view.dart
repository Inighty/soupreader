import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/rss_article.dart';

class RssReadWebView extends StatefulWidget {
  const RssReadWebView({
    super.key,
    required this.refreshVersion,
    required this.article,
    required this.link,
    required this.origin,
  });

  final int refreshVersion;
  final RssArticle? article;
  final String link;
  final String origin;

  @override
  State<RssReadWebView> createState() => RssReadWebViewState();
}

class RssReadWebViewState extends State<RssReadWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _lastLoadedKey;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ));
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant RssReadWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey =
        '${widget.refreshVersion}::${widget.link}::${widget.article?.link}';
    if (_lastLoadedKey != newKey) _loadContent();
  }

  void _loadContent() {
    final key =
        '${widget.refreshVersion}::${widget.link}::${widget.article?.link}';
    _lastLoadedKey = key;
    final link = widget.link.trim();
    if (link.isNotEmpty) {
      _controller.loadRequest(Uri.parse(link));
      return;
    }
    final article = widget.article;
    if (article == null) {
      _controller.loadHtmlString('<html><body></body></html>');
      return;
    }
    final content = (article.content?.trim().isNotEmpty == true
            ? article.content!
            : article.description) ??
        '';
    final html = _buildHtml(
      title: article.title,
      content: content,
      baseUrl: widget.origin,
    );
    _controller.loadHtmlString(
      html,
      baseUrl: widget.origin.isNotEmpty ? widget.origin : null,
    );
  }

  String _buildHtml({
    required String title,
    required String content,
    required String baseUrl,
  }) {
    final escapedTitle = title
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    return '''
<!DOCTYPE html><html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=yes">
<style>
body{font-family:-apple-system,sans-serif;font-size:16px;line-height:1.6;color:#1c1c1e;padding:16px;margin:0;word-wrap:break-word;}
h1{font-size:20px;font-weight:700;margin-bottom:12px;}
img{max-width:100%;height:auto;border-radius:6px;}
a{color:#007aff;}
@media(prefers-color-scheme:dark){body{background:#1c1c1e;color:#e5e5ea;}a{color:#0a84ff;}}
</style></head><body>
${title.isNotEmpty ? '<h1>$escapedTitle</h1>' : ''}
$content
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: CupertinoActivityIndicator()),
          ),
      ],
    );
  }
}
