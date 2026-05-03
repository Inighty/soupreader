import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/database/repositories/rss_star_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import '../models/rss_star.dart';
import 'rss_read_aloud_controller.dart';
import 'rss_read_favorite_dialog.dart';
import 'rss_read_more_menu.dart';
import 'rss_read_trailing_actions.dart';
import 'rss_read_web_view.dart';
import 'rss_view_helpers.dart';

class RssReadPlaceholderView extends StatefulWidget {
  const RssReadPlaceholderView({
    super.key,
    required this.title,
    required this.origin,
    this.link,
    this.repository,
  });

  final String title;
  final String origin;
  final String? link;
  final RssSourceRepository? repository;

  @override
  State<RssReadPlaceholderView> createState() => _RssReadPlaceholderViewState();
}

class _RssReadPlaceholderViewState extends State<RssReadPlaceholderView> {
  late final RssSourceRepository _repo;
  late final RssArticleRepository _articleRepo;
  late final RssStarRepository _starRepo;
  int _refreshVersion = 0;
  RssArticle? _rssArticle;
  RssStar? _rssStar;
  int _favoriteLoadVersion = 0;
  bool _favoriteActionRunning = false;
  final RssReadAloudController _readAloudController = RssReadAloudController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
    _articleRepo = RssArticleRepository(DatabaseService());
    _starRepo = RssStarRepository(DatabaseService());
    _reloadFavoriteContext();
  }

  @override
  void dispose() {
    unawaited(_disposeReadAloudTts());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RssReadPlaceholderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldOrigin = oldWidget.origin.trim();
    final oldLink = (oldWidget.link ?? '').trim();
    if (oldOrigin != _originKey || oldLink != _linkKey) {
      _reloadFavoriteContext();
    }
  }

  String get _originKey => widget.origin.trim();
  String get _linkKey => (widget.link ?? '').trim();

  RssSource? _resolveCurrentSource(List<RssSource>? sources) {
    final key = _originKey;
    if (key.isEmpty) return null;
    if (sources != null) {
      for (final source in sources) {
        if (source.sourceUrl.trim() == key) {
          return source;
        }
      }
    }
    return _repo.getByKey(key);
  }

  bool get _canShowFavoriteAction => _rssArticle != null;
  bool get _isInFavorites => _rssStar != null;

  String? _resolveShareTarget() {
    final currentLink = _linkKey;
    if (currentLink.isNotEmpty) {
      return currentLink;
    }
    final articleLink = (_rssArticle?.link ?? '').trim();
    if (articleLink.isNotEmpty) {
      return articleLink;
    }
    return null;
  }

  String? _resolveBrowserOpenTarget() {
    final currentLink = _linkKey;
    if (currentLink.isNotEmpty) {
      return currentLink;
    }
    final articleLink = (_rssArticle?.link ?? '').trim();
    if (articleLink.isNotEmpty) {
      return articleLink;
    }
    final origin = _originKey;
    if (origin.isNotEmpty) {
      return origin;
    }
    return null;
  }

  String _normalizeReadAloudText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parsed = html_parser.parse(trimmed);
    final bodyText = parsed.body?.text ?? '';
    final documentText = parsed.documentElement?.text ?? '';
    final source = bodyText.trim().isNotEmpty ? bodyText : documentText;
    final lines = source
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isNotEmpty) {
      return lines.join('\n');
    }
    return trimmed;
  }

  String _resolveReadAloudText() {
    final candidates = <String?>[
      _rssArticle?.description,
      _rssArticle?.content,
      _rssArticle?.title,
      widget.title,
    ];
    for (final candidate in candidates) {
      final normalized = _normalizeReadAloudText(candidate ?? '');
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  void _showToast(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  Future<void> _reloadFavoriteContext() async {
    final loadVersion = ++_favoriteLoadVersion;
    final origin = _originKey;
    final link = _linkKey;
    if (origin.isEmpty || link.isEmpty) {
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssArticle = null;
        _rssStar = null;
      });
      return;
    }
    try {
      final star = await _starRepo.get(origin, link);
      final article =
          star?.toRssArticle() ?? await _articleRepo.get(origin, link);
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssStar = star;
        _rssArticle = article;
      });
    } catch (error, stackTrace) {
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssStar = null;
        _rssArticle = null;
      });
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '加载 RSS 收藏状态失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': origin,
          'link': link,
        },
      );
    }
  }

  void _handleRefresh() {
    if (!mounted) return;
    setState(() {
      _refreshVersion += 1;
    });
  }

  Future<void> _handleShare() async {
    final target = _resolveShareTarget();
    if (target == null) {
      _showToast('Null url');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: target,
          subject: '分享',
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(text)：分享异常静默吞掉，不追加提示。
    }
  }

  Future<void> _handleBrowserOpen() async {
    final target = _resolveBrowserOpenTarget();
    if (target == null) {
      _showToast('url null');
      return;
    }
    final uri = Uri.tryParse(target);
    if (uri == null) {
      ExceptionLogService().record(
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
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
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
    }
  }

  Future<void> _handleReadAloud() => _readAloudController.toggle(
        text: _resolveReadAloudText(),
        originKey: _originKey,
        linkKey: _linkKey,
      );

  Future<void> _disposeReadAloudTts() => _readAloudController.disposeAsync();

  Future<void> _handleFavoriteAction() async {
    final article = _rssArticle;
    if (article == null || _favoriteActionRunning) return;
    setState(() {
      _favoriteActionRunning = true;
    });
    try {
      if (_rssStar == null) {
        final createdStar = rssStarFromArticle(article);
        await _starRepo.upsert(createdStar);
        if (!mounted) return;
        setState(() {
          _rssStar = createdStar;
          _rssArticle = article.copyWith(
            title: createdStar.title,
            group: createdStar.group,
          );
        });
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '添加 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': article.origin,
          'link': article.link,
        },
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _favoriteActionRunning = false;
        });
      }
    }
    if (!mounted) return;
    await _openFavoriteDialog();
  }

  Future<void> _openFavoriteDialog() async {
    final article = _rssArticle;
    if (article == null || !mounted) return;
    final result = await showRssFavoriteDialog(
      context: context,
      initialTitle: article.title,
      initialGroup: article.group,
    );
    switch (result.action) {
      case RssFavoriteDialogAction.delete:
        await _deleteFavorite();
      case RssFavoriteDialogAction.confirm:
        final current = _rssArticle;
        if (current == null) return;
        var nextTitle = current.title;
        if (result.title.trim().isNotEmpty) {
          nextTitle = result.title;
        }
        var nextGroup = current.group;
        if (result.group.trim().isNotEmpty) {
          nextGroup = result.group;
        }
        await _updateFavorite(title: nextTitle, group: nextGroup);
      case RssFavoriteDialogAction.cancel:
        break;
    }
  }

  Future<void> _updateFavorite({
    required String title,
    required String group,
  }) async {
    final current = _rssArticle;
    if (current == null) return;
    final updatedArticle = current.copyWith(
      title: title,
      group: group,
    );
    final updatedStar = rssStarFromArticle(updatedArticle);
    try {
      await _starRepo.update(updatedStar);
      if (!mounted) return;
      setState(() {
        _rssArticle = updatedArticle;
        _rssStar = updatedStar;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '更新 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': updatedArticle.origin,
          'link': updatedArticle.link,
        },
      );
    }
  }

  Future<void> _deleteFavorite() async {
    final star = _rssStar;
    if (star == null) return;
    try {
      await _starRepo.delete(star.origin, star.link);
      if (!mounted) return;
      setState(() {
        _rssStar = null;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '删除 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': star.origin,
          'link': star.link,
        },
      );
    }
  }

  Future<void> _showMoreMenu(RssSource? source) async {
    if (!mounted) return;
    final selected =
        await showRssReadMoreMenu(context: context, source: source);
    if (!mounted || selected == null) return;
    switch (selected) {
      case RssReadMenuAction.login:
        if (source == null) return;
        await _openSourceLogin(source);
      case RssReadMenuAction.browserOpen:
        await _handleBrowserOpen();
    }
  }

  Future<void> _openSourceLogin(RssSource source) async {
    if (!mounted) return;
    await openRssSourceLogin(
      context: context,
      repository: _repo,
      source: source,
    );
  }

  Widget _buildTrailingAction(RssSource? source) {
    return RssReadTrailingActions(
      showFavorite: _canShowFavoriteAction,
      isInFavorites: _isInFavorites,
      favoriteActionRunning: _favoriteActionRunning,
      readAloudPlaying: _readAloudController.isPlaying,
      onRefresh: _handleRefresh,
      onFavorite: _handleFavoriteAction,
      onShare: _handleShare,
      onReadAloud: _handleReadAloud,
      onMore: () => _showMoreMenu(source),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RssSource>>(
      stream: _repo.watchAllSources(),
      builder: (context, snapshot) {
        final source = _resolveCurrentSource(snapshot.data);
        return AppCupertinoPageScaffold(
          title: widget.title.isEmpty ? 'RSS 阅读' : widget.title,
          trailing: _buildTrailingAction(source),
          child: RssReadWebView(
            refreshVersion: _refreshVersion,
            article: _rssArticle,
            link: _linkKey,
            origin: _originKey,
          ),
        );
      },
    );
  }
}
