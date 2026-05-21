// ignore_for_file: invalid_use_of_protected_member
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../models/replace_rule.dart';
import 'replace_rule_list_actions.dart';
import 'replace_rule_list_bulk_actions.dart';
import 'replace_rule_list_filtering.dart';
import 'replace_rule_list_group_actions.dart';
import 'replace_rule_list_selection_state.dart';
import 'replace_rule_list_view.dart';
import 'replace_rule_list_widgets.dart';

extension ReplaceRuleListBody on ReplaceRuleListViewState {
  Widget buildRuleList(
    BuildContext context,
    AsyncSnapshot<List<ReplaceRule>> snapshot,
  ) {
    final allRules = List<ReplaceRule>.from(
      snapshot.data ?? repo.getAllRules(),
    )..sort((a, b) => a.order.compareTo(b.order));
    if (dataInited && snapshot.hasData) markChanged();
    dataInited = true;
    syncSelectionWithRules(allRules);

    final groups = buildGroups(allRules);
    final activeGroupQuery = resolveActiveGroupQuery(groups);
    final normalizedSearchQuery = searchQuery.trim();
    final rules = normalizedSearchQuery.isEmpty
        ? filterRulesByGroupQuery(allRules, activeGroupQuery)
        : filterRulesBySearchQueryLikeLegado(allRules, normalizedSearchQuery);
    final selectedCount = selectedCountIn(rules);

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(changed);
      },
      child: AppCupertinoPageScaffold(
        title: '文本替换规则',
        trailing: _buildTopBar(allRules, rules, selectedCount),
        child: _buildContent(rules, selectedCount),
      ),
    );
  }

  Widget _buildTopBar(
    List<ReplaceRule> allRules,
    List<ReplaceRule> visibleRules,
    int selectedCount,
  ) {
    final hasSelection = selectedCount > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppNavBarButton(
          onPressed: menuBusy ? null : () => showGroupFilterOptions(allRules),
          child: const Icon(CupertinoIcons.square_grid_2x2),
        ),
        AppNavBarButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          onPressed: menuBusy || (!selectionMode && allRules.isEmpty)
              ? null
              : () => toggleSelectionMode(allRules),
          child: Text(
            selectionMode ? '完成' : '多选',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        _buildMoreButton(visibleRules, hasSelection),
      ],
    );
  }

  Widget _buildMoreButton(List<ReplaceRule> visibleRules, bool hasSelection) {
    final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return AppNavBarButton(
      key: moreMenuKey,
      onPressed: selectionMode
          ? (hasSelection && !menuBusy
              ? () => showSelectionMoreMenu(visibleRules)
              : null)
          : (menuBusy ? null : showMoreMenu),
      child: selectionMode
          ? _buildSelectionMoreIcon(hasSelection, enabledColor, disabledColor)
          : _buildNormalMoreIcon(),
    );
  }

  Widget _buildSelectionMoreIcon(
    bool hasSelection,
    Color enabledColor,
    Color disabledColor,
  ) {
    if (selectionActionBusy) {
      return const CupertinoActivityIndicator(radius: 9);
    }
    return Icon(
      CupertinoIcons.ellipsis_circle,
      color: hasSelection ? enabledColor : disabledColor,
    );
  }

  Widget _buildNormalMoreIcon() {
    if (menuBusy) return const CupertinoActivityIndicator(radius: 9);
    return const Icon(CupertinoIcons.ellipsis);
  }

  Widget _buildContent(List<ReplaceRule> rules, int selectedCount) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: AppManageSearchField(
            controller: searchController,
            placeholder: '替换净化搜索',
            onChanged: onSearchQueryChanged,
          ),
        ),
        Expanded(child: rules.isEmpty ? empty() : buildList(rules)),
        if (selectionMode) _buildSelectionBar(rules, selectedCount),
      ],
    );
  }

  Widget _buildSelectionBar(List<ReplaceRule> rules, int selectedCount) {
    return ReplaceRuleSelectionBar(
      selectedCount: selectedCount,
      totalCount: rules.length,
      menuBusy: menuBusy,
      selectionActionBusy: selectionActionBusy,
      deletingSelection: deletingSelection,
      onToggleAll: () => toggleSelectAllRules(rules),
      onInvert: () => revertSelection(rules),
      onConfirmDelete: () => confirmDeleteSelectedRules(rules),
      onShowMore: () => showSelectionMoreMenu(rules),
    );
  }
}
