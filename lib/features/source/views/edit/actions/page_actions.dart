import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/app/widgets/app_action_list_sheet.dart';
import 'package:soupreader/app/widgets/app_toast.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/app/widgets/option_picker_sheet.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/shared/debug_text_view.dart';

enum _SourceEditMoreAction {
  clearCookie,
  copyJson,
  pasteJsonFromClipboard,
}

class SourceEditViewActions {
  SourceEditViewActions({
    required this.context,
    required this.ref,
    required this.args,
    required this.setTab,
  });

  final BuildContext context;
  final WidgetRef ref;
  final SourceEditArgs args;
  final ValueChanged<int> setTab;

  SourceEditNotifier get notifier => ref.read(sourceEditProvider(args).notifier);
  SourceEditState get state => ref.read(sourceEditProvider(args));

  Future<void> showMoreMenu() async {
    final selected = await showAppActionListSheet<_SourceEditMoreAction>(
      context: context,
      title: '更多',
      showCancel: true,
      items: const [
        AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.clearCookie,
          icon: CupertinoIcons.delete_solid,
          label: '清 Cookie',
        ),
        AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.copyJson,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制 JSON',
        ),
        AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.pasteJsonFromClipboard,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '从剪贴板粘贴 JSON',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _SourceEditMoreAction.clearCookie:
        await clearCookie();
        return;
      case _SourceEditMoreAction.copyJson:
        await Clipboard.setData(ClipboardData(text: state.rawJson));
        await _showToast('已复制 JSON');
        return;
      case _SourceEditMoreAction.pasteJsonFromClipboard:
        await pasteJsonFromClipboard();
        return;
    }
  }

  Future<void> clearCookie() async {
    final url = state.source.bookSourceUrl.trim();
    if (url.isEmpty) {
      showMessage('请先填写 bookSourceUrl');
      return;
    }
    try {
      await notifier.clearCookie();
      await _showToast('已清理该书源 Cookie');
    } catch (error) {
      showMessage('清理 Cookie 失败：$error');
    }
  }

  Future<void> pasteJsonFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      showMessage('剪贴板为空');
      return;
    }
    notifier.updateRawJson(_prettyJson(text));
  }

  Future<void> pickSourceType() async {
    final current = state.source.bookSourceType;
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '书源类型',
      currentValue: current,
      items: _sourceTypes
          .map(
            (item) => OptionPickerItem<int>(
              value: item.value,
              label: item.label,
            ),
          )
          .toList(growable: false),
    );
    if (selected == null) return;
    notifier.updateSource(
      (currentSource) => currentSource.copyWith(bookSourceType: selected),
    );
  }

  Future<void> save() async {
    final error = await notifier.save();
    if (error != null) {
      showMessage(error);
      return;
    }
    await _showToast('保存成功');
  }

  void syncToJsonTab() {
    setTab(2);
  }

  void syncFromJson() {
    notifier.updateRawJson(state.rawJson);
  }

  void formatJson() {
    notifier.updateRawJson(_prettyJson(state.rawJson));
  }

  String? validateJson() {
    return notifier.validateJson();
  }

  Future<void> runRuleLint() async {
    final report = await notifier.runRuleLint();
    await openDebugText(title: '规则体检报告', text: report);
  }

  Future<void> loadLoginState() {
    return notifier.loadLoginState();
  }

  Future<void> saveLoginState() async {
    try {
      await notifier.saveLoginState();
      await _showToast('登录态缓存已保存');
    } catch (error) {
      showMessage('登录态保存失败：$error');
    }
  }

  Future<void> clearLoginState() async {
    await notifier.clearLoginState();
    await _showToast('登录态缓存已清除');
  }

  Future<void> openDebugText({
    required String title,
    required String text,
  }) {
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(title: title, text: text),
      ),
    );
  }

  void showMessage(String message) {
    showCupertinoBottomSheetDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<void> _showToast(String message) {
    return showAppToast(context, message: message);
  }

  String _prettyJson(String raw) {
    try {
      final decoded = json.decode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw.trim();
    }
  }
}

const _sourceTypes = [
  (value: 0, label: '文本'),
  (value: 1, label: '音频'),
  (value: 2, label: '图片'),
  (value: 3, label: '文件'),
];
