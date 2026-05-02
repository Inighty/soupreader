import '../services/rss_source_import_selection_helper.dart';

/// RSS 导入选择决议结果。
class RssImportSelectionDecision {
  const RssImportSelectionDecision({
    required this.candidates,
    required this.policy,
  });

  final List<RssSourceImportCandidate> candidates;
  final RssSourceImportSelectionPolicy policy;
}

/// 主菜单动作（新建 / 导入）。
enum RssSourceMainMenuAction {
  create,
  importFile,
  importUrl,
  importQr,
  importDefault,
}

/// 选择模式下的批量动作。
enum RssSourceSelectionAction {
  enableSelection,
  disableSelection,
  addGroup,
  removeGroup,
  moveToTop,
  moveToBottom,
  exportSelection,
  shareSelection,
  checkSelectedInterval,
}

/// 单条目右键/长按菜单动作。
enum RssSourceItemAction {
  moveToTop,
  moveToBottom,
  delete,
}

/// 分组菜单决议：是打开管理页还是过滤当前列表。
typedef RssGroupMenuDecision = ({bool openManage, String? query});
