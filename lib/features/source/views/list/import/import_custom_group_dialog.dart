import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/views/list/source_list_support.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';

/// 自定义源分组输入对话框：从导入选择面板的「自定义分组」按钮调出。
///
/// 抽离自 `import_dialogs.dart`，仅负责输入框 + 已有分组快选 + 追加开关。
Future<ImportCustomGroupInput?> showImportCustomGroupDialog({
  required BuildContext context,
  required SourceRepository sourceRepo,
  required String initialGroupName,
  required bool initialAppendGroup,
}) async {
  final controller = TextEditingController(text: initialGroupName.trim());
  final allGroups = SourceListSupport.buildGroups(
    SourceListSupport.normalizeSources(sourceRepo.getAllSources()),
  );
  var appendGroup = initialAppendGroup;
  try {
    return showCupertinoBottomSheetDialog<ImportCustomGroupInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = controller.text.trim().toLowerCase();
          final quickGroups = allGroups
              .where(
                  (group) => query.isEmpty || group.toLowerCase().contains(query))
              .take(12)
              .toList(growable: false);
          return CupertinoAlertDialog(
            title: const Text('输入自定义源分组名称'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: controller,
                  placeholder: '分组名',
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (quickGroups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: math.min(quickGroups.length * 34.0, 118),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: quickGroups.map((group) {
                            return CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 26),
                              onPressed: () {
                                controller.value = TextEditingValue(
                                  text: group,
                                  selection: TextSelection.collapsed(
                                      offset: group.length),
                                );
                                setDialogState(() {});
                              },
                              child: Text(group,
                                  style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text('追加分组', style: TextStyle(fontSize: 14)),
                    ),
                    CupertinoSwitch(
                      value: appendGroup,
                      onChanged: (value) {
                        setDialogState(() => appendGroup = value);
                      },
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
                    ImportCustomGroupInput(
                      groupName: controller.text.trim(),
                      appendGroup: appendGroup,
                    ),
                  );
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// 顶部「自定义分组」chip 上的展示文案。
String buildImportCustomGroupActionLabel({
  required String groupName,
  required bool appendGroup,
}) {
  final normalized = groupName.trim();
  if (normalized.isEmpty) return '自定义源分组';
  return appendGroup ? '+【$normalized】' : '【$normalized】';
}
