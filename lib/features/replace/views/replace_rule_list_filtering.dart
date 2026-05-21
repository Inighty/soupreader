// ignore_for_file: invalid_use_of_protected_member
import '../../search/models/search_scope_group_helper.dart';
import '../models/replace_rule.dart';
import 'replace_rule_list_view.dart';

extension ReplaceRuleListFiltering on ReplaceRuleListViewState {
  List<String> buildGroups(List<ReplaceRule> rules) {
    final groups = <String>{};
    for (final rule in rules) {
      final raw = rule.group?.trim();
      if (raw == null || raw.isEmpty) continue;
      for (final part
          in raw.split(ReplaceRuleListViewState.groupSplitPattern)) {
        final group = part.trim();
        if (group.isEmpty) continue;
        groups.add(group);
      }
    }
    final sorted = groups.toList(growable: false)
      ..sort(SearchScopeGroupHelper.cnCompareLikeLegado);
    return sorted;
  }

  String resolveActiveGroupQuery(List<String> groups) {
    if (activeGroupQuery == ReplaceRuleListViewState.groupFilterAll ||
        activeGroupQuery == ReplaceRuleListViewState.groupFilterNoGroup) {
      return activeGroupQuery;
    }
    if (groups.contains(activeGroupQuery)) return activeGroupQuery;
    return ReplaceRuleListViewState.groupFilterAll;
  }

  List<ReplaceRule> filterRulesByGroupQuery(
    List<ReplaceRule> rules,
    String query,
  ) {
    if (query == ReplaceRuleListViewState.groupFilterAll) return rules;
    if (query == ReplaceRuleListViewState.groupFilterNoGroup) {
      return rules.where(_isNoGroupRule).toList(growable: false);
    }
    return rules
        .where((rule) => _containsLikeLegacy(rule.group ?? '', query))
        .toList(growable: false);
  }

  /// 对齐 legado ReplaceRuleActivity.observeReplaceRuleData：
  /// 1) `未分组` -> flowNoGroup
  /// 2) `group:xxx` -> flowGroupSearch("%xxx%")
  /// 3) 其它关键字 -> flowSearch("%key%")（name/group 联合搜索）
  List<ReplaceRule> filterRulesBySearchQueryLikeLegado(
    List<ReplaceRule> rules,
    String query,
  ) {
    final raw = query.trim();
    if (raw.isEmpty) return rules;
    if (raw == ReplaceRuleListViewState.noGroupLabel) {
      return rules.where(_isNoGroupRule).toList(growable: false);
    }
    if (raw.startsWith('group:')) {
      final key = raw.substring(6).trim();
      return rules.where((rule) {
        final group = rule.group;
        if (group == null) return false;
        if (key.isEmpty) return true;
        return _containsLikeLegacy(group, key);
      }).toList(growable: false);
    }
    return rules.where((rule) {
      final group = rule.group ?? '';
      return _containsLikeLegacy(group, raw) ||
          _containsLikeLegacy(rule.name, raw);
    }).toList(growable: false);
  }

  void onSearchQueryChanged(String value) {
    setState(() {
      searchQuery = value;
      selectedRuleIds.clear();
    });
  }

  void applyGroupQuery(String query) {
    setState(() {
      activeGroupQuery = query;
      searchQuery = '';
      selectedRuleIds.clear();
    });
    if (searchController.text.isNotEmpty) {
      searchController.clear();
    }
  }
}

bool _containsLikeLegacy(String text, String key) {
  final normalizedKey = key.trim();
  if (normalizedKey.isEmpty) return true;
  return text.toLowerCase().contains(normalizedKey.toLowerCase());
}

bool _isNoGroupRule(ReplaceRule rule) {
  final raw = rule.group;
  if (raw == null) return true;
  final text = raw.trim();
  if (text.isEmpty) return true;
  return text.contains(ReplaceRuleListViewState.noGroupLabel);
}
