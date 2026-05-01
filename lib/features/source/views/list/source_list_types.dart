import 'package:flutter/cupertino.dart';

import 'package:soupreader/features/source/models/book_source.dart';

enum SourceSortMode {
  manual,
  weight,
  name,
  url,
  update,
  respond,
  enabled,
}

typedef SourceSortModeLabelBuilder = String Function(SourceSortMode mode);
typedef SourceSortChanged = void Function(SourceSortMode mode, bool ascending);
typedef SourceGroupManageCallback = void Function(BuildContext sheetContext);
typedef SourceGroupToggleCallback = void Function(BuildContext sheetContext);
typedef SourceGroupApplyQueryCallback = void Function(
  String query,
  BuildContext sheetContext,
);
typedef SourceMoveSourcesHandler = Future<void> Function(
  List<BookSource> sources, {
  required bool toTop,
});

enum SourceMainMenuAction {
  sort,
  groupFilter,
  create,
  importFile,
  importUrl,
  importQr,
  help,
}

enum SourceItemAction {
  toTop,
  toBottom,
  toggleEnabled,
  login,
  search,
  debug,
  delete,
  share,
  toggleExplore,
}

enum SourceBatchAction {
  enableSelected,
  disableSelected,
  addGroup,
  removeGroup,
  enableExplore,
  disableExplore,
  moveToTop,
  moveToBottom,
  exportSelected,
  shareSelected,
  checkSelected,
  selectInterval,
}

class ImportSelectionDecision {
  const ImportSelectionDecision({
    required this.candidates,
    required this.policy,
  });

  final List<SourceImportCandidate> candidates;
  final SourceImportSelectionPolicy policy;
}

class ImportCustomGroupInput {
  const ImportCustomGroupInput({
    required this.groupName,
    required this.appendGroup,
  });

  final String groupName;
  final bool appendGroup;
}

class SourceCheckSettings {
  const SourceCheckSettings({
    required this.timeoutMs,
    required this.checkSearch,
    required this.checkDiscovery,
    required this.checkInfo,
    required this.checkCategory,
    required this.checkContent,
  });

  final int timeoutMs;
  final bool checkSearch;
  final bool checkDiscovery;
  final bool checkInfo;
  final bool checkCategory;
  final bool checkContent;
}
