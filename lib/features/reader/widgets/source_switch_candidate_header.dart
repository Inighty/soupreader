import 'package:flutter/cupertino.dart';

/// 顶部 grabber + 标题/计数 + 一排操作按钮（筛选/刷新/书源管理/分组/更多/关闭）。
class SourceSwitchCandidateHeader extends StatelessWidget {
  const SourceSwitchCandidateHeader({
    super.key,
    required this.keyword,
    required this.candidateCount,
    required this.filterExpanded,
    required this.compactTapSquare,
    required this.busyOpeningSourceManage,
    required this.busyRefreshingCandidates,
    required this.busySearchingCandidates,
    required this.busyStoppingCandidates,
    required this.busyUpdatingSourceGroup,
    required this.busyAnyToggle,
    required this.showStartCandidatesSearch,
    required this.showStopCandidatesSearch,
    required this.showRefreshCandidates,
    required this.showOpenSourceManage,
    required this.showGroupAction,
    required this.showMoreButton,
    required this.groupButtonLabel,
    required this.onToggleFilter,
    required this.onStartSearch,
    required this.onStopSearch,
    required this.onRefresh,
    required this.onOpenSourceManage,
    required this.onShowGroupActions,
    required this.onShowMoreActions,
    required this.onClose,
  });

  final String keyword;
  final int candidateCount;
  final bool filterExpanded;
  final Size compactTapSquare;
  final bool busyOpeningSourceManage;
  final bool busyRefreshingCandidates;
  final bool busySearchingCandidates;
  final bool busyStoppingCandidates;
  final bool busyUpdatingSourceGroup;
  final bool busyAnyToggle;
  final bool showStartCandidatesSearch;
  final bool showStopCandidatesSearch;
  final bool showRefreshCandidates;
  final bool showOpenSourceManage;
  final bool showGroupAction;
  final bool showMoreButton;
  final String groupButtonLabel;
  final VoidCallback onToggleFilter;
  final VoidCallback onStartSearch;
  final VoidCallback onStopSearch;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSourceManage;
  final VoidCallback onShowGroupActions;
  final VoidCallback onShowMoreActions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: filterExpanded
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '换源（$keyword）',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '候选 $candidateCount 条',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              CupertinoColors.systemGrey.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
          ),
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: compactTapSquare,
                onPressed: onToggleFilter,
                child: Text(filterExpanded ? '收起' : '筛选'),
              ),
              const SizedBox(width: 12),
              if (showStartCandidatesSearch) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: compactTapSquare,
                  onPressed: (busyOpeningSourceManage ||
                          busyRefreshingCandidates ||
                          (busySearchingCandidates &&
                              !showStopCandidatesSearch) ||
                          busyStoppingCandidates)
                      ? null
                      : (busySearchingCandidates ? onStopSearch : onStartSearch),
                  child: Text(
                    busySearchingCandidates
                        ? (busyStoppingCandidates ? '停止中' : '停止')
                        : '刷新',
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (showRefreshCandidates) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: compactTapSquare,
                  onPressed: (busyRefreshingCandidates ||
                          busySearchingCandidates ||
                          busyOpeningSourceManage)
                      ? null
                      : onRefresh,
                  child: Text(busyRefreshingCandidates ? '刷新中' : '刷新列表'),
                ),
                const SizedBox(width: 12),
              ],
              if (showOpenSourceManage)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: compactTapSquare,
                  onPressed: (busyOpeningSourceManage ||
                          busyRefreshingCandidates)
                      ? null
                      : onOpenSourceManage,
                  child: const Text('书源管理'),
                ),
              const SizedBox(width: 12),
              if (showGroupAction) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: compactTapSquare,
                  onPressed: (busyOpeningSourceManage ||
                          busyRefreshingCandidates ||
                          busyUpdatingSourceGroup ||
                          busyAnyToggle)
                      ? null
                      : onShowGroupActions,
                  child: Text(groupButtonLabel),
                ),
                const SizedBox(width: 12),
              ],
              if (showMoreButton) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: compactTapSquare,
                  onPressed: (busyOpeningSourceManage ||
                          busyRefreshingCandidates ||
                          busyUpdatingSourceGroup ||
                          busyAnyToggle)
                      ? null
                      : onShowMoreActions,
                  child: const Text('更多'),
                ),
                const SizedBox(width: 12),
              ],
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: compactTapSquare,
                onPressed: onClose,
                child: const Text('关闭'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
