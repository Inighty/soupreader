import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../models/direct_link_upload_rule.dart';
import '../services/direct_link_upload_config_service.dart';

enum _DirectLinkUploadConfigMenuAction {
  pasteRule,
  importDefault,
}

/// 直链上传配置页（对齐 legado `DirectLinkUploadConfig`）。
class DirectLinkUploadConfigView extends StatefulWidget {
  const DirectLinkUploadConfigView({super.key});

  @override
  State<DirectLinkUploadConfigView> createState() =>
      _DirectLinkUploadConfigViewState();
}

class _DirectLinkUploadConfigViewState
    extends State<DirectLinkUploadConfigView> {
  final DirectLinkUploadConfigService _service =
      DirectLinkUploadConfigService();
  late final TextEditingController _uploadUrlController;
  late final TextEditingController _downloadUrlRuleController;
  late final TextEditingController _summaryController;

  bool _compress = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _uploadUrlController = TextEditingController();
    _downloadUrlRuleController = TextEditingController();
    _summaryController = TextEditingController();
    _initRule();
  }

  @override
  void dispose() {
    _uploadUrlController.dispose();
    _downloadUrlRuleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _initRule() async {
    final rule = await _service.loadRule();
    if (!mounted) return;
    _applyRule(rule);
    setState(() {
      _loading = false;
    });
  }

  void _applyRule(DirectLinkUploadRule rule) {
    _uploadUrlController.text = rule.uploadUrl;
    _downloadUrlRuleController.text = rule.downloadUrlRule;
    _summaryController.text = rule.summary;
    _compress = rule.compress;
  }

  DirectLinkUploadRule? _buildRuleFromForm() {
    final uploadUrl = _uploadUrlController.text;
    final downloadUrlRule = _downloadUrlRuleController.text;
    final summary = _summaryController.text;

    if (uploadUrl.trim().isEmpty) {
      _showMessage('上传Url不能为空');
      return null;
    }
    if (downloadUrlRule.trim().isEmpty) {
      _showMessage('下载Url规则不能为空');
      return null;
    }
    if (summary.trim().isEmpty) {
      _showMessage('注释不能为空');
      return null;
    }
    return DirectLinkUploadRule(
      uploadUrl: uploadUrl,
      downloadUrlRule: downloadUrlRule,
      summary: summary,
      compress: _compress,
    );
  }

  Future<void> _saveAndClose() async {
    final rule = _buildRuleFromForm();
    if (rule == null) return;
    await _service.saveRule(rule);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showMoreMenu() async {
    final selected =
        await showCupertinoModalPopup<_DirectLinkUploadConfigMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('直链上传配置'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _DirectLinkUploadConfigMenuAction.pasteRule,
            ),
            child: const Text('粘贴规则'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _DirectLinkUploadConfigMenuAction.importDefault,
            ),
            child: const Text('导入默认规则'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case _DirectLinkUploadConfigMenuAction.pasteRule:
        await _pasteRuleFromClipboard();
        return;
      case _DirectLinkUploadConfigMenuAction.importDefault:
        await _importDefaultRule();
        return;
    }
  }

  Future<void> _importDefaultRule() async {
    final defaultRules = await _service.loadDefaultRules();
    if (!mounted || defaultRules.isEmpty) return;
    final selected = await showCupertinoModalPopup<DirectLinkUploadRule>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('导入默认规则'),
        actions: defaultRules
            .map(
              (rule) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, rule),
                child: Text(rule.summary),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _applyRule(selected);
    });
  }

  Future<void> _pasteRuleFromClipboard() async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clipData?.text;
    if (clipText == null || clipText.trim().isEmpty) {
      await _showMessage('剪贴板为空或格式不对');
      return;
    }
    try {
      final decoded = jsonDecode(clipText);
      if (decoded is! Map) {
        throw const FormatException('格式不对');
      }
      final mapped = decoded.map<String, dynamic>(
        (key, value) => MapEntry('$key', value),
      );
      final rule = DirectLinkUploadRule.fromJson(mapped);
      if (!mounted) return;
      setState(() {
        _applyRule(rule);
      });
    } catch (_) {
      await _showMessage('剪贴板为空或格式不对');
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _saveAndClose,
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '直链上传配置',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 30,
        onPressed: _showMoreMenu,
        child: const Icon(CupertinoIcons.ellipsis),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    children: [
                      CupertinoFormSection.insetGrouped(
                        children: [
                          CupertinoTextFormFieldRow(
                            controller: _uploadUrlController,
                            prefix: const Text('上传URL'),
                            placeholder: '上传 URL',
                          ),
                          CupertinoTextFormFieldRow(
                            controller: _downloadUrlRuleController,
                            prefix: const Text('下载URL规则'),
                            placeholder: '下载URL规则(downloadUrls)',
                          ),
                          CupertinoTextFormFieldRow(
                            controller: _summaryController,
                            prefix: const Text('注释'),
                            placeholder: '注释',
                          ),
                          CupertinoFormRow(
                            prefix: const Text('是否压缩'),
                            child: CupertinoSwitch(
                              value: _compress,
                              onChanged: (value) {
                                setState(() {
                                  _compress = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildFooterActions(),
              ],
            ),
    );
  }
}
