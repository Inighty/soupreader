import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'replace_rule_import_types.dart';

String _buildImportGroupActionLabel({
  required String groupName,
  required bool appendGroup,
}) {
  final normalized = groupName.trim();
  if (normalized.isEmpty) return '自定义源分组';
  final title = '【$normalized】';
  return appendGroup ? '+$title' : title;
}

Future<ReplaceRuleImportGroupInput?> showReplaceRuleImportCustomGroupDialog({
  required BuildContext context,
  required String initialGroupName,
  required bool initialAppendGroup,
}) async {
  final controller = TextEditingController(text: initialGroupName.trim());
  var appendGroup = initialAppendGroup;
  try {
    return showCupertinoBottomSheetDialog<ReplaceRuleImportGroupInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('输入自定义源分组名称'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: controller,
                placeholder: '分组名',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child:
                        Text('追加分组', style: TextStyle(fontSize: 14)),
                  ),
                  CupertinoSwitch(
                    value: appendGroup,
                    onChanged: (value) =>
                        setDialogState(() => appendGroup = value),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  ReplaceRuleImportGroupInput(
                    groupName: controller.text.trim(),
                    appendGroup: appendGroup,
                  ),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// 「导入替换规则」选择对话框：复选 + 自定义源分组。
Future<ReplaceRuleImportSelectionDecision?>
    showReplaceRuleImportSelectionSheet({
  required BuildContext context,
  required List<ReplaceRuleImportCandidate> candidates,
}) async {
  final selectedIndexes = <int>{
    for (var index = 0; index < candidates.length; index++)
      if (candidates[index].selectedByDefault) index,
  };
  var customGroupName = '';
  var appendCustomGroup = false;
  return showCupertinoBottomSheetDialog<ReplaceRuleImportSelectionDecision>(
    context: context,
    builder: (popupContext) => CupertinoPopupSurface(
      isSurfacePainted: true,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedCount = selectedIndexes.length;
          final totalCount = candidates.length;
          final allSelected = totalCount > 0 && selectedCount == totalCount;
          final toggleAllLabel = allSelected
              ? '取消全选（$selectedCount/$totalCount）'
              : '全选（$selectedCount/$totalCount）';
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
                          '导入替换规则',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
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
                        onPressed: selectedCount == 0
                            ? null
                            : () => Navigator.pop(
                                  popupContext,
                                  ReplaceRuleImportSelectionDecision(
                                    selectedIndexes: selectedIndexes.toSet(),
                                    groupPolicy: ReplaceRuleImportGroupPolicy(
                                      groupName: customGroupName,
                                      appendGroup: appendCustomGroup,
                                    ),
                                  ),
                                ),
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
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        color: CupertinoColors.systemGrey5
                            .resolveFrom(context),
                        onPressed: () {
                          setDialogState(() {
                            if (allSelected) {
                              selectedIndexes.clear();
                            } else {
                              selectedIndexes
                                ..clear()
                                ..addAll(List<int>.generate(
                                    candidates.length, (index) => index));
                            }
                          });
                        },
                        child: Text(toggleAllLabel),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        color: CupertinoColors.systemGrey5
                            .resolveFrom(context),
                        onPressed: () async {
                          final input =
                              await showReplaceRuleImportCustomGroupDialog(
                            context: context,
                            initialGroupName: customGroupName,
                            initialAppendGroup: appendCustomGroup,
                          );
                          if (input == null || !popupContext.mounted) return;
                          setDialogState(() {
                            customGroupName = input.groupName;
                            appendCustomGroup = input.appendGroup;
                          });
                        },
                        child: Text(_buildImportGroupActionLabel(
                          groupName: customGroupName,
                          appendGroup: appendCustomGroup,
                        )),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: candidates.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final selected = selectedIndexes.contains(index);
                      return ReplaceRuleImportCandidateTile(
                        candidate: candidate,
                        selected: selected,
                        onTap: () => setDialogState(() {
                          if (selected) {
                            selectedIndexes.remove(index);
                          } else {
                            selectedIndexes.add(index);
                          }
                        }),
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
