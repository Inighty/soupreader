import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_sheet_panel.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../services/reader_source_switch_helper.dart';
import 'source_switch_candidate_controller.dart';
import 'source_switch_candidate_header.dart';
import 'source_switch_candidate_show.dart';
import 'source_switch_candidate_tile.dart';

export 'source_switch_candidate_show.dart'
    show
        showSourceSwitchCandidateSheet,
        SourceSwitchCandidatesUpdater,
        SourceSwitchCandidatesListUpdater;

class SourceSwitchCandidateSheet extends StatefulWidget {
  const SourceSwitchCandidateSheet({
    super.key,
    required this.keyword,
    this.currentSourceUrl = '',
    required this.candidates,
    this.changeSourceGroup = '',
    this.sourceGroups = const <String>[],
    this.authorKeyword = '',
    this.checkAuthorEnabled = false,
    this.loadInfoEnabled = false,
    this.loadWordCountEnabled = false,
    required this.loadTocEnabled,
    this.changeSourceDelaySeconds = 0,
    this.onCheckAuthorChanged,
    this.onLoadInfoChanged,
    this.onLoadWordCountChanged,
    this.onLoadTocChanged,
    this.onChangeSourceDelayChanged,
    this.onChangeSourceGroupChanged,
    this.onOpenSourceManage,
    this.onStartCandidatesSearch,
    this.onStopCandidatesSearch,
    this.onRefreshCandidates,
    this.onTopSourceCandidate,
    this.onEditSourceCandidate,
    this.onBottomSourceCandidate,
    this.onDisableSourceCandidate,
    this.onDeleteSourceCandidate,
    this.confirmDeleteSourceCandidate = false,
  });

  final String keyword;
  final String currentSourceUrl;
  final List<ReaderSourceSwitchCandidate> candidates;
  final String changeSourceGroup;
  final List<String> sourceGroups;
  final String authorKeyword;
  final bool checkAuthorEnabled;
  final bool loadInfoEnabled;
  final bool loadWordCountEnabled;
  final bool loadTocEnabled;
  final int changeSourceDelaySeconds;
  final Future<void> Function(bool enabled)? onCheckAuthorChanged;
  final Future<void> Function(bool enabled)? onLoadInfoChanged;
  final Future<void> Function(bool enabled)? onLoadWordCountChanged;
  final Future<void> Function(bool enabled)? onLoadTocChanged;
  final Future<void> Function(int seconds)? onChangeSourceDelayChanged;
  final Future<void> Function(String group)? onChangeSourceGroupChanged;
  final Future<void> Function()? onOpenSourceManage;
  final SourceSwitchCandidatesListUpdater? onStartCandidatesSearch;
  final Future<void> Function()? onStopCandidatesSearch;
  final SourceSwitchCandidatesListUpdater? onRefreshCandidates;
  final SourceSwitchCandidatesUpdater? onTopSourceCandidate;
  final SourceSwitchCandidatesUpdater? onEditSourceCandidate;
  final SourceSwitchCandidatesUpdater? onBottomSourceCandidate;
  final SourceSwitchCandidatesUpdater? onDisableSourceCandidate;
  final SourceSwitchCandidatesUpdater? onDeleteSourceCandidate;
  final bool confirmDeleteSourceCandidate;

  @override
  State<SourceSwitchCandidateSheet> createState() =>
      _SourceSwitchCandidateSheetState();
}

class _SourceSwitchCandidateSheetState
    extends State<SourceSwitchCandidateSheet> {
  late final SourceSwitchCandidateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SourceSwitchCandidateController(widget);
  }

  @override
  void didUpdateWidget(covariant SourceSwitchCandidateSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.updateWidget(widget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _SourceSwitchCandidateBody(
        controller: _controller,
        widget: widget,
      ),
    );
  }
}

class _SourceSwitchCandidateBody extends StatelessWidget {
  const _SourceSwitchCandidateBody({
    required this.controller,
    required this.widget,
  });

  final SourceSwitchCandidateController controller;
  final SourceSwitchCandidateSheet widget;

  @override
  Widget build(BuildContext context) {
    final compactTapSquare =
        AppUiTokens.resolve(context).sizes.compactTapSquare;
    final size = MediaQuery.sizeOf(context);
    final filtered = controller.filteredCandidates;
    final showCheckAuthorAction = widget.onCheckAuthorChanged != null;
    final showLoadInfoAction = widget.onLoadInfoChanged != null;
    final showLoadWordCountAction = widget.onLoadWordCountChanged != null;
    final showGroupAction = widget.onChangeSourceGroupChanged != null;
    final groupButtonLabel = controller.changeSourceGroup.isEmpty
        ? '分组'
        : '分组(${controller.changeSourceGroup})';
    final showMoreButton = widget.onLoadTocChanged != null ||
        widget.onChangeSourceDelayChanged != null ||
        showCheckAuthorAction ||
        showLoadInfoAction ||
        showLoadWordCountAction;

    return SizedBox(
      height: size.height * 0.8,
      child: AppSheetPanel(
        contentPadding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CupertinoColors.separator.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SourceSwitchCandidateHeader(
                keyword: widget.keyword,
                candidateCount: controller.candidates.length,
                filterExpanded: controller.filterExpanded,
                compactTapSquare: compactTapSquare,
                busyOpeningSourceManage: controller.openingSourceManage,
                busyRefreshingCandidates: controller.refreshingCandidates,
                busySearchingCandidates: controller.searchingCandidates,
                busyStoppingCandidates: controller.stoppingCandidates,
                busyUpdatingSourceGroup: controller.updatingSourceGroup,
                busyAnyToggle: controller.anyToggleBusy,
                showStartCandidatesSearch:
                    widget.onStartCandidatesSearch != null,
                showStopCandidatesSearch:
                    widget.onStopCandidatesSearch != null,
                showRefreshCandidates: widget.onRefreshCandidates != null,
                showOpenSourceManage: widget.onOpenSourceManage != null,
                showGroupAction: showGroupAction,
                showMoreButton: showMoreButton,
                groupButtonLabel: groupButtonLabel,
                onToggleFilter: controller.filterExpanded
                    ? controller.collapseFilter
                    : controller.openFilter,
                onStartSearch: controller.handleStartCandidatesSearch,
                onStopSearch: controller.handleStopCandidatesSearch,
                onRefresh: controller.handleRefreshCandidates,
                onOpenSourceManage: controller.handleOpenSourceManage,
                onShowGroupActions: () => controller.showGroupActions(context),
                onShowMoreActions: () => controller.showMoreActions(context),
                onClose: () => Navigator.of(context).pop(),
              ),
              if (controller.filterExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: AppManageSearchField(
                    controller: controller.queryController,
                    focusNode: controller.queryFocusNode,
                    placeholder: '筛选',
                  ),
                ),
              Expanded(
                child: SourceSwitchCandidateList(
                  candidates: filtered,
                  searchQuery: controller.query,
                  currentSourceUrl: widget.currentSourceUrl,
                  loadWordCountEnabled: controller.loadWordCountEnabled,
                  compactTapSquare: compactTapSquare,
                  hasLongPressActions: widget.onTopSourceCandidate != null ||
                      widget.onEditSourceCandidate != null ||
                      widget.onBottomSourceCandidate != null ||
                      widget.onDisableSourceCandidate != null ||
                      widget.onDeleteSourceCandidate != null,
                  onSelect: (candidate) =>
                      Navigator.of(context).pop(candidate),
                  onLongPress: (candidate) =>
                      controller.showCandidateActions(context, candidate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
