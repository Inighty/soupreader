import 'package:flutter/cupertino.dart';

import '../models/rss_article.dart';
import '../models/rss_source.dart';
import '../services/rss_article_load_more_helper.dart';
import '../services/rss_article_style_helper.dart';
import '../services/rss_article_sync_models.dart';
import '../services/rss_sort_urls_helper.dart';
import 'rss_articles_widgets.dart';

/// 文章主体（列表 / 网格 / 空态 / 加载态）。
class RssArticlesBody extends StatelessWidget {
  const RssArticlesBody({
    super.key,
    required this.source,
    required this.tabs,
    required this.articles,
    required this.selectedSortIndex,
    required this.scrollController,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.session,
    required this.refreshError,
    required this.fallbackArticleStyle,
    required this.isLoadingTabs,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpenArticle,
  });

  final RssSource? source;
  final List<RssSortTab> tabs;
  final List<RssArticle> articles;
  final int selectedSortIndex;
  final ScrollController scrollController;
  final bool isRefreshing;
  final bool isLoadingMore;
  final RssArticleSession? session;
  final String? refreshError;
  final int fallbackArticleStyle;
  final bool isLoadingTabs;
  final Future<void> Function({
    required RssSource source,
    required RssSortTab tab,
  }) onRefresh;
  final Future<void> Function(RssSource source) onLoadMore;
  final ValueChanged<RssArticle> onOpenArticle;

  bool get _isGridView => RssArticleStyleHelper.isGridStyle(
        source?.articleStyle ?? fallbackArticleStyle,
      );

  @override
  Widget build(BuildContext context) {
    if (isLoadingTabs && articles.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final hasMore = RssArticleLoadMoreHelper.shouldShowManualLoadMore(
      isLoading: isLoadingMore,
      hasMore: session?.hasMore ?? false,
      articleCount: articles.length,
    );

    if (articles.isEmpty && !isRefreshing) {
      return _buildEmpty(context);
    }

    if (_isGridView) {
      return _buildGrid(hasMore: hasMore);
    }
    return _buildList(hasMore: hasMore);
  }

  Widget _buildEmpty(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildRefreshControl(),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: refreshError != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      refreshError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                        fontSize: 14,
                      ),
                    ),
                  )
                : Text(
                    '暂无文章',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildList({required bool hasMore}) {
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildRefreshControl(),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == articles.length) {
                  return hasMore
                      ? _buildLoadMoreButton(source!)
                      : isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CupertinoActivityIndicator()),
                            )
                          : const SizedBox.shrink();
                }
                final article = articles[index];
                return RssArticleListTile(
                  article: article,
                  onTap: () => onOpenArticle(article),
                );
              },
              childCount: articles.length + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid({required bool hasMore}) {
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildRefreshControl(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final article = articles[index];
                return RssArticleGridCard(
                  article: article,
                  onTap: () => onOpenArticle(article),
                );
              },
              childCount: articles.length,
            ),
          ),
        ),
        if (hasMore)
          SliverToBoxAdapter(child: _buildLoadMoreButton(source!)),
        if (isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildRefreshControl() {
    return CupertinoSliverRefreshControl(
      onRefresh: source != null && tabs.isNotEmpty
          ? () => onRefresh(
                source: source!,
                tab: tabs[selectedSortIndex.clamp(0, tabs.length - 1)],
              )
          : null,
    );
  }

  Widget _buildLoadMoreButton(RssSource source) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CupertinoButton(
        onPressed: () => onLoadMore(source),
        child: const Text('加载更多'),
      ),
    );
  }
}
