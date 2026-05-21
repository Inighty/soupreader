import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_empty_state.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/online_import_history_store.dart';
import '../models/replace_rule.dart';
import '../services/replace_rule_import_export_service.dart';
import 'replace_rule_edit_view.dart';
import 'replace_rule_list_actions.dart';
import 'replace_rule_list_body.dart';
import 'replace_rule_list_message_dialogs.dart';
import 'replace_rule_list_selection_state.dart';
import 'replace_rule_list_widgets.dart';

class ReplaceRuleListView extends StatefulWidget {
  const ReplaceRuleListView({super.key});

  @override
  State<ReplaceRuleListView> createState() => ReplaceRuleListViewState();
}

enum ReplaceRuleTopMenuAction {
  create,
  importFile,
  importUrl,
  importQr,
  help,
}

class ReplaceRuleListViewState extends State<ReplaceRuleListView> {
  static const String onlineImportHistoryKey = 'replaceRuleRecordKey';
  static const String groupFilterAll = '';
  static const String groupFilterNoGroup = '__no_group__';
  static const String noGroupLabel = '未分组';
  static final RegExp groupSplitPattern = RegExp(r'[,;，；]');

  late final ReplaceRuleRepository repo;
  final GlobalKey moreMenuKey = GlobalKey();
  final ReplaceRuleImportExportService io = ReplaceRuleImportExportService();
  final TextEditingController searchController = TextEditingController();
  final OnlineImportHistoryStore onlineImportHistoryStore =
      OnlineImportHistoryStore();

  String activeGroupQuery = groupFilterAll;
  String searchQuery = '';
  bool changed = false;
  bool dataInited = false;
  bool importingLocal = false;
  bool importingOnline = false;
  bool importingQr = false;
  bool exportingSelection = false;
  bool enablingSelection = false;
  bool disablingSelection = false;
  bool toppingSelection = false;
  bool bottomingSelection = false;
  bool deletingSelection = false;
  bool selectionMode = false;
  final Set<int> selectedRuleIds = <int>{};

  bool get selectionUpdating =>
      enablingSelection ||
      disablingSelection ||
      toppingSelection ||
      bottomingSelection;

  bool get selectionActionBusy =>
      exportingSelection || selectionUpdating || deletingSelection;

  bool get menuBusy =>
      importingLocal ||
      importingOnline ||
      importingQr ||
      exportingSelection ||
      selectionUpdating ||
      deletingSelection;

  @override
  void initState() {
    super.initState();
    repo = ReplaceRuleRepository(DatabaseService());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void markChanged() {
    if (!changed) setState(() => changed = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReplaceRule>>(
      stream: repo.watchAllRules(),
      builder: buildRuleList,
    );
  }

  void recordViewError({
    required String node,
    required String message,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
  }) {
    ExceptionLogService().record(
      node: node,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
    debugPrint('[replace-rule] $node failed: $error');
  }

  Widget empty() {
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 86),
      title: '暂无规则',
      message: '可通过新建或导入创建替换净化规则',
      action: CupertinoButton.filled(
        onPressed: createRule,
        child: const Text('新建规则'),
      ),
    );
  }

  Widget buildList(List<ReplaceRule> rules) {
    return ReplaceRuleListItems(
      rules: rules,
      selectedRuleIds: selectedRuleIds,
      selectionMode: selectionMode,
      onToggleSelection: toggleRuleSelection,
      onUpdateRule: (r) => repo.updateRule(r),
      onEditRule: editRule,
      onShowRuleItemMenu: showRuleItemMenu,
    );
  }

  void createRule() {
    editRule(ReplaceRule.create());
  }

  int _nextReplaceRuleOrder() {
    var maxOrder = ReplaceRule.unsetOrder;
    for (final rule in repo.getAllRules()) {
      if (rule.order > maxOrder) {
        maxOrder = rule.order;
      }
    }
    return maxOrder + 1;
  }

  ReplaceRule _normalizeRuleForSave(ReplaceRule rule) {
    if (rule.order != ReplaceRule.unsetOrder) {
      return rule;
    }
    return rule.copyWith(order: _nextReplaceRuleOrder());
  }

  void editRule(ReplaceRule rule) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReplaceRuleEditView(
          initial: rule,
          onSave: (next) async {
            await repo.addRule(_normalizeRuleForSave(next));
          },
        ),
      ),
    );
  }

  Future<void> showMessageDialog({
    required String title,
    required String message,
  }) =>
      showReplaceRuleMessageDialog(
          context: context, title: title, message: message);
}
