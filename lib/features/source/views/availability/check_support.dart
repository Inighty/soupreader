import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/theme/design_tokens.dart';
import 'package:soupreader/features/source/services/source_availability/check_task_service.dart';

enum SourceAvailabilityResultFilter {
  all,
  available,
  failed,
  empty,
  timeout,
  skipped,
}

class SourceAvailabilityCheckSupport {
  static Color accentColor(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  static Color statusColor(
    BuildContext context,
    SourceCheckStatus status,
  ) {
    switch (status) {
      case SourceCheckStatus.ok:
        return CupertinoColors.systemGreen.resolveFrom(context);
      case SourceCheckStatus.empty:
        return CupertinoColors.systemOrange.resolveFrom(context);
      case SourceCheckStatus.fail:
        return CupertinoColors.systemRed.resolveFrom(context);
      case SourceCheckStatus.running:
        return accentColor(context);
      case SourceCheckStatus.skipped:
        return CupertinoColors.systemGrey.resolveFrom(context);
      case SourceCheckStatus.pending:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  static String statusText(SourceCheckStatus status) {
    switch (status) {
      case SourceCheckStatus.pending:
        return '待检测';
      case SourceCheckStatus.running:
        return '检测中';
      case SourceCheckStatus.ok:
        return '可用';
      case SourceCheckStatus.empty:
        return '空列表';
      case SourceCheckStatus.fail:
        return '失败';
      case SourceCheckStatus.skipped:
        return '跳过';
    }
  }

  static bool isTimeoutMessage(String? message) {
    final text = (message ?? '').trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('timeout') ||
        text.contains('time out') ||
        text.contains('timed out') ||
        text.contains('连接超时') ||
        text.contains('请求超时') ||
        text.contains('超时');
  }

  static bool matchesFilter(
    SourceCheckItem item,
    SourceAvailabilityResultFilter filter,
  ) {
    switch (filter) {
      case SourceAvailabilityResultFilter.all:
        return true;
      case SourceAvailabilityResultFilter.available:
        return item.status == SourceCheckStatus.ok;
      case SourceAvailabilityResultFilter.failed:
        return item.status == SourceCheckStatus.fail;
      case SourceAvailabilityResultFilter.empty:
        return item.status == SourceCheckStatus.empty;
      case SourceAvailabilityResultFilter.timeout:
        return item.status == SourceCheckStatus.fail &&
            isTimeoutMessage(item.message);
      case SourceAvailabilityResultFilter.skipped:
        return item.status == SourceCheckStatus.skipped;
    }
  }

  static String filterLabel(SourceAvailabilityResultFilter filter) {
    switch (filter) {
      case SourceAvailabilityResultFilter.all:
        return '全部';
      case SourceAvailabilityResultFilter.available:
        return '可用';
      case SourceAvailabilityResultFilter.failed:
        return '失败';
      case SourceAvailabilityResultFilter.empty:
        return '空列表';
      case SourceAvailabilityResultFilter.timeout:
        return '超时';
      case SourceAvailabilityResultFilter.skipped:
        return '跳过';
    }
  }

  static int countByFilter(
    List<SourceCheckItem> items,
    SourceAvailabilityResultFilter filter,
  ) {
    return items.where((item) => matchesFilter(item, filter)).length;
  }

  static String diagnosisLabelText(String code) {
    switch (code) {
      case 'request_failure':
        return '请求失败';
      case 'parse_failure':
        return '解析失败';
      case 'paging_interrupted':
        return '分页中断';
      case 'ok':
        return '基本正常';
      case 'no_data':
        return '无数据';
      default:
        return code;
    }
  }

  static Color diagnosisLabelColor(BuildContext context, String code) {
    switch (code) {
      case 'request_failure':
      case 'parse_failure':
      case 'paging_interrupted':
        return CupertinoColors.systemRed.resolveFrom(context);
      case 'ok':
        return CupertinoColors.systemGreen.resolveFrom(context);
      default:
        return CupertinoColors.systemGrey.resolveFrom(context);
    }
  }

  static String buildReportText({
    required List<SourceCheckItem> items,
    required SourceCheckTaskConfig activeConfig,
    required SourceAvailabilityResultFilter resultFilter,
    required bool onlyVisible,
  }) {
    final now = DateTime.now().toIso8601String();
    final pool = onlyVisible
        ? items.where((item) => matchesFilter(item, resultFilter)).toList()
        : items;

    final lines = <String>[
      '书源可用性检测报告',
      '生成时间：$now',
      '范围：${activeConfig.includeDisabled ? '全部书源' : '仅启用书源'}',
      if (activeConfig.normalizedKeyword().isNotEmpty)
        '关键词：${activeConfig.normalizedKeyword()}',
      '筛选：${filterLabel(resultFilter)}',
      '总计：${pool.length}',
      '可用：${pool.where((item) => item.status == SourceCheckStatus.ok).length}',
      '失败：${pool.where((item) => item.status == SourceCheckStatus.fail).length}',
      '空列表：${pool.where((item) => item.status == SourceCheckStatus.empty).length}',
      '跳过：${pool.where((item) => item.status == SourceCheckStatus.skipped).length}',
      '',
    ];

    for (final item in pool) {
      final source = item.source;
      lines.add([
        statusText(item.status),
        source.bookSourceName,
        source.bookSourceUrl,
        if (item.elapsedMs > 0) '${item.elapsedMs}ms',
        if (item.listCount > 0) 'list=${item.listCount}',
        if (item.diagnosis.labels.isNotEmpty)
          'diag=${item.diagnosis.labels.map(diagnosisLabelText).join(',')}',
        if (item.message != null && item.message!.trim().isNotEmpty)
          item.message!.trim(),
      ].join(' | '));
    }
    return lines.join('\n');
  }

  static String buildItemDetails(SourceCheckItem item) {
    final source = item.source;
    return <String>[
      '名称：${source.bookSourceName}',
      '地址：${source.bookSourceUrl}',
      '启用：${source.enabled}',
      if (item.debugKey != null) '调试 key：${item.debugKey}',
      if (item.requestUrl != null) '请求：${item.requestUrl}',
      '耗时：${item.elapsedMs}ms',
      '列表：${item.listCount}',
      if (item.diagnosis.labels.isNotEmpty)
        '诊断：${item.diagnosis.labels.map(diagnosisLabelText).join(' / ')}',
      if (item.diagnosis.hints.isNotEmpty)
        '建议：${item.diagnosis.hints.join('；')}',
      if (item.message != null) '信息：${item.message}',
    ].join('\n');
  }
}
