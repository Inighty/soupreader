import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import '../services/rss_article_style_helper.dart';
import '../services/rss_article_sync_service.dart';
import '../services/rss_sort_urls_helper.dart';
import 'rss_articles_body.dart';
import 'rss_articles_menu.dart';
import 'rss_articles_widgets.dart';
import 'rss_read_record_view.dart';
import 'rss_read_view.dart';
import 'rss_source_edit_view.dart';
import 'rss_source_variable_dialog.dart';
import 'rss_view_helpers.dart';

class RssArticlesPlaceholderView extends StatefulWidget {
  const RssArticlesPlaceholderView({
    super.key,
    required this.sourceName,
    required this.sourceUrl,
    this.repository,
  });

  final String sourceName;
  final String sourceUrl;
  final RssSourceRepository? repository;

  @override
  State<RssArticlesPlaceholderView> createState() =>
      _RssArticlesPlaceholderViewState();
}

class _RssArticlesPlaceholderViewState
    extends State<RssArticlesPlaceholderView> {
  late final RssSourceRepository _repo;
  late final RssArticleRepository _articleRepo;
  late final RssArticleSyncService _syncService;
  int _sortReloadVersion = 0;
  int _fallbackArticleStyle = RssArticleStyleHelper.minStyle;
  String _sortFutureKey = '';
  Future<List<RssSortTab>>? _sortTabsFuture;
  final GlobalKey _moreMenuKey = GlobalKey();

  int _selectedSortIndex = 0;
  List<RssArticle> _articles = const <RssArticle>[];
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _refreshError;
  RssArticleSession? _session;
  StreamSubscription<List<RssArticle>>? _articleStreamSub;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _repo = widget.repository ?? RssSourceRepository(db);
    _articleRepo = RssArticleRepository(db);
    _syncService =
        RssArticleSyncService(db: db, articleRepository: _articleRepo);
  }

  @override
  void dispose() {
    _articleStreamSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeArticles(String sourceUrl, String sortName) {
    _articleStreamSub?.cancel();
    _articleStreamSub = _articleRepo
        .flowByOriginSort(sourceUrl, sortName)
        .listen((articles) {
      if (!mounted) return;
      setState(() => _articles = articles);
    });
  }

  Future<void> _onSortTabSelected(
    int index,
    List<RssSortTab> tabs,
    RssSource? source,
  ) async {
    if (_selectedSortIndex == index && _session != null) return;
    setState(() {
      _selectedSortIndex = index;
      _articles = const <RssArticle>[];
      _session = null;
      _refreshError = null;
    });
    final tab = tabs.isNotEmpty ? tabs[index] : null;
    final sortName = tab?.name ?? '';
    final sourceUrl = source?.sourceUrl.trim() ?? '';
    if (sourceUrl.isNotEmpty) {
      _subscribeArticles(sourceUrl, sortName);
    }
    if (source != null && tab != null) {
      await _doRefresh(source: source, tab: tab);
    }
  }

  Future<void> _doRefresh({
    required RssSource source,
    required RssSortTab tab,
  }) async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });
    try {
      final result = await _syncService.refresh(
        source: source,
        sortName: tab.name,
        sortUrl: tab.url,
      );
      if (!mounted) return;
      setState(() {
        _session = result.session;
        _isRefreshing = false;
        if (result.error != null) _refreshError = result.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _refreshError = e.toString();
      });
    }
  }

  Future<void> _doLoadMore(RssSource source) async {
    final session = _session;
    if (session == null || !session.hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _syncService.loadMore(
        source: source,
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _session = result.session;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  String get _sourceUrlKey => widget.sourceUrl.trim();

  RssSource? _buildFallbackSource() {
    final sourceUrl = _sourceUrlKey;
    if (sourceUrl.isEmpty) return null;
    return RssSource(
      sourceUrl: sourceUrl,
      sourceName: widget.sourceName.trim(),
      articleStyle: _fallbackArticleStyle,
    );
  }

  RssSource? _resolveCurrentSource(List<RssSource>? sources) {
    final key = _sourceUrlKey;
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

  RssSource? _resolveMenuSource(RssSource? source) {
    return source ?? _buildFallbackSource();
  }

  String _buildSortFutureKey(RssSource? source) {
    final sourceUrl = source?.sourceUrl.trim() ?? '';
    final sortUrl = (source?.sortUrl ?? '').trim();
    return '$sourceUrl::$sortUrl::$_sortReloadVersion';
  }

  void _ensureSortTabsFuture(RssSource? source) {
    final key = _buildSortFutureKey(source);
    if (_sortTabsFuture != null && _sortFutureKey == key) {
      return;
    }
    _sortFutureKey = key;
    _sortTabsFuture = _loadSortTabs(source);
  }

  Future<List<RssSortTab>> _loadSortTabs(RssSource? source) async {
    if (source == null) return const <RssSortTab>[];
    try {
      return await RssSortUrlsHelper.resolveSortTabs(source);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.sort_tabs',
        message: 'RSS 分类解析失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': source.sourceUrl,
        },
      );
      return const <RssSortTab>[];
    }
  }

  String _resolvePageTitle(RssSource? source) {
    final sourceName = source?.sourceName.trim() ?? '';
    if (sourceName.isNotEmpty) return sourceName;
    final initialName = widget.sourceName.trim();
    if (initialName.isNotEmpty) return initialName;
    return 'RSS 文章列表';
  }

  Widget? _buildTrailingAction(RssSource? source) {
    if (source == null) return null;
    final actions = buildRssArticlesMenuActions(source);
    if (actions.isEmpty) return null;
    return CupertinoButton(
      key: _moreMenuKey,
      padding: EdgeInsets.zero,
      minimumSize: const Size(28, 28),
      onPressed: () => _showMoreMenu(source: source, actions: actions),
      child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
    );
  }

  Future<void> _showMoreMenu({
    required RssSource source,
    required List<RssArticlesMenuAction> actions,
  }) async {
    if (!mounted) return;
    final selected = await showRssArticlesMoreMenu(
      context: context,
      anchorKey: _moreMenuKey,
      actions: actions,
    );
    if (selected == null) return;
    switch (selected) {
      case RssArticlesMenuAction.login:
        await _openSourceLogin(source);
      case RssArticlesMenuAction.refreshSort:
        await _refreshSort(source);
      case RssArticlesMenuAction.setSourceVariable:
        if (!mounted) return;
        await showRssSourceVariableDialog(
          context: context,
          source: source,
          loadCurrentSource: (url) => _repo.getByKey(url) ?? source,
        );
      case RssArticlesMenuAction.editSource:
        await _openEditSource(source);
      case RssArticlesMenuAction.switchLayout:
        await _switchLayout(source);
      case RssArticlesMenuAction.readRecord:
        await _openReadRecord();
      case RssArticlesMenuAction.clear:
        await _clearArticles(source);
    }
  }

  Future<void> _openReadRecord() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const RssReadRecordView(),
      ),
    );
  }

  Future<void> _clearArticles(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    try {
      await _articleRepo.deleteByOrigin(sourceUrl);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_clear',
        message: '清除 RSS 文章缓存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'sourceUrl': sourceUrl},
      );
    }
  }

  Future<void> _refreshSort(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    final current = _repo.getByKey(sourceUrl) ?? source;
    try {
      await RssSortUrlsHelper.clearSortCache(current);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_refresh_sort',
        message: '刷新 RSS 分类缓存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': current.sourceUrl,
          'sortUrl': current.sortUrl,
        },
      );
      return;
    }
    if (!mounted) return;
    setState(() => _sortReloadVersion += 1);
  }

  Future<void> _switchLayout(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    final cached = _repo.getByKey(sourceUrl);
    final current = cached ?? source;
    final nextStyle = RssArticleStyleHelper.nextStyle(current.articleStyle);

    if (cached == null) {
      if (!mounted) return;
      setState(() {
        _fallbackArticleStyle = nextStyle;
        _sortReloadVersion += 1;
      });
      return;
    }

    try {
      await _repo.updateSource(cached.copyWith(articleStyle: nextStyle));
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_switch_layout',
        message: '切换 RSS 文章布局失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'fromStyle': cached.articleStyle,
          'toStyle': nextStyle,
        },
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _fallbackArticleStyle = nextStyle;
      _sortReloadVersion += 1;
    });
  }

  Future<void> _openSourceLogin(RssSource source) async {
    if (!mounted) return;
    await openRssSourceLogin(
      context: context,
      repository: _repo,
      source: source,
    );
  }

  Future<void> _openEditSource(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty || !mounted) return;
    try {
      final saved = await Navigator.of(context).push<bool>(
        CupertinoPageRoute<bool>(
          builder: (_) => RssSourceEditView(sourceUrl: sourceUrl),
        ),
      );
      if (!mounted || saved != true) return;
      setState(() => _sortReloadVersion += 1);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_edit_source',
        message: '打开 RSS 源编辑页失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{'sourceUrl': sourceUrl},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RssSource>>(
      stream: _repo.watchAllSources(),
      builder: (context, snapshot) {
        final source = _resolveCurrentSource(snapshot.data);
        final menuSource = _resolveMenuSource(source);
        final title = _resolvePageTitle(menuSource);
        _ensureSortTabsFuture(menuSource);

        return AppCupertinoPageScaffold(
          title: title,
          trailing: _buildTrailingAction(menuSource),
          child: FutureBuilder<List<RssSortTab>>(
            future: _sortTabsFuture,
            builder: (context, sortSnapshot) {
              final tabs = sortSnapshot.data ?? const <RssSortTab>[];
              if (sortSnapshot.connectionState == ConnectionState.done &&
                  _session == null &&
                  !_isRefreshing &&
                  tabs.isNotEmpty &&
                  menuSource != null) {
                final idx = _selectedSortIndex.clamp(0, tabs.length - 1);
                final tab = tabs[idx];
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _session == null && !_isRefreshing) {
                    _onSortTabSelected(idx, tabs, menuSource);
                  }
                });
                final sourceUrl = menuSource.sourceUrl.trim();
                if (_articleStreamSub == null && sourceUrl.isNotEmpty) {
                  _subscribeArticles(sourceUrl, tab.name);
                }
              }

              final separatorColor =
                  CupertinoColors.separator.resolveFrom(context);

              return Column(
                children: [
                  if (tabs.length > 1)
                    RssSortTabBar(
                      tabs: tabs,
                      selectedIndex:
                          _selectedSortIndex.clamp(0, tabs.length - 1),
                      onTap: (idx) =>
                          _onSortTabSelected(idx, tabs, menuSource),
                    ),
                  if (tabs.length > 1)
                    Container(height: 0.5, color: separatorColor),
                  Expanded(
                    child: RssArticlesBody(
                      source: menuSource,
                      tabs: tabs,
                      articles: _articles,
                      selectedSortIndex: _selectedSortIndex,
                      scrollController: _scrollController,
                      isRefreshing: _isRefreshing,
                      isLoadingMore: _isLoadingMore,
                      session: _session,
                      refreshError: _refreshError,
                      fallbackArticleStyle: _fallbackArticleStyle,
                      isLoadingTabs: sortSnapshot.connectionState ==
                          ConnectionState.waiting,
                      onRefresh: _doRefresh,
                      onLoadMore: _doLoadMore,
                      onOpenArticle: _openArticle,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openArticle(RssArticle article) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssReadPlaceholderView(
          title: article.title,
          origin: article.origin,
          link: article.link,
          repository: _repo,
        ),
      ),
    );
  }
}
