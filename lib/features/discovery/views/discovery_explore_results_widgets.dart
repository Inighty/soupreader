import 'package:flutter/cupertino.dart';

import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/source_consistent_card.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';

/// 发现二级页结果列表中的单条卡片。
class DiscoveryExploreResultItem extends StatelessWidget {
  final SearchResult result;
  final bool inBookshelf;
  final VoidCallback onTap;

  const DiscoveryExploreResultItem({
    super.key,
    required this.result,
    required this.inBookshelf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final primaryTextColor = CupertinoColors.label.resolveFrom(context);
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final tertiaryTextColor =
        CupertinoColors.tertiaryLabel.resolveFrom(context);
    final inShelfColor = CupertinoColors.activeBlue.resolveFrom(context);
    final author = result.author.trim().isEmpty ? '未知作者' : result.author.trim();
    final lastChapter = result.lastChapter.trim();
    final intro = result.intro.trim();
    const minTapSize = SourceUiTokens.minTapSize;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SourceConsistentCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minTapSize),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCoverImage(
                  urlOrPath: result.coverUrl,
                  title: result.name,
                  author: result.author,
                  width: SourceUiTokens.discoveryResultCoverWidth,
                  height: SourceUiTokens.discoveryResultCoverHeight,
                  borderRadius: 7,
                  fit: BoxFit.cover,
                  showTextOnPlaceholder: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.copyWith(
                          fontSize: SourceUiTokens.itemTitleSize,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.copyWith(
                          fontSize: SourceUiTokens.itemMetaSize,
                          color: secondaryTextColor,
                        ),
                      ),
                      if (lastChapter.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '最新：$lastChapter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            fontSize: SourceUiTokens.itemSubMetaSize,
                            color: tertiaryTextColor,
                          ),
                        ),
                      ],
                      if (intro.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          intro,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            fontSize: SourceUiTokens.itemSubMetaSize,
                            color: tertiaryTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: minTapSize,
                  height: minTapSize,
                  child: Center(
                    child: Icon(
                      inBookshelf
                          ? CupertinoIcons.book_fill
                          : CupertinoIcons.chevron_right,
                      size: inBookshelf ? 17 : 16,
                      color: inBookshelf ? inShelfColor : secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 列表底部加载指示框（加载中）。
class DiscoveryExploreFooterLoadingBox extends StatelessWidget {
  const DiscoveryExploreFooterLoadingBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: SourceUiTokens.minTapSize),
        child: const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }
}
