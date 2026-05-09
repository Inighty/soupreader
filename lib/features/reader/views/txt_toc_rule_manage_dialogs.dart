import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../settings/views/app_help_dialog.dart';
import '../services/txt_toc_rule_store.dart';
import 'txt_toc_rule_widgets.dart';

/// 显示「导入候选规则」多选面板，返回最终用户选中的索引集合（取消返回 null）。
Future<Set<int>?> showTxtTocRuleImportSelectionSheet({
  required BuildContext context,
  required List<TxtTocRuleImportCandidate> candidates,
}) {
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
                ? '取消全选（$selectedCount/$totalCount）'
                : '全选（$selectedCount/$totalCount）';
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
                            '导入 TXT 目录规则',
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
                                ..addAll(List<int>.generate(
                                  candidates.length,
                                  (index) => index,
                                ));
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
                        return TxtTocRuleImportCandidateTile(
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

/// 弹出「网络导入」输入面板，返回用户输入；取消返回 null。
///
/// [history] 是历史记录的可变列表；用户在面板内删除条目时直接修改它，
/// 删除后回调 [onPersistHistory] 持久化。
Future<String?> showTxtTocRuleOnlineImportInputSheet({
  required BuildContext context,
  required List<String> history,
  required Future<void> Function(List<String> history) onPersistHistory,
}) async {
  final inputController = TextEditingController();
  try {
    return await showCupertinoBottomSheetDialog<String>(
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
                            onPressed: () => Navigator.pop(
                              popupContext,
                              inputController.text.trim(),
                            ),
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
                                return _OnlineImportHistoryRow(
                                  url: item,
                                  onTap: () {
                                    inputController.text = item;
                                  },
                                  onDelete: () async {
                                    history.removeAt(index);
                                    await onPersistHistory(history);
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

class _OnlineImportHistoryRow extends StatelessWidget {
  const _OnlineImportHistoryRow({
    required this.url,
    required this.onTap,
    required this.onDelete,
  });

  final String url;
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
                url,
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

/// 通用提示对话框。
Future<void> showTxtTocRuleMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 「确定删除？」二次确认。
Future<bool> confirmTxtTocRuleDelete({
  required BuildContext context,
  required String name,
}) async {
  final confirmed = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提醒'),
      content: Text('是否确认删除？\n$name'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 「确定删除选中的 N 条？」二次确认。
Future<bool> confirmTxtTocRuleDeleteSelected({
  required BuildContext context,
  required int count,
}) async {
  final confirmed = await showCupertinoBottomSheetDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提醒'),
      content: Text('是否确认删除选中的 $count 条规则？'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// 用阻塞 dialog 执行异步任务，结束后自动关闭 dialog。
Future<void> runTxtTocRuleImportingTask({
  required BuildContext context,
  required Future<void> Function() task,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showCupertinoBottomSheetDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const CupertinoAlertDialog(
      content: BlockingProgressContent(text: '导入中...'),
    ),
  );
  await Future<void>.delayed(Duration.zero);
  try {
    await task();
  } finally {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

/// 「导出成功」展示路径并支持复制。
Future<void> showTxtTocRuleExportPathDialog({
  required BuildContext context,
  required String outputPath,
  required void Function(String message) onToast,
}) async {
  final path = outputPath.trim();
  final uri = Uri.tryParse(path);
  final isHttpPath = uri != null &&
      (uri.scheme.toLowerCase() == 'http' ||
          uri.scheme.toLowerCase() == 'https');
  final lines = <String>[
    '导出路径：',
    path,
    if (isHttpPath) '',
    if (isHttpPath) '检测到网络链接，可直接复制后分享。',
  ];
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('导出成功'),
      content: Text('\n${lines.join('\n')}'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
        CupertinoDialogAction(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: path));
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            onToast('已复制导出路径');
          },
          child: const Text('复制路径'),
        ),
      ],
    ),
  );
}

/// 加载 markdown 帮助并展示。
Future<void> showTxtTocRuleHelpDialog(BuildContext context) async {
  try {
    final markdownText =
        await rootBundle.loadString('assets/web/help/md/txtTocRuleHelp.md');
    if (!context.mounted) return;
    await showAppHelpDialog(context, markdownText: markdownText);
  } catch (error) {
    if (!context.mounted) return;
    await showTxtTocRuleMessageDialog(
      context: context,
      title: '帮助',
      message: '帮助文档加载失败：$error',
    );
  }
}

String formatTxtTocRuleImportError(Object error) {
  if (error is FileSystemException) {
    final message = error.message.trim();
    if (message.isEmpty) return 'readTextError:ERROR';
    return 'readTextError:$message';
  }
  if (error is FormatException) {
    final message = error.message.trim();
    if (message.isEmpty) return 'ImportError:格式不对';
    return 'ImportError:$message';
  }
  final text = '$error'.trim();
  if (text.isEmpty) return 'ImportError:ERROR';
  if (text.startsWith('Exception:')) {
    final stripped = text.substring('Exception:'.length).trim();
    return stripped.isEmpty ? 'ImportError:ERROR' : 'ImportError:$stripped';
  }
  return 'ImportError:$text';
}
