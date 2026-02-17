import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/source_login_store.dart';
import '../models/book_source.dart';
import '../services/source_login_ui_helper.dart';
import '../services/source_login_script_service.dart';

class SourceLoginFormView extends StatefulWidget {
  final BookSource source;

  const SourceLoginFormView({
    super.key,
    required this.source,
  });

  @override
  State<SourceLoginFormView> createState() => _SourceLoginFormViewState();
}

class _SourceLoginFormViewState extends State<SourceLoginFormView> {
  late final List<SourceLoginUiRow> _rows;
  final SourceLoginScriptService _scriptService =
      const SourceLoginScriptService();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _rows = SourceLoginUiHelper.parseRows(widget.source.loginUi);
    _initFormData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _initFormData() async {
    final key = widget.source.bookSourceUrl.trim();
    Map<String, String> loginInfoMap = <String, String>{};
    if (key.isNotEmpty) {
      final raw = await SourceLoginStore.getLoginInfo(key);
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (k == null || v == null) return;
              final name = k.toString().trim();
              if (name.isEmpty) return;
              loginInfoMap[name] = v.toString();
            });
          }
        } catch (_) {
          // ignore invalid cached payload
        }
      }
    }

    for (final row in _rows) {
      if (!row.isTextLike) continue;
      _controllers[row.name] = TextEditingController(
        text: loginInfoMap[row.name] ?? '',
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final key = widget.source.bookSourceUrl.trim();
    if (key.isEmpty) {
      await _showMessage('请先填写书源地址');
      return;
    }

    final loginData = <String, String>{};
    for (final row in _rows) {
      if (!row.isTextLike) continue;
      final text = (_controllers[row.name]?.text ?? '').trim();
      if (text.isEmpty) continue;
      loginData[row.name] = text;
    }

    if (loginData.isEmpty) {
      await SourceLoginStore.removeLoginInfo(key);
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    await SourceLoginStore.putLoginInfo(key, jsonEncode(loginData));
    final result = await _scriptService.runLoginScript(
      source: widget.source,
      loginData: loginData,
    );
    if (!mounted) return;
    if (!result.success) {
      await _showMessage(result.message);
      return;
    }
    if (result.message.trim().isNotEmpty) {
      await _showMessage(result.message);
      if (!mounted) return;
    }
    Navigator.pop(context);
  }

  Future<void> _handleActionRow(SourceLoginUiRow row) async {
    final action = row.action?.trim() ?? '';
    if (action.isEmpty) return;

    if (SourceLoginUiHelper.isAbsUrl(action)) {
      final uri = Uri.tryParse(action);
      if (uri == null) {
        await _showMessage('按钮地址无效');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final loginData = <String, String>{};
    for (final item in _rows) {
      if (!item.isTextLike) continue;
      final text = (_controllers[item.name]?.text ?? '').trim();
      if (text.isEmpty) continue;
      loginData[item.name] = text;
    }
    final result = await _scriptService.runButtonScript(
      source: widget.source,
      loginData: loginData,
      actionScript: action,
    );
    if (!mounted) return;
    if (result.message.trim().isNotEmpty) {
      await _showMessage(result.message);
    }
  }

  Widget _buildRow(SourceLoginUiRow row) {
    if (row.isButton) {
      return CupertinoButton.filled(
        onPressed: () => _handleActionRow(row),
        child: Text(row.name),
      );
    }

    final controller = _controllers[row.name] ?? TextEditingController();
    _controllers.putIfAbsent(row.name, () => controller);

    return CupertinoTextField(
      controller: controller,
      obscureText: row.isPassword,
      placeholder: row.name,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      clearButtonMode: OverlayVisibilityMode.editing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '登录',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _loading ? null : _submit,
        child: const Text('完成'),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _buildRow(_rows[index]),
              ),
      ),
    );
  }
}
