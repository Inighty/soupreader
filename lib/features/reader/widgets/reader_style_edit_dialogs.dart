import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../models/reading_settings.dart';
import 'reader_color_picker_dialog.dart';

String readerStyleHexRgb(int colorValue) {
  final rgb = colorValue & 0x00FFFFFF;
  return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
}

/// 弹出"样式名称"编辑对话框，确认时回调新名称。
Future<void> showReaderStyleNameDialog({
  required BuildContext context,
  required ReadStyleConfig draft,
  required ValueChanged<ReadStyleConfig> onUpdate,
}) async {
  final controller = TextEditingController(text: draft.name);
  final result = await showCupertinoDialog<String>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('样式名称'),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoTextField(
          controller: controller,
          autofocus: true,
          placeholder: '请输入名称',
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null) return;
  onUpdate(draft.copyWith(name: result));
}

Future<void> showReaderStyleTextColorPicker({
  required BuildContext context,
  required ReadStyleConfig draft,
  required ValueChanged<ReadStyleConfig> onUpdate,
}) async {
  final picked = await showReaderColorPickerDialog(
    context: context,
    title: '文字颜色',
    initialColor: draft.textColor,
  );
  if (picked == null) return;
  onUpdate(draft.copyWith(textColor: picked));
}

Future<void> showReaderStyleBgColorPicker({
  required BuildContext context,
  required ReadStyleConfig draft,
  required ValueChanged<ReadStyleConfig> onUpdate,
}) async {
  final picked = await showReaderColorPickerDialog(
    context: context,
    title: '背景颜色',
    initialColor: draft.backgroundColor,
  );
  if (picked == null) return;
  onUpdate(draft.copyWith(
    backgroundColor: picked,
    bgStr: '#${readerStyleHexRgb(picked)}',
  ));
}

/// 选择本地图片作为背景。Web 平台直接 no-op。
Future<void> pickReaderStyleBgFile({
  required ReadStyleConfig draft,
  required ValueChanged<ReadStyleConfig> onUpdate,
  required bool Function() isMounted,
}) async {
  if (kIsWeb) return;
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  if (!isMounted()) return;
  final path = result?.files.firstOrNull?.path;
  if (path == null || path.isEmpty) return;
  onUpdate(draft.copyWith(
    bgType: ReadStyleConfig.bgTypeFile,
    bgStr: path,
    bgAlpha: draft.bgAlpha == 100 ? 80 : draft.bgAlpha,
  ));
}

/// 弹出"恢复预设"选择菜单。
void showReaderStylePresetPicker({
  required BuildContext context,
  required ReadStyleConfig draft,
  required ValueChanged<ReadStyleConfig> onUpdate,
}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('选择预设'),
      actions: [
        for (final preset in kDefaultReadStyleConfigs)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onUpdate(preset.copyWith(name: draft.name));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(preset.backgroundColor),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(preset.name),
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('取消'),
      ),
    ),
  );
}

/// 弹出"删除样式"确认弹框，确认后关闭 sheet 并触发 onDelete。
void confirmReaderStyleDelete({
  required BuildContext context,
  required ReadStyleConfig draft,
  required VoidCallback? onDelete,
}) {
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('删除样式'),
      content: Text('确定删除「${draft.name.isEmpty ? '未命名' : draft.name}」吗？'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pop(context);
            onDelete?.call();
          },
          child: const Text('删除'),
        ),
      ],
    ),
  );
}

/// 「背景透明度」滑杆行。
class ReaderStyleAlphaRow extends StatelessWidget {
  final ReadStyleConfig draft;
  final Color labelColor;
  final Color mutedColor;
  final Color accent;
  final ValueChanged<ReadStyleConfig> onUpdate;

  const ReaderStyleAlphaRow({
    super.key,
    required this.draft,
    required this.labelColor,
    required this.mutedColor,
    required this.accent,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = draft.bgAlpha.clamp(0, 100);
    final enabled = draft.bgType != ReadStyleConfig.bgTypeColor;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Text('背景透明度',
                  style: TextStyle(color: labelColor, fontSize: 15)),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoSlider(
                  value: alpha.toDouble(),
                  min: 0,
                  max: 100,
                  activeColor: accent,
                  onChanged: enabled
                      ? (v) => onUpdate(draft.copyWith(bgAlpha: v.round()))
                      : null,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$alpha%',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「恢复预设」按钮行。
class ReaderStylePresetRow extends StatelessWidget {
  final Color labelColor;
  final VoidCallback onTap;

  const ReaderStylePresetRow({
    super.key,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Text('恢复预设',
              style: TextStyle(color: labelColor, fontSize: 15)),
          const Spacer(),
          Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            size: 14,
          ),
        ],
      ),
    );
  }
}

/// 「删除样式」红色按钮行。
class ReaderStyleDeleteRow extends StatelessWidget {
  final VoidCallback onTap;

  const ReaderStyleDeleteRow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Text(
            '删除样式',
            style: TextStyle(
              color: CupertinoColors.systemRed.resolveFrom(context),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
