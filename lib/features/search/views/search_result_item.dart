import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/source_aware_cover_image.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../services/search_aggregator.dart';

/// 单条搜索结果卡片。
class SearchResultItem extends StatelessWidget {
  const SearchResultItem({
    super.key,
    required this.item,
    required this.showCover,
    required this.sourceRepo,
    required this.onCoverState,
    required this.onTap,
  });

  final SearchDisplayItem item;
  final bool showCover;
  final SourceRepository sourceRepo;
  final void Function(String itemKey, SourceAwareCoverLoadState state)
      onCoverState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    final result = item.primary;
    final coverUrl = item.displayCoverUrl;
    final sourceCount = item.origins.length;
    final mutedStyle = theme.textTheme.textStyle.copyWith(
      fontSize: 12,
      color: uiTokens.colors.mutedForeground,
    );
    final meta = <String>[
      if (result.kind.isNotEmpty) result.kind,
      if (result.wordCount.isNotEmpty) '字数:${result.wordCount}',
      if (result.updateTime.isNotEmpty) '更新:${result.updateTime}',
    ];
    final coverSource =
        showCover ? sourceRepo.getSourceByUrl(item.displayCoverSourceUrl) : null;

    return Padding(
      key: ValueKey(item.key),
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: uiTokens.colors.card,
            borderRadius: BorderRadius.circular(uiTokens.radii.control),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCover) ...[
                coverUrl.isEmpty
                    ? AppCoverImage(
                        urlOrPath: '',
                        title: result.name,
                        author: result.author,
                        width: 66,
                        height: 92,
                        borderRadius: 8,
                        fit: BoxFit.cover,
                        showTextOnPlaceholder: false,
                      )
                    : SourceAwareCoverImage(
                        urlOrPath: coverUrl,
                        source: coverSource,
                        title: result.name,
                        author: result.author,
                        width: 66,
                        height: 92,
                        borderRadius: 8,
                        fit: BoxFit.cover,
                        showTextOnPlaceholder: false,
                        onLoadStateChanged: (state) =>
                            onCoverState(item.key, state),
                      ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.textStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: uiTokens.colors.foreground,
                            ),
                          ),
                        ),
                        if (sourceCount > 1)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: uiTokens.colors.accent
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$sourceCount 源',
                              style: theme.textTheme.textStyle.copyWith(
                                fontSize: 12,
                                color: uiTokens.colors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.author.isNotEmpty ? result.author : '未知作者',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mutedStyle,
                      ),
                    ],
                    if (result.lastChapter.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '最新: ${result.lastChapter}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mutedStyle,
                      ),
                    ],
                    if (result.intro.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.intro,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: mutedStyle,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      sourceCount > 1
                          ? '来源: ${result.sourceName} 等 $sourceCount 个'
                          : '来源: ${result.sourceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                item.inBookshelf
                    ? CupertinoIcons.book_fill
                    : CupertinoIcons.chevron_forward,
                size: item.inBookshelf ? 17 : 16,
                color: item.inBookshelf
                    ? uiTokens.colors.accent
                    : uiTokens.colors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
