import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/widgets/app_card.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/services/source_import/selection_helper.dart';
import 'package:soupreader/features/source/views/list/import/import_custom_group_dialog.dart';
import 'package:soupreader/features/source/views/list/import/import_editor.dart';
import 'package:soupreader/features/source/views/list/actions/settings_helper.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';

export 'package:soupreader/features/source/views/list/import/import_custom_group_dialog.dart'
    show buildImportCustomGroupActionLabel;

class SourceListImportDialogs {
  const SourceListImportDialogs({
    required this.context,
    required this.sourceRepo,
    required this.settingsHelper,
  });

  final BuildContext context;
  final SourceRepository sourceRepo;
  final SourceListSettingsHelper settingsHelper;

  SourceListImportEditor get _editor => SourceListImportEditor(context: context);

  String importStateLabel(SourceImportCandidateState state) {
    return switch (state) {
      SourceImportCandidateState.newSource => '新增',
      SourceImportCandidateState.update => '更新',
      SourceImportCandidateState.existing => '已有',
    };
  }

  Color importStateColor(SourceImportCandidateState state) {
    return switch (state) {
      SourceImportCandidateState.newSource =>
        CupertinoColors.systemGreen.resolveFrom(context),
      SourceImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      SourceImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }

  Future<ImportSelectionDecision?> showImportSelectionDialog(
    List<SourceImportCandidate> candidates,
  ) {
    final dialogCandidates = candidates.toList(growable: true);
    final selectedIndexes = <int>{};
    final defaultUrls =
        SourceImportSelectionHelper.defaultSelectedUrls(dialogCandidates);
    for (var index = 0; index < dialogCandidates.length; index++) {
      if (defaultUrls.contains(dialogCandidates[index].url)) {
        selectedIndexes.add(index);
      }
    }
    var keepName = settingsHelper.settingsGetBool(
      SourceListSettingsHelper.prefImportKeepName,
      defaultValue: false,
    );
    var keepGroup = settingsHelper.settingsGetBool(
      SourceListSettingsHelper.prefImportKeepGroup,
      defaultValue: false,
    );
    var keepEnable = settingsHelper.settingsGetBool(
      SourceListSettingsHelper.prefImportKeepEnable,
      defaultValue: false,
    );
    var appendCustomGroup = false;
    var customGroupName = '';

    return showCupertinoBottomSheetDialog<ImportSelectionDecision>(
      context: context,
      builder: (popupContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCount = selectedIndexes.length;
            final totalCount = dialogCandidates.length;
            return SizedBox(
              height: math.min(MediaQuery.sizeOf(context).height * 0.86, 680),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '导入书源',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () => Navigator.pop(popupContext),
                          child: const Text('取消'),
                        ),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: selectedCount == 0
                              ? null
                              : () async {
                                  await Future.wait([
                                    settingsHelper.settingsPut(
                                      SourceListSettingsHelper.prefImportKeepName,
                                      keepName,
                                    ),
                                    settingsHelper.settingsPut(
                                      SourceListSettingsHelper.prefImportKeepGroup,
                                      keepGroup,
                                    ),
                                    settingsHelper.settingsPut(
                                      SourceListSettingsHelper.prefImportKeepEnable,
                                      keepEnable,
                                    ),
                                  ]);
                                  if (!context.mounted) return;
                                  Navigator.pop(
                                    context,
                                    ImportSelectionDecision(
                                      candidates: dialogCandidates.toList(growable: false),
                                      policy: SourceImportSelectionPolicy(
                                        selectedUrls: selectedIndexes
                                            .map((index) => dialogCandidates[index].url)
                                            .toSet(),
                                        selectedIndexes: selectedIndexes.toSet(),
                                        keepName: keepName,
                                        keepGroup: keepGroup,
                                        keepEnabled: keepEnable,
                                        customGroup: customGroupName,
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
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChipButton(
                          label: selectedIndexes.length == dialogCandidates.length
                              ? '取消全选'
                              : '全选',
                          onPressed: () {
                            setDialogState(() {
                              if (selectedIndexes.length == dialogCandidates.length) {
                                selectedIndexes.clear();
                              } else {
                                selectedIndexes
                                  ..clear()
                                  ..addAll(List<int>.generate(
                                    dialogCandidates.length,
                                    (index) => index,
                                  ));
                              }
                            });
                          },
                        ),
                        _buildChipButton(
                          label: '选中新增源',
                          onPressed: () {
                            setDialogState(() {
                              final targetIndexes = <int>{
                                for (var index = 0; index < dialogCandidates.length; index++)
                                  if (dialogCandidates[index].state ==
                                      SourceImportCandidateState.newSource)
                                    index,
                              };
                              final allSelected =
                                  targetIndexes.every(selectedIndexes.contains);
                              if (allSelected) {
                                selectedIndexes.removeWhere(targetIndexes.contains);
                              } else {
                                selectedIndexes.addAll(targetIndexes);
                              }
                            });
                          },
                        ),
                        _buildChipButton(
                          label: '选中更新源',
                          onPressed: () {
                            setDialogState(() {
                              final targetIndexes = <int>{
                                for (var index = 0; index < dialogCandidates.length; index++)
                                  if (dialogCandidates[index].state ==
                                      SourceImportCandidateState.update)
                                    index,
                              };
                              final allSelected =
                                  targetIndexes.every(selectedIndexes.contains);
                              if (allSelected) {
                                selectedIndexes.removeWhere(targetIndexes.contains);
                              } else {
                                selectedIndexes.addAll(targetIndexes);
                              }
                            });
                          },
                        ),
                        _buildChipButton(
                          label: buildImportCustomGroupActionLabel(
                            groupName: customGroupName,
                            appendGroup: appendCustomGroup,
                          ),
                          onPressed: () async {
                            final input = await showImportCustomGroupDialog(
                              context: context,
                              sourceRepo: sourceRepo,
                              initialGroupName: customGroupName,
                              initialAppendGroup: appendCustomGroup,
                            );
                            if (input == null || !popupContext.mounted) return;
                            setDialogState(() {
                              customGroupName = input.groupName;
                              appendCustomGroup = input.appendGroup;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AppCard(
                      backgroundColor: CupertinoColors.systemGrey6.resolveFrom(context),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        children: [
                          _buildPolicySwitchRow(
                            title: '保留原名',
                            value: keepName,
                            onChanged: (value) {
                              setDialogState(() => keepName = value);
                            },
                          ),
                          _buildPolicySwitchRow(
                            title: '保留分组',
                            value: keepGroup,
                            onChanged: (value) {
                              setDialogState(() => keepGroup = value);
                            },
                          ),
                          _buildPolicySwitchRow(
                            title: '保留启用状态',
                            value: keepEnable,
                            onChanged: (value) {
                              setDialogState(() => keepEnable = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Row(
                      children: [
                        Text(
                          '待导入：$selectedCount/$totalCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: dialogCandidates.length,
                      separatorBuilder: (_, __) => Container(
                        height: 0.5,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                      itemBuilder: (context, index) {
                        final candidate = dialogCandidates[index];
                        final selected = selectedIndexes.contains(index);
                        final stateColor = importStateColor(candidate.state);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setDialogState(() {
                              if (selected) {
                                selectedIndexes.remove(index);
                              } else {
                                selectedIndexes.add(index);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, right: 8),
                                  child: Icon(
                                    selected
                                        ? CupertinoIcons.check_mark_circled_solid
                                        : CupertinoIcons.circle,
                                    color: selected
                                        ? CupertinoTheme.of(context).primaryColor
                                        : CupertinoColors.systemGrey.resolveFrom(context),
                                    size: 20,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    candidate.incoming.bookSourceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 2),
                                  child: Text(
                                    importStateLabel(candidate.state),
                                    style: TextStyle(color: stateColor, fontSize: 12),
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(40, 28),
                                  onPressed: () async {
                                    final updated =
                                        await editImportCandidateRawJson(candidate: candidate);
                                    if (updated == null || !context.mounted) return;
                                    setDialogState(() {
                                      dialogCandidates[index] = updated;
                                    });
                                  },
                                  child: const Text('打开'),
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
  }

  Future<SourceImportCandidate?> editImportCandidateRawJson({
    required SourceImportCandidate candidate,
  }) =>
      _editor.editImportCandidateRawJson(candidate: candidate);

  Widget _buildPolicySwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildChipButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: CupertinoColors.systemGrey5.resolveFrom(context),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
