import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_availability/check_models.dart';
import 'package:soupreader/features/source/services/source_availability/summary_store.dart';
import 'package:soupreader/features/source/services/source/explore_kinds_service.dart';

class SourceAvailabilityCheckSupport {
  static void clearCachedResultsFor(
    Map<String, SourceCheckCachedResult> lastResultByUrl,
    List<SourceCheckItem> items,
  ) {
    for (final item in items) {
      final url = item.source.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      lastResultByUrl.remove(url);
    }
  }

  static void cacheItemResult(
    Map<String, SourceCheckCachedResult> lastResultByUrl,
    SourceCheckItem item,
  ) {
    if (item.status == SourceCheckStatus.pending) return;
    final url = item.source.bookSourceUrl.trim();
    if (url.isEmpty) return;
    lastResultByUrl[url] = SourceCheckCachedResult(
      status: item.status,
      message: item.message,
      elapsedMs: item.elapsedMs,
    );
  }

  static int resolveThreadCount(int itemCount) {
    if (itemCount <= 0) return 1;
    var threadCount = 8;
    try {
      threadCount = SettingsService().appSettings.searchConcurrency;
    } catch (_) {
      threadCount = 8;
    }
    if (threadCount < 1) {
      threadCount = 1;
    }
    if (threadCount > itemCount) {
      threadCount = itemCount;
    }
    return threadCount;
  }

  static bool isFileSourceType(BookSource source) {
    return source.bookSourceType == 3;
  }

  static Future<String?> resolveFirstExploreUrl(
    BookSource source,
    SourceExploreKindsService exploreKindsService,
  ) async {
    try {
      final kinds = await exploreKindsService.exploreKinds(source);
      for (final kind in kinds) {
        final url = (kind.url ?? '').trim();
        if (url.isNotEmpty) return url;
      }
    } catch (_) {
      // 保持与校验流程一致：无法解析发现分类时按“无可用分类链接”处理。
    }
    return null;
  }

  static List<SourceCheckItem> buildItems(
    SourceCheckTaskConfig config,
    SourceRepository repo,
  ) {
    final selectedUrls = config.normalizedSourceUrls();
    final all = repo.getAllSources();
    if (selectedUrls.isNotEmpty) {
      final byUrl = <String, BookSource>{
        for (final source in all) source.bookSourceUrl: source,
      };
      final ordered = <SourceCheckItem>[];
      final seen = <String>{};
      for (final raw in (config.sourceUrls ?? const <String>[])) {
        final url = raw.trim();
        if (url.isEmpty || !seen.add(url)) continue;
        final source = byUrl[url];
        if (source == null) continue;
        ordered.add(SourceCheckItem(source: source));
      }
      return ordered;
    }

    all.sort((a, b) {
      if (a.weight != b.weight) return b.weight.compareTo(a.weight);
      return a.bookSourceName.compareTo(b.bookSourceName);
    });
    return all.map((source) => SourceCheckItem(source: source)).toList();
  }

  static void publishSummary(
    List<SourceCheckItem> items,
    SourceCheckTaskConfig config,
  ) {
    final failedSourceUrls = items
        .where(
          (item) =>
              item.status == SourceCheckStatus.fail ||
              item.status == SourceCheckStatus.empty,
        )
        .map((item) => item.source.bookSourceUrl)
        .toSet()
        .toList(growable: false);

    SourceAvailabilitySummaryStore.instance.update(
      SourceAvailabilitySummary(
        finishedAt: DateTime.now(),
        includeDisabled: config.includeDisabled,
        keyword:
            config.normalizedKeyword().isEmpty ? null : config.normalizedKeyword(),
        total: items.length,
        available: items.where((item) => item.status == SourceCheckStatus.ok).length,
        failed: items.where((item) => item.status == SourceCheckStatus.fail).length,
        empty: items.where((item) => item.status == SourceCheckStatus.empty).length,
        timeout: items
            .where(
              (item) =>
                  item.status == SourceCheckStatus.fail &&
                  isTimeoutMessage(item.message),
            )
            .length,
        skipped:
            items.where((item) => item.status == SourceCheckStatus.skipped).length,
        failedSourceUrls: failedSourceUrls,
      ),
    );
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

  static bool isLikelyJsError(String message) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('script') ||
        text.contains('javascript') ||
        text.contains('js ') ||
        text.contains('js:') ||
        text.contains('js执行') ||
        text.contains('js失效');
  }
}
