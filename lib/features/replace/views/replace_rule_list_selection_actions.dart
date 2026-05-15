import '../../../core/database/repositories/replace_rule_repository.dart';
import '../models/replace_rule.dart';

/// 批量启用所选规则。
Future<void> enableSelectedReplaceRules({
  required ReplaceRuleRepository repo,
  required List<ReplaceRule> selectedRules,
}) async {
  if (selectedRules.isEmpty) return;
  final updated = selectedRules
      .map((rule) => rule.copyWith(isEnabled: true))
      .toList(growable: false);
  await repo.addRules(updated);
}

/// 批量禁用所选规则。
Future<void> disableSelectedReplaceRules({
  required ReplaceRuleRepository repo,
  required List<ReplaceRule> selectedRules,
}) async {
  if (selectedRules.isEmpty) return;
  final updated = selectedRules
      .map((rule) => rule.copyWith(isEnabled: false))
      .toList(growable: false);
  await repo.addRules(updated);
}

/// 批量置顶所选规则。
Future<void> topSelectedReplaceRules({
  required ReplaceRuleRepository repo,
  required List<ReplaceRule> selectedRules,
}) async {
  if (selectedRules.isEmpty) return;
  final allRules = repo.getAllRules();
  if (allRules.isEmpty) return;
  var minOrder = allRules.first.order;
  for (final rule in allRules.skip(1)) {
    if (rule.order < minOrder) minOrder = rule.order;
  }
  var nextOrder = minOrder - selectedRules.length;
  final updated = selectedRules.map((rule) {
    nextOrder += 1;
    return rule.copyWith(order: nextOrder);
  }).toList(growable: false);
  await repo.addRules(updated);
}

/// 批量置底所选规则。
Future<void> bottomSelectedReplaceRules({
  required ReplaceRuleRepository repo,
  required List<ReplaceRule> selectedRules,
}) async {
  if (selectedRules.isEmpty) return;
  final allRules = repo.getAllRules();
  if (allRules.isEmpty) return;
  var maxOrder = allRules.first.order;
  for (final rule in allRules.skip(1)) {
    if (rule.order > maxOrder) maxOrder = rule.order;
  }
  final updated = selectedRules.map((rule) {
    final currentOrder = maxOrder;
    maxOrder += 1;
    return rule.copyWith(order: currentOrder);
  }).toList(growable: false);
  await repo.addRules(updated);
}
