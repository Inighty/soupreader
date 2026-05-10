import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../services/rss_source_import_selection_helper.dart';
import 'rss_source_manage_types.dart';

String _importStateLabel(RssSourceImportCandidateState state) {
  return switch (state) {
    RssSourceImportCandidateState.newSource => '新增',
    RssSourceImportCandidateState.update => '更新',
    RssSourceImportCandidateState.existing => '已有',
  };
}

Color _importStateColor(
  RssSourceImportCandidateState state,
  BuildContext context,
) {
  return switch (state) {
    RssSourceImportCandidateState.newSource =>
      CupertinoColors.systemGreen.resolveFrom(context),
    RssSourceImportCandidateState.update =>
      CupertinoColors.systemOrange.resolveFrom(context),
    RssSourceImportCandidateState.existing =>
      CupertinoColors.secondaryLabel.resolveFrom(context),
  };
}

Widget _switchRow({
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 13)),
        ),
        CupertinoSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

/// 「导入RSS源」弹窗：批量勾选 + 命名/分组/启用策略 + 自定义分组。
Future<RssImportSelectionDecision?> showRssImportSelectionDialog({
  required BuildContext context,
  required List<RssSourceImportCandidate> candidates,
}) async {
  final dialogCandidates = candidates.toList(growable: false);
  final customGroupController = TextEditingController();
  final defaultSelected = RssSourceImportSelectionHelper.defaultSelectedUrls(
    dialogCandidates,
  );
  final selectedUrls = defaultSelected.toSet();
  var keepName = true;
  var keepGroup = true;
  var keepEnabled = true;
  var appendCustomGroup = false;
  try {
    return await showCupertinoBottomSheetDialog<RssImportSelectionDecision>(
      context: context,
      builder: (popupContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCount = selectedUrls.length;
            final totalCount = dialogCandidates.length;
            final allSelected =
                RssSourceImportSelectionHelper.areAllSelected(
              candidates: dialogCandidates,
              selectedUrls: selectedUrls,
            );
            return SizedBox(
              height: math.min(
                MediaQuery.sizeOf(context).height * 0.86,
                680,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '导入RSS源',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => Navigator.pop(popupContext),
                          child: const Text('取消'),
                        ),
                        CupertinoButton.filled(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: () {
                            Navigator.pop(
                              context,
                              RssImportSelectionDecision(
                                candidates: dialogCandidates,
                                policy: RssSourceImportSelectionPolicy(
                                  selectedUrls: selectedUrls.toSet(),
                                  keepName: keepName,
                                  keepGroup: keepGroup,
                                  keepEnabled: keepEnabled,
                                  customGroup:
                                      customGroupController.text,
                                  appendCustomGroup: appendCustomGroup,
                                ),
                              ),
                            );
                          },
                          child: Text('导入($selectedCount)'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          color: CupertinoColors.systemGrey5
                              .resolveFrom(context),
                          onPressed: () {
                            setDialogState(() {
                              final next = RssSourceImportSelectionHelper
                                  .toggleAllSelection(
                                candidates: dialogCandidates,
                                selectedUrls: selectedUrls,
                              );
                              selectedUrls
                                ..clear()
                                ..addAll(next);
                            });
                          },
                          child: Text(allSelected ? '取消全选' : '全选'),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$selectedCount / $totalCount',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AppCard(
                      backgroundColor:
                          CupertinoColors.systemGrey6.resolveFrom(context),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        children: [
                          _switchRow(
                            title: '保留原名',
                            value: keepName,
                            onChanged: (v) =>
                                setDialogState(() => keepName = v),
                          ),
                          _switchRow(
                            title: '保留分组',
                            value: keepGroup,
                            onChanged: (v) =>
                                setDialogState(() => keepGroup = v),
                          ),
                          _switchRow(
                            title: '保留启用状态',
                            value: keepEnabled,
                            onChanged: (v) =>
                                setDialogState(() => keepEnabled = v),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: customGroupController,
                            placeholder: '自定义分组（可选）',
                          ),
                          const SizedBox(height: 6),
                          _switchRow(
                            title: '追加到已有分组',
                            value: appendCustomGroup,
                            onChanged: (v) => setDialogState(
                                () => appendCustomGroup = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: dialogCandidates.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final candidate = dialogCandidates[index];
                        final selected =
                            selectedUrls.contains(candidate.url);
                        return GestureDetector(
                          onTap: () => setDialogState(() {
                            if (selected) {
                              selectedUrls.remove(candidate.url);
                            } else {
                              selectedUrls.add(candidate.url);
                            }
                          }),
                          child: AppCard(
                            backgroundColor: CupertinoColors.systemGrey6
                                .resolveFrom(context),
                            borderColor: selected
                                ? CupertinoColors.activeBlue
                                    .resolveFrom(context)
                                : CupertinoColors.separator
                                    .resolveFrom(context),
                            borderWidth: 0.6,
                            padding:
                                const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? CupertinoIcons
                                          .check_mark_circled_solid
                                      : CupertinoIcons.circle,
                                  size: 20,
                                  color: selected
                                      ? CupertinoColors.activeBlue
                                          .resolveFrom(context)
                                      : CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        candidate.incoming.sourceName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        candidate.url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors
                                              .secondaryLabel
                                              .resolveFrom(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _importStateLabel(candidate.state),
                                  style: TextStyle(
                                    color: _importStateColor(
                                      candidate.state,
                                      context,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  } finally {
    customGroupController.dispose();
  }
}
