import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../source/views/source_debug_text_view.dart';
import '../models/rss_source.dart';
import '../services/rss_source_debug_service.dart';

enum _RssSourceDebugMenuAction {
  openListRawSource,
  openContentRawSource,
}

class RssSourceDebugView extends StatefulWidget {
  const RssSourceDebugView({
    super.key,
    required this.source,
    this.debugService,
  });

  final RssSource source;
  final RssSourceDebugService? debugService;

  @override
  State<RssSourceDebugView> createState() => _RssSourceDebugViewState();
}

class _RssSourceDebugViewState extends State<RssSourceDebugView> {
  late final RssSourceDebugService _debugService;
  bool _running = false;
  List<String> _logs = const <String>[];
  String? _listSrcRaw;
  String? _contentSrcRaw;

  @override
  void initState() {
    super.initState();
    _debugService = widget.debugService ?? RssSourceDebugService();
    _runDebug();
  }

  Future<void> _runDebug() async {
    if (_running) return;
    setState(() {
      _running = true;
      _logs = const <String>['开始调试...'];
      _listSrcRaw = null;
      _contentSrcRaw = null;
    });

    final snapshot = await _debugService.run(widget.source);
    if (!mounted) return;
    setState(() {
      _running = false;
      _logs = snapshot.logs.isEmpty ? const <String>['调试结束'] : snapshot.logs;
      _listSrcRaw = snapshot.listSrc;
      _contentSrcRaw = snapshot.contentSrc;
    });
  }

  Future<void> _openListRawSource() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(
          title: 'Html',
          text: _listSrcRaw ?? '',
        ),
      ),
    );
  }

  Future<void> _openContentRawSource() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(
          title: 'Html',
          text: _contentSrcRaw ?? '',
        ),
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    if (!mounted) return;
    final selected = await showAppActionListSheet<_RssSourceDebugMenuAction>(
      context: context,
      title: '更多',
      showCancel: true,
      items: const [
        AppActionListItem<_RssSourceDebugMenuAction>(
          value: _RssSourceDebugMenuAction.openListRawSource,
          icon: CupertinoIcons.list_bullet,
          label: '列表源码',
        ),
        AppActionListItem<_RssSourceDebugMenuAction>(
          value: _RssSourceDebugMenuAction.openContentRawSource,
          icon: CupertinoIcons.doc_text,
          label: '正文源码',
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _RssSourceDebugMenuAction.openListRawSource:
        await _openListRawSource();
        return;
      case _RssSourceDebugMenuAction.openContentRawSource:
        await _openContentRawSource();
        return;
    }
  }

  Widget _buildLogList() {
    if (_logs.isEmpty) {
      return const AppEmptyState(
        illustration: AppEmptyPlanetIllustration(size: 82),
        title: '暂无调试日志',
        message: '请点击刷新重新发起调试',
      );
    }
    final tokens = AppUiTokens.resolve(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        return AppCard(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          borderColor: tokens.colors.separator.withValues(alpha: 0.72),
          child: Text(
            _logs[index],
            style: TextStyle(
              fontSize: 13,
              color: tokens.colors.label,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '订阅源调试',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            minimumSize: const Size(30, 30),
            onPressed: _running ? null : _runDebug,
            child: const Icon(CupertinoIcons.refresh),
          ),
          AppNavBarButton(
            minimumSize: const Size(30, 30),
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_running)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CupertinoActivityIndicator(),
                  SizedBox(width: 8),
                  Text('调试运行中...'),
                ],
              ),
            ),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }
}
