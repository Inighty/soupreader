import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../models/search_scope.dart';
import 'search_view_widgets.dart';

/// 顶部搜索栏（输入框 + 范围按钮 + 取消/停止）。
class SearchTopBar extends StatelessWidget {
  const SearchTopBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.isSearching,
    required this.hasMore,
    required this.scopeLabel,
    required this.onChangedTyping,
    required this.onSubmit,
    required this.onOpenScopePicker,
    required this.onCancel,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isSearching;
  final bool hasMore;
  final String scopeLabel;
  final ValueChanged<String> onChangedTyping;
  final VoidCallback onSubmit;
  final VoidCallback onOpenScopePicker;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: AppManageSearchField(
              controller: searchController,
              focusNode: searchFocusNode,
              placeholder: '输入书名/作者，进行精准搜索书源...',
              onChanged: onChangedTyping,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: 8, right: 4),
            minimumSize: const Size(0, 32),
            onPressed: onOpenScopePicker,
            child: Text(
              scopeLabel,
              style: TextStyle(fontSize: 13, color: uiTokens.colors.accent),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: 4, right: 2),
            minimumSize: const Size(42, 32),
            onPressed: onCancel,
            child: Text(isSearching ? '停止' : '取消'),
          ),
        ],
      ),
    );
  }
}

/// 搜索中 + 失败汇总 + 「继续加载」三种状态条。
class SearchTopStatusPanels extends StatelessWidget {
  const SearchTopStatusPanels({
    super.key,
    required this.isSearching,
    required this.searchingSource,
    required this.completedSources,
    required this.totalSources,
    required this.sourceIssueCount,
    required this.showManualLoadMore,
    required this.onCancelSearch,
    required this.onShowIssueDetails,
    required this.onContinueLoadMore,
  });

  final bool isSearching;
  final String searchingSource;
  final int completedSources;
  final int totalSources;
  final int sourceIssueCount;
  final bool showManualLoadMore;
  final VoidCallback onCancelSearch;
  final VoidCallback onShowIssueDetails;
  final VoidCallback onContinueLoadMore;

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return Column(
      children: [
        if (isSearching)
          SearchStatusPanel(
            borderColor: uiTokens.colors.separator,
            child: Row(
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '正在搜索：$searchingSource ($completedSources/$totalSources)',
                    style: TextStyle(
                      fontSize: 13,
                      color: uiTokens.colors.mutedForeground,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  onPressed: onCancelSearch,
                  child: Text(
                    '停止',
                    style: TextStyle(color: uiTokens.colors.accent),
                  ),
                ),
              ],
            ),
          ),
        if (!isSearching && sourceIssueCount > 0)
          SearchStatusPanel(
            borderColor: uiTokens.colors.destructive,
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 16,
                  color: uiTokens.colors.destructive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '本次 $sourceIssueCount 个书源失败，可查看原因',
                    style: TextStyle(
                      fontSize: 12,
                      color: uiTokens.colors.destructive,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  onPressed: onShowIssueDetails,
                  child: Text(
                    '查看',
                    style: TextStyle(color: uiTokens.colors.accent),
                  ),
                ),
              ],
            ),
          ),
        if (showManualLoadMore)
          SearchStatusPanel(
            borderColor: uiTokens.colors.accent.withValues(alpha: 0.35),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_down_circle,
                  size: 16,
                  color: uiTokens.colors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '还有更多结果，可继续加载下一页',
                    style: TextStyle(
                      fontSize: 12,
                      color: uiTokens.colors.mutedForeground,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  onPressed: onContinueLoadMore,
                  child: Text(
                    '继续',
                    style: TextStyle(color: uiTokens.colors.accent),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 搜索范围 helper：把 [resolvedScope] 转成显示文本。
String resolvedScopeDisplay(SearchScopeResolveResult scope) =>
    scope.display();

/// 包一层 unawaited 让 onChanged 这种 sync 回调能触发异步。
void runAsync(Future<void> Function() task) => unawaited(task());
