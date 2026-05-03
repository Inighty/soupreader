import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../models/http_tts_rule.dart';
import '../services/http_tts_rule_store.dart';
import 'http_tts_rule_edit_view.dart';
import 'speak_engine_import_selection_sheet.dart';
import 'speak_engine_manage_body.dart';
import 'speak_engine_manage_widgets.dart';
import 'speak_engine_online_import_input_sheet.dart';

class SpeakEngineManageView extends StatefulWidget {
  const SpeakEngineManageView({super.key});

  @override
  State<SpeakEngineManageView> createState() => _SpeakEngineManageViewState();
}

class _SpeakEngineManageViewState extends State<SpeakEngineManageView> {
  final HttpTtsRuleStore _ruleStore = HttpTtsRuleStore();
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  bool _loading = true;
  bool _importingDefault = false;
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _exporting = false;
  List<HttpTtsRule> _rules = const <HttpTtsRule>[];
  int? _selectedRuleId;

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  bool get _menuBusy =>
      _importingDefault || _importingLocal || _importingOnline || _exporting;

  void _updateState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '朗读引擎',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: _menuBusy ? null : _addRule,
            minimumSize: const Size(30, 30),
            child: const Icon(CupertinoIcons.add),
          ),
          AppNavBarButton(
            onPressed: _menuBusy ? null : _showMoreMenu,
            minimumSize: const Size(30, 30),
            child: _menuBusy
                ? const CupertinoActivityIndicator(radius: 9)
                : const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: SpeakEngineManageBody(
        loading: _loading,
        rules: _rules,
        selectedRuleId: _selectedRuleId,
        onSelectRule: _selectEngine,
        onEditRule: _openRuleEditor,
        onDeleteRule: _deleteRule,
      ),
    );
  }

  Future<void> _reloadRules() async {
    _updateState(() => _loading = true);
    final results = await Future.wait([
      _ruleStore.loadRules(),
      _ruleStore.loadSelectedRuleId(),
    ]);
    final rules = results[0] as List<HttpTtsRule>;
    final selectedId = results[1] as int?;
    final sorted = rules.toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });
    _updateState(() {
      _rules = sorted;
      _selectedRuleId = selectedId;
      _loading = false;
    });
  }

  Future<void> _selectEngine(int? ruleId) async {
    await _ruleStore.saveSelectedRuleId(ruleId);
    _updateState(() => _selectedRuleId = ruleId);
    String name;
    if (ruleId == null) {
      name = '系统默认';
    } else {
      final matched = _rules.where((r) => r.id == ruleId).firstOrNull;
      final rawName = matched?.name.trim() ?? '';
      name = rawName.isEmpty ? '未命名引擎' : rawName;
    }
    _showToastMessage('已切换到 $name');
  }

  HttpTtsRule _buildNewRuleDraft() {
    final usedIds = _rules.map((rule) => rule.id).toSet();
    var id = DateTime.now().millisecondsSinceEpoch;
    while (usedIds.contains(id)) {
      id++;
    }
    return HttpTtsRule(
      id: id,
      name: '',
      url: '',
      contentType: null,
      concurrentRate: '0',
      loginUrl: null,
      loginUi: null,
      header: null,
      jsLib: null,
      enabledCookieJar: false,
      loginCheckJs: null,
      lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _openRuleEditor(HttpTtsRule rule) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => HttpTtsRuleEditView(
          initialRule: rule,
          onRuleSaved: (_) => _reloadRules(),
        ),
      ),
    );
  }

  Future<void> _deleteRule(HttpTtsRule rule) async {
    try {
      await _ruleStore.deleteRule(rule.id);
      await _reloadRules();
    } catch (_) {}
  }

  Future<void> _addRule() async {
    if (_menuBusy) return;
    await _openRuleEditor(_buildNewRuleDraft());
  }

  Future<void> _importDefaultRules() async {
    if (_importingDefault) return;
    _updateState(() => _importingDefault = true);
    try {
      await _ruleStore.importDefaultRules();
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await _showMessageDialog(title: '导入默认规则', message: '导入失败：$error');
    } finally {
      _updateState(() => _importingDefault = false);
    }
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showAppActionListSheet<SpeakEngineMenuAction>(
      context: context,
      title: '朗读引擎',
      showCancel: true,
      items: const [
        AppActionListItem<SpeakEngineMenuAction>(
          value: SpeakEngineMenuAction.importDefaultRules,
          icon: CupertinoIcons.arrow_down_doc,
          label: '导入默认规则',
        ),
        AppActionListItem<SpeakEngineMenuAction>(
          value: SpeakEngineMenuAction.importLocal,
          icon: CupertinoIcons.folder,
          label: '本地导入',
        ),
        AppActionListItem<SpeakEngineMenuAction>(
          value: SpeakEngineMenuAction.importOnline,
          icon: CupertinoIcons.cloud_download,
          label: '网络导入',
        ),
        AppActionListItem<SpeakEngineMenuAction>(
          value: SpeakEngineMenuAction.export,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case SpeakEngineMenuAction.importDefaultRules:
        await _importDefaultRules();
      case SpeakEngineMenuAction.importLocal:
        await _importLocalRules();
      case SpeakEngineMenuAction.importOnline:
        await _importOnlineRules();
      case SpeakEngineMenuAction.export:
        await _exportRules();
    }
  }

  Future<void> _exportRules() async {
    if (_exporting) return;
    _updateState(() => _exporting = true);
    try {
      final jsonText = HttpTtsRule.listToJsonText(_rules);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出',
        fileName: 'httpTts.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      if (!mounted) return;
      await _showExportPathDialog(outputPath.trim());
    } catch (error) {
      if (!mounted) return;
      await _showMessageDialog(title: '导出', message: '导出失败：$error');
    } finally {
      _updateState(() => _exporting = false);
    }
  }

  Future<void> _runImportingTask(Future<void> Function() task) async {
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

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
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

  Future<void> _showExportPathDialog(String outputPath) async {
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
    if (!mounted) return;
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
              _showToastMessage('已复制导出路径');
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  void _showToastMessage(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  Future<void> _importLocalRules() async {
    if (_importingLocal) return;
    _updateState(() => _importingLocal = true);
    try {
      final fileText = await _pickLocalImportText();
      if (fileText == null) return;
      final candidates = await _ruleStore.previewImportCandidates(fileText);
      if (candidates.isEmpty) {
        await _showMessageDialog(title: '本地导入', message: '格式不对');
        return;
      }
      if (!mounted) return;
      final selectedIndexes = await showSpeakEngineImportSelectionSheet(
        context: context,
        candidates: candidates,
      );
      if (selectedIndexes == null || selectedIndexes.isEmpty) return;
      if (!mounted) return;
      await _runImportingTask(() async {
        await _ruleStore.importCandidates(
          candidates: candidates,
          selectedIndexes: selectedIndexes,
        );
      });
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(title: '本地导入', message: '导入失败：$error');
    } finally {
      _updateState(() => _importingLocal = false);
    }
  }

  Future<void> _importOnlineRules() async {
    if (_importingOnline) return;
    _updateState(() => _importingOnline = true);
    try {
      final rawInput = await showSpeakEngineOnlineImportInputSheet(
        context: context,
        historyStore: _onlineImportHistoryStore,
      );
      final normalizedInput = rawInput?.trim();
      if (normalizedInput == null || normalizedInput.isEmpty) return;
      if (_isHttpUrl(normalizedInput)) {
        await pushSpeakEngineOnlineImportHistory(
          _onlineImportHistoryStore,
          normalizedInput,
        );
      }
      final candidates = await _ruleStore.previewImportCandidates(
        normalizedInput,
      );
      if (candidates.isEmpty) {
        await _showMessageDialog(title: '网络导入', message: '格式不对');
        return;
      }
      if (!mounted) return;
      final selectedIndexes = await showSpeakEngineImportSelectionSheet(
        context: context,
        candidates: candidates,
      );
      if (selectedIndexes == null || selectedIndexes.isEmpty) return;
      if (!mounted) return;
      await _runImportingTask(() async {
        await _ruleStore.importCandidates(
          candidates: candidates,
          selectedIndexes: selectedIndexes,
        );
      });
      await _reloadRules();
    } on FormatException {
      if (!mounted) return;
      await _showMessageDialog(title: '网络导入', message: '格式不对');
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(title: '网络导入', message: '导入失败：$error');
    } finally {
      _updateState(() => _importingOnline = false);
    }
  }

  Future<String?> _pickLocalImportText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return File(path).readAsString();
    }
    throw const FileSystemException('无法读取文件内容');
  }

  bool _isHttpUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    return parsed.scheme == 'http' || parsed.scheme == 'https';
  }
}
