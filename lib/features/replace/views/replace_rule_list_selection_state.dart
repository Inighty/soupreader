// ignore_for_file: invalid_use_of_protected_member
import '../models/replace_rule.dart';
import 'replace_rule_list_view.dart';

extension ReplaceRuleListSelectionState on ReplaceRuleListViewState {
  void syncSelectionWithRules(List<ReplaceRule> rules) {
    final availableIds = rules.map((rule) => rule.id).toSet();
    selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
  }

  void toggleSelectionMode(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      selectionMode = !selectionMode;
      selectedRuleIds.clear();
    });
  }

  int selectedCountIn(List<ReplaceRule> rules) {
    var count = 0;
    for (final rule in rules) {
      if (selectedRuleIds.contains(rule.id)) count += 1;
    }
    return count;
  }

  List<ReplaceRule> selectedRulesByCurrentOrder(
    List<ReplaceRule> visibleRules,
  ) {
    if (visibleRules.isEmpty) return const <ReplaceRule>[];
    return visibleRules
        .where((rule) => selectedRuleIds.contains(rule.id))
        .toList(growable: false);
  }

  void toggleRuleSelection(int ruleId) {
    setState(() {
      if (selectedRuleIds.contains(ruleId)) {
        selectedRuleIds.remove(ruleId);
      } else {
        selectedRuleIds.add(ruleId);
      }
    });
  }

  void toggleSelectAllRules(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      final allSelected = selectedCountIn(rules) == rules.length;
      if (allSelected) {
        selectedRuleIds.removeAll(rules.map((rule) => rule.id));
        return;
      }
      selectedRuleIds.addAll(rules.map((rule) => rule.id));
    });
  }

  void revertSelection(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      for (final rule in rules) {
        if (selectedRuleIds.contains(rule.id)) {
          selectedRuleIds.remove(rule.id);
        } else {
          selectedRuleIds.add(rule.id);
        }
      }
    });
  }
}
