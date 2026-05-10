import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../services/reader_source_switch_helper.dart';
import 'source_switch_candidate_sheet.dart';

typedef SourceSwitchCandidatesUpdater
    = Future<List<ReaderSourceSwitchCandidate>> Function(
  ReaderSourceSwitchCandidate candidate,
  List<ReaderSourceSwitchCandidate> currentCandidates,
);

typedef SourceSwitchCandidatesListUpdater
    = Future<List<ReaderSourceSwitchCandidate>> Function(
  List<ReaderSourceSwitchCandidate> currentCandidates,
);

/// 顶层入口：弹出换源候选 sheet 并等待用户选择。
Future<ReaderSourceSwitchCandidate?> showSourceSwitchCandidateSheet({
  required BuildContext context,
  required String keyword,
  required List<ReaderSourceSwitchCandidate> candidates,
  String currentSourceUrl = '',
  String changeSourceGroup = '',
  List<String> sourceGroups = const <String>[],
  String authorKeyword = '',
  bool checkAuthorEnabled = false,
  bool loadInfoEnabled = false,
  bool loadWordCountEnabled = false,
  bool loadTocEnabled = false,
  int changeSourceDelaySeconds = 0,
  Future<void> Function(bool enabled)? onCheckAuthorChanged,
  Future<void> Function(bool enabled)? onLoadInfoChanged,
  Future<void> Function(bool enabled)? onLoadWordCountChanged,
  Future<void> Function(bool enabled)? onLoadTocChanged,
  Future<void> Function(int seconds)? onChangeSourceDelayChanged,
  Future<void> Function(String group)? onChangeSourceGroupChanged,
  Future<void> Function()? onOpenSourceManage,
  SourceSwitchCandidatesListUpdater? onStartCandidatesSearch,
  Future<void> Function()? onStopCandidatesSearch,
  SourceSwitchCandidatesListUpdater? onRefreshCandidates,
  SourceSwitchCandidatesUpdater? onTopSourceCandidate,
  SourceSwitchCandidatesUpdater? onEditSourceCandidate,
  SourceSwitchCandidatesUpdater? onBottomSourceCandidate,
  SourceSwitchCandidatesUpdater? onDisableSourceCandidate,
  SourceSwitchCandidatesUpdater? onDeleteSourceCandidate,
  bool confirmDeleteSourceCandidate = false,
}) {
  return showCupertinoBottomSheetDialog<ReaderSourceSwitchCandidate>(
    context: context,
    builder: (_) => SourceSwitchCandidateSheet(
      keyword: keyword,
      currentSourceUrl: currentSourceUrl,
      candidates: candidates,
      changeSourceGroup: changeSourceGroup,
      sourceGroups: sourceGroups,
      authorKeyword: authorKeyword,
      checkAuthorEnabled: checkAuthorEnabled,
      loadInfoEnabled: loadInfoEnabled,
      loadWordCountEnabled: loadWordCountEnabled,
      loadTocEnabled: loadTocEnabled,
      changeSourceDelaySeconds: changeSourceDelaySeconds,
      onCheckAuthorChanged: onCheckAuthorChanged,
      onLoadInfoChanged: onLoadInfoChanged,
      onLoadWordCountChanged: onLoadWordCountChanged,
      onLoadTocChanged: onLoadTocChanged,
      onChangeSourceDelayChanged: onChangeSourceDelayChanged,
      onChangeSourceGroupChanged: onChangeSourceGroupChanged,
      onOpenSourceManage: onOpenSourceManage,
      onStartCandidatesSearch: onStartCandidatesSearch,
      onStopCandidatesSearch: onStopCandidatesSearch,
      onRefreshCandidates: onRefreshCandidates,
      onTopSourceCandidate: onTopSourceCandidate,
      onEditSourceCandidate: onEditSourceCandidate,
      onBottomSourceCandidate: onBottomSourceCandidate,
      onDisableSourceCandidate: onDisableSourceCandidate,
      onDeleteSourceCandidate: onDeleteSourceCandidate,
      confirmDeleteSourceCandidate: confirmDeleteSourceCandidate,
    ),
  );
}
