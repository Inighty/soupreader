import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../../app/widgets/app_empty_state.dart';
import '../services/reader_source_switch_helper.dart';

/// 候选列表（含空态）。
class SourceSwitchCandidateList extends StatelessWidget {
  const SourceSwitchCandidateList({
    super.key,
    required this.candidates,
    required this.searchQuery,
    required this.currentSourceUrl,
    required this.loadWordCountEnabled,
    required this.compactTapSquare,
    required this.hasLongPressActions,
    required this.onSelect,
    required this.onLongPress,
  });

  final List<ReaderSourceSwitchCandidate> candidates;
  final String searchQuery;
  final String currentSourceUrl;
  final bool loadWordCountEnabled;
  final Size compactTapSquare;
  final bool hasLongPressActions;
  final ValueChanged<ReaderSourceSwitchCandidate> onSelect;
  final ValueChanged<ReaderSourceSwitchCandidate> onLongPress;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return AppEmptyState(
        illustration: const AppEmptyPlanetIllustration(size: 82),
        title: searchQuery.trim().isEmpty ? '暂无候选书源' : '无匹配候选',
        message:
            searchQuery.trim().isEmpty ? '可尝试刷新列表或更换分组' : '请尝试更换筛选关键字',
      );
    }
    return ListView.separated(
      controller: ModalScrollController.of(context),
      itemCount: candidates.length,
      separatorBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 0.5,
        color: CupertinoColors.systemGrey4.resolveFrom(context),
      ),
      itemBuilder: (itemContext, index) {
        final candidate = candidates[index];
        final isCurrentSource = currentSourceUrl.isNotEmpty &&
            candidate.source.bookSourceUrl == currentSourceUrl;
        return SourceSwitchCandidateTile(
          candidate: candidate,
          isCurrentSource: isCurrentSource,
          loadWordCountEnabled: loadWordCountEnabled,
          compactTapSquare: compactTapSquare,
          onTap: () => onSelect(candidate),
          onLongPress: hasLongPressActions
              ? () => onLongPress(candidate)
              : null,
        );
      },
    );
  }
}

/// 候选行卡片：书源名 + 作者 + 最新章节 + 字数 + 响应时间。
class SourceSwitchCandidateTile extends StatelessWidget {
  const SourceSwitchCandidateTile({
    super.key,
    required this.candidate,
    required this.isCurrentSource,
    required this.loadWordCountEnabled,
    required this.compactTapSquare,
    required this.onTap,
    required this.onLongPress,
  });

  final ReaderSourceSwitchCandidate candidate;
  final bool isCurrentSource;
  final bool loadWordCountEnabled;
  final Size compactTapSquare;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final sourceName = candidate.source.bookSourceName;
    final author = candidate.book.author.trim().isEmpty
        ? '未知作者'
        : candidate.book.author.trim();
    final latestChapter = candidate.book.lastChapter.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minimumSize: compactTapSquare,
        onPressed: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sourceName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    author,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (latestChapter.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      latestChapter,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            CupertinoColors.systemGrey2.resolveFrom(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (loadWordCountEnabled &&
                      candidate.chapterWordCountText.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      candidate.chapterWordCountText.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            CupertinoColors.systemGrey2.resolveFrom(context),
                      ),
                    ),
                  ],
                  if (candidate.respondTimeMs >= 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '响应时间：${candidate.respondTimeMs} ms',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            CupertinoColors.systemGrey2.resolveFrom(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isCurrentSource)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 18,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
