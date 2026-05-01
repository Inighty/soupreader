import 'package:dio/dio.dart';

import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';
import 'package:soupreader/features/source/services/source_availability/check_models.dart';
import 'package:soupreader/features/source/services/source_availability/check_support.dart';
import 'package:soupreader/features/source/services/source_availability/diagnosis_service.dart';
import 'package:soupreader/features/source/services/source/explore_kinds_service.dart';

class SourceCheckStageOutcome {
  const SourceCheckStageOutcome({
    required this.success,
    required this.failed,
    this.message = '',
    this.requestUrl,
    this.elapsedMs = 0,
    this.listCount = 0,
    this.diagnosis = DiagnosisSummary.noData,
    this.addGroups = const <String>{},
    this.removeGroups = const <String>{},
  });

  final bool success;
  final bool failed;
  final String message;
  final String? requestUrl;
  final int elapsedMs;
  final int listCount;
  final DiagnosisSummary diagnosis;
  final Set<String> addGroups;
  final Set<String> removeGroups;

  bool get hasMessage => message.trim().isNotEmpty;
}

class SourceCheckRunOutcome {
  const SourceCheckRunOutcome({
    this.addGroups = const <String>{},
    this.removeGroups = const <String>{},
  });

  final Set<String> addGroups;
  final Set<String> removeGroups;
}

class SourceAvailabilityCheckStageRunner {
  const SourceAvailabilityCheckStageRunner({
    required this.engine,
    required this.diagnosisService,
    required this.exploreKindsService,
  });

  final RuleParserEngine engine;
  final SourceAvailabilityDiagnosisService diagnosisService;
  final SourceExploreKindsService exploreKindsService;

  Future<SourceCheckRunOutcome> runItemCheckStages({
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
    required CancelToken cancelToken,
  }) async {
    throwIfCancelled(cancelToken);
    final source = item.source;
    final outcomes = <SourceCheckStageOutcome>[];
    if (config.checkSearch) {
      outcomes.add(
        await _runSearchStage(
          source: source,
          config: config,
          item: item,
          cancelToken: cancelToken,
        ),
      );
    }
    if (config.checkDiscovery) {
      outcomes.add(
        await _runExploreStage(
          source: source,
          config: config,
          item: item,
          cancelToken: cancelToken,
        ),
      );
    }

    if (outcomes.isEmpty) {
      item.status = SourceCheckStatus.skipped;
      item.message = '已跳过';
      item.diagnosis = DiagnosisSummary.noData;
      return const SourceCheckRunOutcome();
    }

    final failedMessages = <String>[];
    final successMessages = <String>[];
    final addGroups = <String>{};
    final removeGroups = <String>{};
    var hasSuccessOutcome = false;
    var elapsedMs = 0;
    var listCount = 0;
    String? requestUrl;
    DiagnosisSummary diagnosis = DiagnosisSummary.noData;

    for (final outcome in outcomes) {
      elapsedMs += outcome.elapsedMs;
      listCount = listCount > outcome.listCount ? listCount : outcome.listCount;
      if ((outcome.requestUrl ?? '').trim().isNotEmpty) {
        requestUrl = outcome.requestUrl;
      }
      if (diagnosis == DiagnosisSummary.noData &&
          outcome.diagnosis != DiagnosisSummary.noData) {
        diagnosis = outcome.diagnosis;
      }
      addGroups.addAll(outcome.addGroups);
      removeGroups.addAll(outcome.removeGroups);
      if (outcome.failed) {
        if (outcome.hasMessage) {
          failedMessages.add(outcome.message);
        }
      } else if (outcome.success) {
        hasSuccessOutcome = true;
        if (outcome.hasMessage) {
          successMessages.add(outcome.message);
        }
      }
    }

    item.elapsedMs = elapsedMs;
    item.listCount = listCount;
    item.requestUrl = requestUrl;
    item.diagnosis = diagnosis;

    if (failedMessages.isNotEmpty) {
      item.status = SourceCheckStatus.fail;
      item.message = failedMessages.join('；');
      return SourceCheckRunOutcome(
        addGroups: addGroups,
        removeGroups: removeGroups,
      );
    }
    if (successMessages.isNotEmpty) {
      item.status = SourceCheckStatus.ok;
      item.message = successMessages.join('；');
      return SourceCheckRunOutcome(
        addGroups: addGroups,
        removeGroups: removeGroups,
      );
    }
    if (hasSuccessOutcome) {
      item.status = SourceCheckStatus.ok;
      item.message = '校验成功';
      return SourceCheckRunOutcome(
        addGroups: addGroups,
        removeGroups: removeGroups,
      );
    }

    item.status = SourceCheckStatus.skipped;
    item.message = '已跳过';
    if (item.diagnosis == DiagnosisSummary.noData) {
      item.diagnosis = diagnosisService.diagnoseMissingRule();
    }
    return SourceCheckRunOutcome(
      addGroups: addGroups,
      removeGroups: removeGroups,
    );
  }

  Future<SourceCheckStageOutcome> _runSearchStage({
    required BookSource source,
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
    required CancelToken cancelToken,
  }) async {
    final hasSearch =
        source.searchUrl != null && source.searchUrl!.trim().isNotEmpty;
    if (!hasSearch) {
      return SourceCheckStageOutcome(
        success: true,
        failed: false,
        diagnosis: diagnosisService.diagnoseMissingRule(),
        addGroups: const <String>{'搜索链接规则为空'},
      );
    }

    final overrideKeyword = config.normalizedKeyword();
    final keyword = overrideKeyword.isNotEmpty
        ? overrideKeyword
        : (source.ruleSearch?.checkKeyWord?.trim().isNotEmpty == true
            ? source.ruleSearch!.checkKeyWord!.trim()
            : '我的');
    item.debugKey = keyword;
    final debug = await engine.searchDebug(
      source,
      keyword,
      cancelToken: cancelToken,
    );
    final listCount = debug.listCount;
    final requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
    final diagnosis = diagnosisService.diagnoseSearch(
      debug: debug,
      keyword: keyword,
    );
    if (debug.fetch.body == null) {
      final errorText = (debug.error ?? debug.fetch.error ?? '搜索请求失败');
      final failureGroup = SourceAvailabilityCheckSupport.isLikelyJsError(errorText)
          ? 'js失效'
          : '网站失效';
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: errorText,
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: listCount,
        diagnosis: diagnosis,
        addGroups: <String>{failureGroup},
        removeGroups: const <String>{'搜索链接规则为空'},
      );
    }
    if (listCount <= 0) {
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '搜索失效',
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: listCount,
        diagnosis: diagnosis,
        addGroups: const <String>{'搜索失效'},
        removeGroups: const <String>{'搜索链接规则为空'},
      );
    }

    final chain = await _runBookStageChain(
      source: source,
      config: config,
      stagePrefix: '搜索',
      bookUrl: debug.results.first.bookUrl.trim(),
      cancelToken: cancelToken,
    );
    return SourceCheckStageOutcome(
      success: chain.success,
      failed: chain.failed,
      message: chain.hasMessage ? chain.message : '搜索可用（列表 $listCount）',
      requestUrl: chain.requestUrl ?? requestUrl,
      elapsedMs: debug.fetch.elapsedMs + chain.elapsedMs,
      listCount: listCount,
      diagnosis:
          chain.diagnosis == DiagnosisSummary.noData ? diagnosis : chain.diagnosis,
      addGroups: chain.addGroups,
      removeGroups: {
        ...chain.removeGroups,
        '搜索失效',
        '搜索链接规则为空',
      },
    );
  }

  Future<SourceCheckStageOutcome> _runExploreStage({
    required BookSource source,
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
    required CancelToken cancelToken,
  }) async {
    final hasExplore =
        source.exploreUrl != null && source.exploreUrl!.trim().isNotEmpty;
    if (!hasExplore) {
      return const SourceCheckStageOutcome(success: true, failed: false);
    }

    final exploreUrl = await SourceAvailabilityCheckSupport.resolveFirstExploreUrl(
      source,
      exploreKindsService,
    );
    if (exploreUrl == null) {
      return const SourceCheckStageOutcome(
        success: true,
        failed: false,
        addGroups: <String>{'发现规则为空'},
      );
    }
    item.debugKey = '发现::$exploreUrl';
    final debug = await engine.exploreDebug(
      source,
      exploreUrlOverride: exploreUrl,
      cancelToken: cancelToken,
    );
    final listCount = debug.listCount;
    final requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
    final diagnosis = diagnosisService.diagnoseExplore(debug: debug);
    if (debug.fetch.body == null) {
      final errorText = (debug.error ?? debug.fetch.error ?? '发现请求失败');
      final failureGroup = SourceAvailabilityCheckSupport.isLikelyJsError(errorText)
          ? 'js失效'
          : '网站失效';
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: errorText,
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: listCount,
        diagnosis: diagnosis,
        addGroups: <String>{failureGroup},
        removeGroups: const <String>{'发现规则为空'},
      );
    }
    if (listCount <= 0) {
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '发现失效',
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: listCount,
        diagnosis: diagnosis,
        addGroups: const <String>{'发现失效'},
        removeGroups: const <String>{'发现规则为空'},
      );
    }

    final chain = await _runBookStageChain(
      source: source,
      config: config,
      stagePrefix: '发现',
      bookUrl: debug.results.first.bookUrl.trim(),
      cancelToken: cancelToken,
    );
    return SourceCheckStageOutcome(
      success: chain.success,
      failed: chain.failed,
      message: chain.hasMessage ? chain.message : '发现可用（列表 $listCount）',
      requestUrl: chain.requestUrl ?? requestUrl,
      elapsedMs: debug.fetch.elapsedMs + chain.elapsedMs,
      listCount: listCount,
      diagnosis:
          chain.diagnosis == DiagnosisSummary.noData ? diagnosis : chain.diagnosis,
      addGroups: chain.addGroups,
      removeGroups: {
        ...chain.removeGroups,
        '发现失效',
        '发现规则为空',
      },
    );
  }

  Future<SourceCheckStageOutcome> _runBookStageChain({
    required BookSource source,
    required SourceCheckTaskConfig config,
    required String stagePrefix,
    required String bookUrl,
    required CancelToken cancelToken,
  }) async {
    throwIfCancelled(cancelToken);
    final tocFailureGroup = '$stagePrefix目录失效';
    final contentFailureGroup = '$stagePrefix正文失效';
    if (!config.checkInfo) {
      return SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '$stagePrefix可用',
        removeGroups: {tocFailureGroup, contentFailureGroup},
      );
    }

    final normalizedBookUrl = bookUrl.trim();
    if (normalizedBookUrl.isEmpty) {
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '$stagePrefix详情失效',
        diagnosis: diagnosisService.diagnoseMissingRule(),
      );
    }

    throwIfCancelled(cancelToken);
    final info = await engine.getBookInfoDebug(source, normalizedBookUrl);
    throwIfCancelled(cancelToken);
    final infoRequestUrl = info.fetch.finalUrl ?? info.fetch.requestUrl;
    if (info.fetch.body == null || info.detail == null) {
      final detailError = (info.error ?? '').trim();
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: detailError.isNotEmpty ? detailError : '$stagePrefix详情失效',
        requestUrl: infoRequestUrl,
        elapsedMs: info.fetch.elapsedMs,
        diagnosis: diagnosisService.diagnoseMissingRule(),
      );
    }

    if (!config.checkCategory ||
        SourceAvailabilityCheckSupport.isFileSourceType(source)) {
      return SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '$stagePrefix详情可用',
        requestUrl: infoRequestUrl,
        elapsedMs: info.fetch.elapsedMs,
        removeGroups: {tocFailureGroup, contentFailureGroup},
      );
    }

    final tocUrl = info.detail!.tocUrl.trim();
    if (tocUrl.isEmpty) {
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '$stagePrefix目录失效',
        requestUrl: infoRequestUrl,
        elapsedMs: info.fetch.elapsedMs,
        addGroups: {tocFailureGroup},
      );
    }

    throwIfCancelled(cancelToken);
    final toc = await engine.getTocDebug(source, tocUrl);
    throwIfCancelled(cancelToken);
    final tocRequestUrl = toc.fetch.finalUrl ?? toc.fetch.requestUrl;
    final chapters = toc.toc
        .where((chapter) => !chapter.isVolume && chapter.url.trim().isNotEmpty)
        .toList(growable: false);
    if (toc.fetch.body == null || chapters.isEmpty) {
      final tocError = (toc.error ?? '').trim();
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: tocError.isNotEmpty ? tocError : '$stagePrefix目录失效',
        requestUrl: tocRequestUrl,
        elapsedMs: info.fetch.elapsedMs + toc.fetch.elapsedMs,
        addGroups: {tocFailureGroup},
      );
    }

    if (!config.checkContent) {
      return SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '$stagePrefix目录可用',
        requestUrl: tocRequestUrl,
        elapsedMs: info.fetch.elapsedMs + toc.fetch.elapsedMs,
        removeGroups: {tocFailureGroup, contentFailureGroup},
      );
    }

    final firstChapter = chapters.first;
    final nextChapterUrl = chapters.length > 1 ? chapters[1].url : null;
    throwIfCancelled(cancelToken);
    final content = await engine.getContentDebug(
      source,
      firstChapter.url,
      nextChapterUrl: nextChapterUrl,
    );
    throwIfCancelled(cancelToken);
    final contentRequestUrl = content.fetch.finalUrl ?? content.fetch.requestUrl;
    final contentText = content.content.trim();
    if (content.fetch.body == null ||
        (content.error ?? '').trim().isNotEmpty ||
        contentText.isEmpty) {
      final contentError = (content.error ?? '').trim();
      return SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: contentError.isNotEmpty ? contentError : '$stagePrefix正文失效',
        requestUrl: contentRequestUrl,
        elapsedMs:
            info.fetch.elapsedMs + toc.fetch.elapsedMs + content.fetch.elapsedMs,
        addGroups: {contentFailureGroup},
      );
    }

    return SourceCheckStageOutcome(
      success: true,
      failed: false,
      message: '$stagePrefix正文可用',
      requestUrl: contentRequestUrl,
      elapsedMs:
          info.fetch.elapsedMs + toc.fetch.elapsedMs + content.fetch.elapsedMs,
      removeGroups: {tocFailureGroup, contentFailureGroup},
    );
  }

  Never cancelledError(CancelToken cancelToken) {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.cancel,
      error: cancelToken.cancelError,
      message: cancelToken.cancelError?.toString(),
    );
  }

  void throwIfCancelled(CancelToken cancelToken) {
    if (!cancelToken.isCancelled) return;
    cancelledError(cancelToken);
  }
}
