import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

import '../models/rss_article.dart';
import '../services/rss_sort_urls_helper.dart';

/// 分类 Tab 横向滚动栏。
class RssSortTabBar extends StatelessWidget {
  const RssSortTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<RssSortTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = CupertinoTheme.of(context).primaryColor;
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final selected = index == selectedIndex;
          final label = tab.name.trim().isEmpty ? '默认' : tab.name.trim();
          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withValues(alpha: 0.12)
                    : CupertinoColors.tertiarySystemGroupedBackground
                        .resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? activeColor.withValues(alpha: 0.4)
                      : separatorColor.withValues(alpha: 0.6),
                  width: 0.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? activeColor
                      : CupertinoColors.label.resolveFrom(context),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 文章列表项（大图 + 标题 + 时间，对齐 legado item_rss_article_2.xml）。
class RssArticleListTile extends StatelessWidget {
  const RssArticleListTile({
    super.key,
    required this.article,
    required this.onTap,
  });

  final RssArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final imageUrl = (article.image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;
    final isRead = article.read;
    final titleColor = isRead
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            SizedBox(
              height: 180,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    height: 1.35,
                  ),
                ),
                if ((article.pubDate ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    article.pubDate!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(height: 0.5, color: separatorColor),
        ],
      ),
    );
  }
}

/// 文章网格卡片（双列 0.72 宽高比）。
class RssArticleGridCard extends StatelessWidget {
  const RssArticleGridCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  final RssArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardBg = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final imageUrl = (article.image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: cardBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage)
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color:
                          CupertinoColors.systemGrey5.resolveFrom(context),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 32,
                      color:
                          CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              if ((article.pubDate ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Text(
                    article.pubDate!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryLabel,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
