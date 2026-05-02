import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

/// 整数输入对话框返回该 token 表示用户点了"默认"按钮。
const String kAppearanceDefaultInputActionToken = '__default__';

/// 弹出 launcher icon 选择器（CupertinoPicker），返回用户选中的项索引；
/// 用户取消时返回 null。
Future<int?> showLauncherIconPicker({
  required BuildContext context,
  required List<({String value, String label})> options,
  required int currentIndex,
}) async {
  final initial = currentIndex >= 0 ? currentIndex : 0;
  var pendingIndex = initial;
  final controller = FixedExtentScrollController(initialItem: initial);
  final selected = await showCupertinoBottomSheetDialog<int>(
    context: context,
    builder: (dialogContext) => Container(
      height: 300,
      color: CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground.resolveFrom(context),
        dialogContext,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(pendingIndex),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: controller,
                itemExtent: 36,
                onSelectedItemChanged: (index) {
                  pendingIndex = index;
                },
                children: options
                    .map(
                      (option) => Center(
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  return selected;
}

/// 弹出整数输入对话框（提供 默认/取消/确定 三个动作）。
/// 返回值：
/// - `null`：用户取消；
/// - [kAppearanceDefaultInputActionToken]：用户点击"默认"；
/// - 其他字符串：用户输入的文本（已 trim）。
Future<String?> showAppearanceIntegerInputDialog({
  required BuildContext context,
  required String title,
  required String placeholder,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  return showCupertinoBottomSheetDialog<String>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          placeholder: placeholder,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext)
              .pop(kAppearanceDefaultInputActionToken),
          child: const Text('默认'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(
            controller.text.trim(),
          ),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

/// 显示输入校验失败提示框。
Future<void> showAppearanceValidationMessage(
  BuildContext context,
  String message,
) async {
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('输入无效'),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 显示通用提示框。
Future<void> showAppearanceMessage(
  BuildContext context,
  String message,
) async {
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('提示'),
      content: Text('\n$message'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}
