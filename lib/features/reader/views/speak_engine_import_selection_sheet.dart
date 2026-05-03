import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../services/http_tts_rule_store.dart';
import 'speak_engine_manage_widgets.dart';

/// 弹出待导入候选规则的多选面板，返回用户最终选中的索引集合。
///
/// 用户点击取消 / 关闭对话框时返回 `null`；点击「导入」但未选时返回 `null`。
Future<Set<int>?> showSpeakEngineImportSelectionSheet({
  required BuildContext context,
  required List<HttpTtsImportCandidate> candidates,
}) async {
  final selectedIndexes = <int>{
    for (var index = 0; index < candidates.length; index++)
      if (candidates[index].selectedByDefault) index,
  };
  return showCupertinoBottomSheetDialog<Set<int>>(
    context: context,
    builder: (popupContext) {
      return CupertinoPopupSurface(
        isSurfacePainted: true,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCount = selectedIndexes.length;
            final totalCount = candidates.length;
            final allSelected = totalCount > 0 && selectedCount == totalCount;
            final toggleAllLabel = allSelected
                ? '取消全选($selectedCount/$totalCount)'
                : '全选($selectedCount/$totalCount)';
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
                            '导入朗读引擎',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
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
                              : () => Navigator.pop(
                                    popupContext,
                                    selectedIndexes.toSet(),
                                  ),
                          child: Text('导入($selectedCount)'),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        color:
                            CupertinoColors.systemGrey5.resolveFrom(context),
                        onPressed: () {
                          setDialogState(() {
                            if (allSelected) {
                              selectedIndexes.clear();
                            } else {
                              selectedIndexes
                                ..clear()
                                ..addAll(
                                  List<int>.generate(
                                    candidates.length,
                                    (index) => index,
                                  ),
                                );
                            }
                          });
                        },
                        child: Text(toggleAllLabel),
                      ),
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
                        return ImportCandidateTile(
                          candidate: candidate,
                          selected: selected,
                          onTap: () {
                            setDialogState(() {
                              if (selected) {
                                selectedIndexes.remove(index);
                              } else {
                                selectedIndexes.add(index);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
