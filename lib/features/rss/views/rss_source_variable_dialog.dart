import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/source_variable_store.dart';
import '../models/rss_source.dart';
import 'rss_view_helpers.dart';

/// 弹出「设置源变量」对话框，并把结果写入 [SourceVariableStore]。
///
/// - 如果 [source] 的 `sourceUrl` 为空，则向用户提示「源不存在」并返回。
/// - 用户取消时不做任何写入。
Future<void> showRssSourceVariableDialog({
  required BuildContext context,
  required RssSource source,
  RssSource Function(String sourceUrl)? loadCurrentSource,
}) async {
  final sourceUrl = source.sourceUrl.trim();
  if (sourceUrl.isEmpty) {
    await showRssLoginMessage(context, '源不存在');
    return;
  }
  final current =
      loadCurrentSource != null ? loadCurrentSource(sourceUrl) : source;
  const defaultComment = '源变量可在js中通过source.getVariable()获取';
  final note = current.getDisplayVariableComment(defaultComment);
  final initial = await SourceVariableStore.getVariable(sourceUrl) ?? '';
  if (!context.mounted) return;

  final controller = TextEditingController(text: initial);
  final result = await showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (popupContext) => CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(popupContext).size.height * 0.78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => Navigator.pop(popupContext),
                      child: const Text('取消'),
                    ),
                    const Expanded(
                      child: Text(
                        '设置源变量',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () =>
                          Navigator.pop(popupContext, controller.text),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
              Container(
                height: 0.5,
                color: CupertinoColors.separator.resolveFrom(popupContext),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(popupContext),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: CupertinoTextField(
                          controller: controller,
                          minLines: null,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          placeholder: '输入变量 JSON 或文本',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.dispose();
  if (result == null) return;

  await SourceVariableStore.putVariable(sourceUrl, result);
}
