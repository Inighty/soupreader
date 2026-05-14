import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/source_aware_cover_image.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart' show SearchResult;
import '../services/search_aggregator.dart';
import '../services/search_input_hint_helper.dart';
import 'search_result_item.dart';
import 'search_view_panels.dart';
import 'search_view_widgets.dart';

/// 整个搜索页主体；State 把所有状态与回调注入进来，本组件只负责装配。
class SearchViewBody extends StatelessWidget {
  const SearchViewBody({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.resultScrollController,
    required this.isSearching,
    required this.hasMore,
    required this.searchHasFocus,
    required this.searchingSource,
    required this.completedSources,
    required this.totalSources,
    required this.scopeLabel,
    required this.sourceIssueCount,
    required this.showManualLoadMorePanel,
    required this.showInputHelpPanel,
    required this.displayResults,
    required this.bookshelfHints,
    required this.historyHints,
    required this.hasQueryText,
    required this.showCover,
    required this.sourceRepo,
    required this.onTopBarChanged,
    required this.onSubmit,
    required this.onOpenScopePicker,
    required this.onCancelButton,
    required this.onCancelSearch,
    required this.onShowIssueDetails,
    required this.onContinueLoadMore,
    required this.onClearHistory,
    required this.onHistoryTap,
    required this.onHistoryLongPress,
    required this.onBookshelfTap,
    required this.onCoverState,
    required this.onOpenBookInfo,
    required this.onShowSettings,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ScrollController resultScrollController;
  final bool isSearching;
  final bool hasMore;
  final bool searchHasFocus;
  final String searchingSource;
  final int completedSources;
  final int totalSources;
  final String scopeLabel;
  final int sourceIssueCount;
  final bool showManualLoadMorePanel;
  final bool showInputHelpPanel;
  final List<SearchDisplayItem> displayResults;
  final List<Book> bookshelfHints;
  final List<String> historyHints;
  final bool hasQueryText;
  final bool showCover;
  final SourceRepository sourceRepo;
  final ValueChanged<String> onTopBarChanged;
  final VoidCallback onSubmit;
  final VoidCallback onOpenScopePicker;
  final VoidCallback onCancelButton;
  final VoidCallback onCancelSearch;
  final VoidCallback onShowIssueDetails;
  final VoidCallback onContinueLoadMore;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onHistoryTap;
  final ValueChanged<String> onHistoryLongPress;
  final ValueChanged<Book> onBookshelfTap;
  final void Function(String itemKey, SourceAwareCoverLoadState state)
      onCoverState;
  final ValueChanged<SearchResult> onOpenBookInfo;
  final VoidCallback onShowSettings;

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !SearchInputHintHelper.shouldConsumeBackToClearFocus(
        hasInputFocus: searchHasFocus,
      ),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (SearchInputHintHelper.shouldConsumeBackToClearFocus(
          hasInputFocus: searchHasFocus,
        )) {
          searchFocusNode.unfocus();
        }
      },
      child: AppCupertinoPageScaffold(
        title: '搜索',
        child: Column(
          children: [
            SearchTopBar(
              searchController: searchController,
              searchFocusNode: searchFocusNode,
              isSearching: isSearching,
              hasMore: hasMore,
              scopeLabel: scopeLabel,
              onChangedTyping: onTopBarChanged,
              onSubmit: onSubmit,
              onOpenScopePicker: onOpenScopePicker,
              onCancel: onCancelButton,
            ),
            SearchTopStatusPanels(
              isSearching: isSearching,
              searchingSource: searchingSource,
              completedSources: completedSources,
              totalSources: totalSources,
              sourceIssueCount: sourceIssueCount,
              showManualLoadMore: showManualLoadMorePanel,
              onCancelSearch: onCancelSearch,
              onShowIssueDetails: onShowIssueDetails,
              onContinueLoadMore: onContinueLoadMore,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: displayResults.isEmpty
                        ? SearchEmptyBody(
                            totalSources: totalSources,
                            isSearching: isSearching,
                            hasIssues: sourceIssueCount > 0,
                            historyHints: historyHints,
                            hasQueryText: hasQueryText,
                            onClearHistory: onClearHistory,
                            onHistoryTap: onHistoryTap,
                            onHistoryLongPress: onHistoryLongPress,
                          )
                        : ListView.builder(
                            controller: resultScrollController,
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                            itemCount: displayResults.length,
                            itemBuilder: (context, index) => SearchResultItem(
                              item: displayResults[index],
                              showCover: showCover,
                              sourceRepo: sourceRepo,
                              onCoverState: onCoverState,
                              onTap: () =>
                                  onOpenBookInfo(displayResults[index].primary),
                            ),
                          ),
                  ),
                  if (showInputHelpPanel)
                    Positioned.fill(
                      child: SearchInputHelpPanel(
                        bookshelfHints: bookshelfHints,
                        historyHints: historyHints,
                        hasQueryText: hasQueryText,
                        onClearHistory: onClearHistory,
                        onHistoryTap: onHistoryTap,
                        onHistoryLongPress: onHistoryLongPress,
                        onBookshelfTap: onBookshelfTap,
                      ),
                    ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      child: SearchFloatingSettingsButton(
                        onPressed: onShowSettings,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
