import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

/// 「网络导入」输入面板：URL 输入 + 历史记录列表。
Future<String?> showReplaceRuleOnlineImportSheet({
  required BuildContext context,
  required Future<List<String>> Function() loadHistory,
  required Future<void> Function(List<String> next) saveHistory,
}) async {
  final history = await loadHistory();
  final inputController = TextEditingController();
  try {
    if (!context.mounted) return null;
    return showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (popupContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: SizedBox(
          height: math.min(MediaQuery.sizeOf(context).height * 0.72, 560),
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '网络导入',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(popupContext),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: inputController,
                          placeholder: 'url',
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        onPressed: () => Navigator.pop(
                            popupContext, inputController.text.trim()),
                        child: const Text('导入'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Text(
                          '历史记录',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: history.isEmpty
                      ? const AppEmptyState(
                          illustration:
                              AppEmptyPlanetIllustration(size: 76),
                          title: '暂无历史记录',
                          message: '输入 URL 并导入后会自动保存',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: history.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = history[index];
                            return AppCard(
                              backgroundColor:
                                  CupertinoColors.systemGrey6.resolveFrom(context),
                              padding:
                                  const EdgeInsets.fromLTRB(10, 8, 8, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => inputController.text = item,
                                      child: Text(
                                        item,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(28, 28),
                                    onPressed: () async {
                                      history.removeAt(index);
                                      await saveHistory(history);
                                      if (context.mounted) {
                                        setDialogState(() {});
                                      }
                                    },
                                    child: Icon(
                                      CupertinoIcons.delete,
                                      size: 18,
                                      color: CupertinoColors.systemRed
                                          .resolveFrom(context),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    inputController.dispose();
  }
}
