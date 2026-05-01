import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';
import 'package:soupreader/features/source/services/source_availability/check_executor.dart';
import 'package:soupreader/features/source/services/source_availability/check_models.dart';
import 'package:soupreader/features/source/services/source_availability/check_support.dart';
import 'package:soupreader/features/source/services/source_availability/diagnosis_service.dart';
import 'package:soupreader/features/source/services/source/explore_kinds_service.dart';

export 'package:soupreader/features/source/services/source_availability/check_models.dart';

/// 书源可用性检测任务服务：
/// - 检测任务脱离页面生命周期，页面退出后可继续运行；
/// - 再次进入检测页可恢复当前任务状态；
/// - 提供 start/stop 任务控制，并输出统一快照供 UI 订阅。
class SourceAvailabilityCheckTaskService {
  SourceAvailabilityCheckTaskService._() {
    _executor = SourceAvailabilityCheckExecutor(
      engine: RuleParserEngine(),
      diagnosisService: const SourceAvailabilityDiagnosisService(),
      repo: _repo,
      exploreKindsService: SourceExploreKindsService(),
      shouldStopCurrentTask: _shouldStopCurrentTask,
      touch: touch,
      cacheItemResult: _cacheItemResult,
    );
  }

  static final SourceAvailabilityCheckTaskService instance =
      SourceAvailabilityCheckTaskService._();

  final SourceRepository _repo = SourceRepository(DatabaseService());
  final Map<String, SourceCheckCachedResult> _lastResultByUrl =
      <String, SourceCheckCachedResult>{};
  final ValueNotifier<SourceCheckTaskSnapshot?> _notifier =
      ValueNotifier<SourceCheckTaskSnapshot?>(null);
  late final SourceAvailabilityCheckExecutor _executor;

  ValueListenable<SourceCheckTaskSnapshot?> get listenable => _notifier;

  SourceCheckTaskSnapshot? get snapshot => _notifier.value;

  bool get isRunning => snapshot?.running == true;

  SourceCheckCachedResult? lastResultFor(String bookSourceUrl) {
    final key = bookSourceUrl.trim();
    if (key.isEmpty) return null;
    return _lastResultByUrl[key];
  }

  Future<SourceCheckStartResult> start(
    SourceCheckTaskConfig config, {
    bool forceRestart = false,
  }) async {
    final current = snapshot;
    if (current != null && current.running) {
      if (current.config.semanticallyEquals(config)) {
        return const SourceCheckStartResult(
          type: SourceCheckStartType.attachedExisting,
          message: '已恢复正在进行的检测任务',
        );
      }
      return const SourceCheckStartResult(
        type: SourceCheckStartType.runningOtherTask,
        message: '已有检测任务在运行，请先停止后再发起新任务',
      );
    }

    if (!forceRestart &&
        current != null &&
        current.config.semanticallyEquals(config) &&
        current.items.isNotEmpty) {
      return const SourceCheckStartResult(
        type: SourceCheckStartType.attachedExisting,
        message: '已恢复最近一次检测结果',
      );
    }

    final items = SourceAvailabilityCheckSupport.buildItems(config, _repo);
    if (items.isEmpty) {
      _notifier.value = SourceCheckTaskSnapshot(
        config: config,
        running: false,
        stopRequested: false,
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        items: const <SourceCheckItem>[],
      );
      return const SourceCheckStartResult(
        type: SourceCheckStartType.emptySource,
        message: '没有可检测书源',
      );
    }

    SourceAvailabilityCheckSupport.clearCachedResultsFor(_lastResultByUrl, items);
    final now = DateTime.now();
    _notifier.value = SourceCheckTaskSnapshot(
      config: config,
      running: true,
      stopRequested: false,
      startedAt: now,
      finishedAt: null,
      items: items,
    );

    unawaited(_runCurrentTask());
    return const SourceCheckStartResult(
      type: SourceCheckStartType.started,
      message: '已开始检测任务',
    );
  }

  void requestStop() {
    final current = snapshot;
    if (current == null || !current.running || current.stopRequested) return;
    _notifier.value = current.copyWith(stopRequested: true);
    _executor.requestStop();
  }

  void touch() {
    final current = snapshot;
    if (current == null) return;
    _notifier.value = current.copyWith();
  }

  Future<void> _runCurrentTask() async {
    final current = snapshot;
    if (current == null || !current.running) return;

    await _executor.run(
      config: current.config,
      items: current.items,
    );

    final done = snapshot;
    if (done == null) return;
    _notifier.value = done.copyWith(
      running: false,
      stopRequested: false,
      finishedAt: DateTime.now(),
    );
    SourceAvailabilityCheckSupport.publishSummary(done.items, done.config);
  }

  bool _shouldStopCurrentTask() {
    final latest = snapshot;
    return latest == null || !latest.running || latest.stopRequested;
  }

  void _cacheItemResult(SourceCheckItem item) {
    SourceAvailabilityCheckSupport.cacheItemResult(_lastResultByUrl, item);
  }
}
