import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/theme/design_tokens.dart';
import 'package:soupreader/app/widgets/app_cupertino_page_scaffold.dart';
import 'package:soupreader/app/widgets/app_nav_bar_button.dart';
import 'package:soupreader/app/widgets/app_ui_kit.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/services/source_availability/check_task_service.dart';
import 'package:soupreader/features/source/services/source_debug/export_service.dart';
import 'package:soupreader/features/source/views/availability/check_actions.dart';
import 'package:soupreader/features/source/views/availability/check_support.dart';

class SourceAvailabilityCheckView extends StatefulWidget {
  const SourceAvailabilityCheckView({
    super.key,
    this.includeDisabled = false,
    this.sourceUrls,
    this.keywordOverride,
  });

  final bool includeDisabled;
  final List<String>? sourceUrls;
  final String? keywordOverride;

  @override
  State<SourceAvailabilityCheckView> createState() =>
      _SourceAvailabilityCheckViewState();
}

class _SourceAvailabilityCheckViewState
    extends State<SourceAvailabilityCheckView> {
  final SourceAvailabilityCheckTaskService _taskService =
      SourceAvailabilityCheckTaskService.instance;
  final SourceDebugExportService _exportService = SourceDebugExportService();
  late final SourceRepository _repo;

  SourceAvailabilityResultFilter _resultFilter =
      SourceAvailabilityResultFilter.all;
  late final SourceCheckTaskConfig _initialConfig;

  SourceAvailabilityCheckActions get _actions => SourceAvailabilityCheckActions(
        context: context,
        repo: _repo,
        taskService: _taskService,
        exportService: _exportService,
        items: _items,
        activeConfig: _activeConfig,
        resultFilter: _resultFilter,
        running: _running,
        onItemsChanged: () {
          if (!mounted) return;
          setState(() {});
        },
      );

  @override
  void initState() {
    super.initState();
    _repo = SourceRepository(DatabaseService());
    _initialConfig = SourceCheckTaskConfig(
      includeDisabled: widget.includeDisabled,
      sourceUrls: widget.sourceUrls,
      keywordOverride: widget.keywordOverride,
    );
    _taskService.listenable.addListener(_onTaskUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_actions.ensureTaskStarted());
    });
  }

  @override
  void dispose() {
    _taskService.listenable.removeListener(_onTaskUpdate);
    super.dispose();
  }

  void _onTaskUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  SourceCheckTaskSnapshot? get _snapshot => _taskService.snapshot;

  SourceCheckTaskConfig get _activeConfig => _snapshot?.config ?? _initialConfig;

  List<SourceCheckItem> get _items =>
      _snapshot?.items ?? const <SourceCheckItem>[];

  bool get _running => _snapshot?.running == true;

  bool get _stopRequested => _snapshot?.stopRequested == true;

  void _stop() {
    _taskService.requestStop();
  }

  Future<void> _start() async {
    await _actions.ensureTaskStarted(forceRestart: true);
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final done = _items
        .where(
          (item) =>
              item.status != SourceCheckStatus.pending &&
              item.status != SourceCheckStatus.running,
        )
        .length;
    final ok =
        _items.where((item) => item.status == SourceCheckStatus.ok).length;
    final fail =
        _items.where((item) => item.status == SourceCheckStatus.fail).length;
    final empty =
        _items.where((item) => item.status == SourceCheckStatus.empty).length;
    final timedOut = _items
        .where(
          (item) =>
              item.status == SourceCheckStatus.fail &&
              SourceAvailabilityCheckSupport.isTimeoutMessage(item.message),
        )
        .length;
    final skipped = _items
        .where((item) => item.status == SourceCheckStatus.skipped)
        .length;
    final visibleItems = _items
        .where(
          (item) =>
              SourceAvailabilityCheckSupport.matchesFilter(item, _resultFilter),
        )
        .toList(growable: false);

    return AppCupertinoPageScaffold(
      title: '书源可用性检测',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: () => unawaited(_actions.copyReport()),
            child: const Text('复制'),
          ),
          AppNavBarButton(
            onPressed: () => unawaited(_actions.exportReportToFile()),
            child: const Text('导出'),
          ),
        ],
      ),
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('概览'),
            children: [
              CupertinoListTile.notched(
                title: const Text('进度'),
                additionalInfo: Text('$done / $total'),
              ),
              CupertinoListTile.notched(
                title: const Text('结果'),
                subtitle: Text(
                  '可用 $ok / 失败 $fail / 空 $empty / 超时 $timedOut / 跳过 $skipped',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('结果筛选'),
                subtitle: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: CupertinoSlidingSegmentedControl<
                      SourceAvailabilityResultFilter>(
                    groupValue: _resultFilter,
                    children: {
                      for (final filter in SourceAvailabilityResultFilter.values)
                        filter: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${SourceAvailabilityCheckSupport.filterLabel(filter)}'
                            '(${SourceAvailabilityCheckSupport.countByFilter(_items, filter)})',
                          ),
                        ),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      setState(() => _resultFilter = value);
                    },
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('一键禁用失效源'),
                subtitle: const Text('禁用状态为“失败/空列表”的已启用书源'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => unawaited(_actions.disableUnavailableSources()),
              ),
              CupertinoListTile.notched(
                title: Text(_running ? (_stopRequested ? '停止中…' : '停止检测') : '重新检测'),
                trailing: const CupertinoListTileChevron(),
                onTap: _running ? _stop : () => unawaited(_start()),
              ),
            ],
          ),
          AppListSection(
            header: Text('列表（显示 ${visibleItems.length} / 总计 $total）'),
            children: visibleItems.map((item) {
              final statusText =
                  SourceAvailabilityCheckSupport.statusText(item.status);
              final statusColor = SourceAvailabilityCheckSupport.statusColor(
                context,
                item.status,
              );
              final diagnosisColor =
                  SourceAvailabilityCheckSupport.diagnosisLabelColor(
                context,
                item.diagnosis.primary,
              );
              return GestureDetector(
                onLongPress: () => unawaited(_actions.openEditorAtDebug(item)),
                child: CupertinoListTile.notched(
                  title: Text(item.source.bookSourceName),
                  subtitle: Text(item.source.bookSourceUrl),
                  additionalInfo: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: diagnosisColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppDesignTokens.radiusControl,
                          ),
                          border: Border.all(
                            color: diagnosisColor.withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          SourceAvailabilityCheckSupport.diagnosisLabelText(
                            item.diagnosis.primary,
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: diagnosisColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => unawaited(_actions.openItemDetails(item)),
                ),
              );
            }).toList(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              '提示：长按某条书源可直接打开调试页。',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
