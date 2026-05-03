import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/online_import_history_store.dart';

const String _onlineImportHistoryKey = 'ttsUrlKey';

/// 弹出「网络导入」输入面板，附带历史记录列表。
///
/// 用户点击「导入」时返回 trim 后的输入；取消则返回 `null`。
Future<String?> showSpeakEngineOnlineImportInputSheet({
  required BuildContext context,
  required OnlineImportHistoryStore historyStore,
}) async {
  final history = await loadSpeakEngineOnlineImportHistory(historyStore);
  if (!context.mounted) return null;
  final inputController = TextEditingController();
  try {
    return showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (popupContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SizedBox(
            height: math.min(MediaQuery.sizeOf(context).height * 0.72, 560),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '网络导入',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
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
                              horizontal: 12,
                              vertical: 10,
                            ),
                            onPressed: () {
                              Navigator.pop(
                                popupContext,
                                inputController.text.trim(),
                              );
                            },
                            child: const Text('导入'),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
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
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: history.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final item = history[index];
                                return _HistoryRow(
                                  item: item,
                                  onTap: () {
                                    inputController.text = item;
                                  },
                                  onDelete: () async {
                                    history.removeAt(index);
                                    await saveSpeakEngineOnlineImportHistory(
                                      historyStore,
                                      history,
                                    );
                                    setDialogState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  } finally {
    inputController.dispose();
  }
}

Future<List<String>> loadSpeakEngineOnlineImportHistory(
  OnlineImportHistoryStore store,
) {
  return store.load(_onlineImportHistoryKey);
}

Future<void> saveSpeakEngineOnlineImportHistory(
  OnlineImportHistoryStore store,
  List<String> history,
) {
  return store.save(_onlineImportHistoryKey, history);
}

Future<void> pushSpeakEngineOnlineImportHistory(
  OnlineImportHistoryStore store,
  String url,
) {
  return store.push(_onlineImportHistoryKey, url);
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final String item;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
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
            onPressed: () => onDelete(),
            child: Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
