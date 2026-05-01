import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soupreader/app/widgets/app_cupertino_page_scaffold.dart';
import 'package:soupreader/app/widgets/app_nav_bar_button.dart';
import 'package:soupreader/core/utils/legado_json.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/providers/source_edit_notifier.dart';
import 'package:soupreader/features/source/views/edit/actions/page_actions.dart';
import 'package:soupreader/features/source/views/edit/tabs/basic_tab.dart';
import 'package:soupreader/features/source/views/edit/source_edit_view_build.dart';
import 'package:soupreader/features/source/views/edit/actions/debug_actions.dart';
import 'package:soupreader/features/source/views/edit/tabs/debug_tab.dart';
import 'package:soupreader/features/source/views/edit/tabs/json_tab.dart';
import 'package:soupreader/features/source/views/edit/tabs/rules_tab.dart';

class SourceEditView extends ConsumerStatefulWidget {
  const SourceEditView({
    super.key,
    required this.initialRawJson,
    this.originalUrl,
    this.initialTab,
    this.initialDebugKey,
  });

  final String? originalUrl;
  final String initialRawJson;
  final int? initialTab;
  final String? initialDebugKey;

  static SourceEditView fromSource(
    BookSource source, {
    String? rawJson,
    int? initialTab,
    String? initialDebugKey,
  }) {
    final normalizedRaw = (rawJson != null && rawJson.trim().isNotEmpty)
        ? rawJson
        : LegadoJson.encode(source.toJson());
    return SourceEditView(
      originalUrl: source.bookSourceUrl,
      initialRawJson: normalizedRaw,
      initialTab: initialTab,
      initialDebugKey: initialDebugKey,
    );
  }

  @override
  ConsumerState<SourceEditView> createState() => _SourceEditViewState();
}

class _SourceEditViewState extends ConsumerState<SourceEditView> {
  final Object _sessionId = Object();
  late int _tab;

  SourceEditArgs get _args => SourceEditArgs(
        originalUrl: widget.originalUrl,
        initialRawJson: widget.initialRawJson,
        sessionId: _sessionId,
      );

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(sourceEditProvider(_args).notifier);
      if ((widget.initialDebugKey ?? '').trim().isNotEmpty) {
        notifier.updateDebugKey(widget.initialDebugKey!.trim());
      }
      unawaited(notifier.loadLoginState());
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageActions = SourceEditViewActions(
      context: context,
      ref: ref,
      args: _args,
      setTab: _setTab,
    );
    final debugActions = SourceEditDebugActions(
      context: context,
      ref: ref,
      args: _args,
      setTab: _setTab,
    );

    return AppCupertinoPageScaffold(
      title: '书源编辑',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: () => pageActions.save(),
            child: const Text('保存'),
          ),
          AppNavBarButton(
            onPressed: () => pageActions.showMoreMenu(),
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: Column(
        children: [
          SourceEditTopControlBar(
            args: _args,
            onPickSourceType: pageActions.pickSourceType,
          ),
          Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SourceEditTabControl(
              tabIndex: _tab,
              onChanged: _setTab,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                SourceEditBasicTab(
                  args: _args,
                  actions: pageActions,
                ),
                SourceEditRulesTab(
                  args: _args,
                  actions: pageActions,
                  debugActions: debugActions,
                ),
                SourceEditJsonTab(
                  args: _args,
                  actions: pageActions,
                ),
                SourceEditDebugTab(
                  args: _args,
                  actions: pageActions,
                  debugActions: debugActions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
  }
}
