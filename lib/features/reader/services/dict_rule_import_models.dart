import '../models/dict_rule.dart';

/// 导入候选项的状态：是新规则还是已存在同名规则。
enum DictRuleImportCandidateState {
  newRule,
  existing,
}

/// 字典规则导入预览中的单条候选项。
class DictRuleImportCandidate {
  const DictRuleImportCandidate({
    required this.rule,
    required this.localRule,
    required this.state,
  });

  /// 待导入规则。
  final DictRule rule;

  /// 当前本地存在的同名规则（若不存在则为 null）。
  final DictRule? localRule;

  /// 候选项状态。
  final DictRuleImportCandidateState state;

  /// 默认是否选中：仅新规则默认选中。
  bool get selectedByDefault => state == DictRuleImportCandidateState.newRule;
}
