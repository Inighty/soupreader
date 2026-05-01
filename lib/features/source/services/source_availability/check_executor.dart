import 'dart:async';

import 'package:dio/dio.dart';

import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';
import 'package:soupreader/features/source/services/source_availability/check_models.dart';
import 'package:soupreader/features/source/services/source_availability/check_stage_runner.dart';
import 'package:soupreader/features/source/services/source_availability/check_support.dart';
import 'package:soupreader/features/source/services/source_availability/diagnosis_service.dart';
import 'package:soupreader/features/source/services/source_availability/source_state_helper.dart';
import 'package:soupreader/features/source/services/source/explore_kinds_service.dart';

class SourceAvailabilityCheckExecutor {
  SourceAvailabilityCheckExecutor({
    required this.engine,
    required this.diagnosisService,
    required this.repo,
    required this.exploreKindsService,
    required this.shouldStopCurrentTask,
    required this.touch,
    required this.cacheItemResult,
  }) : _stageRunner = SourceAvailabilityCheckStageRunner(
          engine: engine,
          diagnosisService: diagnosisService,
          exploreKindsService: exploreKindsService,
        );

  final RuleParserEngine engine;
  final SourceAvailabilityDiagnosisService diagnosisService;
  final SourceRepository repo;
  final SourceExploreKindsService exploreKindsService;
  final bool Function() shouldStopCurrentTask;
  final void Function() touch;
  final void Function(SourceCheckItem item) cacheItemResult;

  final SourceAvailabilityCheckStageRunner _stageRunner;
  CancelToken? _runningCancelToken;
  final Set<CancelToken> _runningCancelTokens = <CancelToken>{};

  void requestStop() {
    final tokens = _runningCancelTokens.toList(growable: false);
    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel('source check stopped by user');
      }
    }
    final currentToken = _runningCancelToken;
    if (currentToken != null && !currentToken.isCancelled) {
      currentToken.cancel('source check stopped by user');
    }
  }

  Future<void> run({
    required SourceCheckTaskConfig config,
    required List<SourceCheckItem> items,
  }) async {
    final workerCount = SourceAvailabilityCheckSupport.resolveThreadCount(
      items.length,
    );
    var cursor = 0;

    Future<void> runWorker() async {
      while (true) {
        if (shouldStopCurrentTask()) return;
        if (cursor >= items.length) return;
        final item = items[cursor++];
        await _runItem(config: config, item: item);
      }
    }

    final workers = List<Future<void>>.generate(
      workerCount,
      (_) => runWorker(),
      growable: false,
    );
    await Future.wait(workers);

    _runningCancelToken = null;
    _runningCancelTokens.clear();
  }

  Future<void> _runItem({
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
  }) async {
    if (shouldStopCurrentTask()) return;

    var source = item.source;
    if (!config.includeDisabled && !source.enabled) {
      item.status = SourceCheckStatus.skipped;
      item.message = '已跳过（未启用）';
      cacheItemResult(item);
      touch();
      return;
    }
    if (!config.checkSearch && !config.checkDiscovery) {
      item.status = SourceCheckStatus.skipped;
      item.message = '已跳过（未启用搜索/发现校验）';
      cacheItemResult(item);
      touch();
      return;
    }

    item.status = SourceCheckStatus.running;
    item.message = '检测中…';
    cacheItemResult(item);
    touch();
    source = SourceCheckSourceStateHelper.prepareForCheck(source);
    item.source = source;

    final requestToken = CancelToken();
    _runningCancelToken = requestToken;
    _runningCancelTokens.add(requestToken);
    final stopwatch = Stopwatch()..start();
    try {
      final timeout = Duration(milliseconds: config.normalizedTimeoutMs());
      final runOutcome = await _stageRunner
          .runItemCheckStages(
            config: config,
            item: item,
            cancelToken: requestToken,
          )
          .timeout(
            timeout,
            onTimeout: () {
              if (!requestToken.isCancelled) {
                requestToken.cancel('source check timeout');
              }
              throw TimeoutException('source check timeout');
            },
          );
      source = SourceCheckSourceStateHelper.applyGroupMutations(
        source,
        add: runOutcome.addGroups,
        remove: runOutcome.removeGroups,
      );
      if (item.status == SourceCheckStatus.fail ||
          item.status == SourceCheckStatus.empty) {
        final invalidGroups = SourceCheckSourceStateHelper.invalidGroupNames(
          source.bookSourceGroup,
        );
        final errorMessage = invalidGroups.isNotEmpty
            ? invalidGroups
            : ((item.message ?? '').trim().isNotEmpty
                ? (item.message ?? '').trim()
                : '校验失败');
        source = SourceCheckSourceStateHelper.addErrorComment(
          source,
          errorMessage,
        );
      }
      cacheItemResult(item);
      touch();
    } on TimeoutException catch (_) {
      item.status = SourceCheckStatus.fail;
      item.message = '校验超时';
      item.diagnosis = diagnosisService.diagnoseException('timeout');
      source = SourceCheckSourceStateHelper.applyGroupMutations(
        source,
        add: const <String>{'校验超时'},
      );
      source = SourceCheckSourceStateHelper.addErrorComment(source, '校验超时');
      cacheItemResult(item);
      touch();
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        item.status = SourceCheckStatus.skipped;
        item.message = '已停止';
        item.diagnosis = DiagnosisSummary.noData;
        cacheItemResult(item);
        touch();
      } else {
        item.status = SourceCheckStatus.fail;
        item.message = '异常：$error';
        item.diagnosis = diagnosisService.diagnoseException(error);
        source = SourceCheckSourceStateHelper.applyGroupMutations(
          source,
          add: const <String>{'网站失效'},
        );
        source = SourceCheckSourceStateHelper.addErrorComment(
          source,
          error.toString(),
        );
        cacheItemResult(item);
        touch();
      }
    } catch (error) {
      item.status = SourceCheckStatus.fail;
      item.message = '异常：$error';
      item.diagnosis = diagnosisService.diagnoseException(error);
      final errorText = error.toString();
      source = SourceCheckSourceStateHelper.applyGroupMutations(
        source,
        add: SourceAvailabilityCheckSupport.isLikelyJsError(errorText)
            ? const <String>{'js失效'}
            : const <String>{'网站失效'},
      );
      source = SourceCheckSourceStateHelper.addErrorComment(source, errorText);
      cacheItemResult(item);
      touch();
    } finally {
      stopwatch.stop();
      final elapsed = item.elapsedMs > 0
          ? item.elapsedMs
          : stopwatch.elapsedMilliseconds;
      if (elapsed > 0) {
        source = source.copyWith(respondTime: elapsed);
        item.elapsedMs = elapsed;
      }
      item.source = source;
      cacheItemResult(item);
      try {
        await repo.updateSource(source);
      } catch (_) {
        // 按任务继续策略忽略单条写库失败，避免整批检测中断。
      }
      _runningCancelTokens.remove(requestToken);
      if (identical(_runningCancelToken, requestToken)) {
        _runningCancelToken = null;
      }
    }
  }
}
