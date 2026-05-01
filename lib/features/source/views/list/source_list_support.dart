import 'package:flutter/cupertino.dart';

import 'package:soupreader/features/search/models/search_scope_group_helper.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_availability/check_task_service.dart';
import 'package:soupreader/features/source/services/source_availability/source_state_helper.dart';
import 'package:soupreader/features/source/services/source/host_group_helper.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';

class SourceListSupport {
  static List<BookSource> normalizeSources(List<BookSource> sources) {
    final dedup = <String, BookSource>{};
    for (final source in sources) {
      final url = source.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      dedup[url] = source;
    }
    return dedup.values.toList(growable: false);
  }

  static void cleanupSelection({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
    required Map<String, GlobalKey> itemKeyByUrl,
  }) {
    final urls = allSources.map((source) => source.bookSourceUrl).toSet();
    itemKeyByUrl.removeWhere((url, _) => !urls.contains(url));
    if (selectedUrls.isEmpty) return;
    final toRemove =
        selectedUrls.where((url) => !urls.contains(url)).toList(growable: false);
    if (toRemove.isEmpty) return;
    selectedUrls.removeAll(toRemove);
  }

  static Map<String, SourceCheckItem> buildCheckItemIndex(
    SourceCheckTaskSnapshot? snapshot,
  ) {
    if (snapshot == null) return const {};
    return {
      for (final item in snapshot.items) item.source.bookSourceUrl: item,
    };
  }

  static SourceCheckStatus? inlineCheckStatus({
    required BookSource source,
    required SourceAvailabilityCheckTaskService checkTaskService,
    Map<String, SourceCheckItem>? checkIndex,
  }) {
    final item = checkIndex?[source.bookSourceUrl];
    if (item != null) return item.status;
    final cached = checkTaskService.lastResultFor(source.bookSourceUrl);
    return cached?.status;
  }

  static String? inlineCheckMessage({
    required BookSource source,
    required SourceAvailabilityCheckTaskService checkTaskService,
    Map<String, SourceCheckItem>? checkIndex,
  }) {
    final item = checkIndex?[source.bookSourceUrl];
    final cached = checkTaskService.lastResultFor(source.bookSourceUrl);
    final status = item?.status ?? cached?.status;
    if (status == null) return null;
    final base = switch (status) {
      SourceCheckStatus.pending => '待校验',
      SourceCheckStatus.running => '校验中',
      SourceCheckStatus.ok => '校验成功',
      SourceCheckStatus.empty => '空列表',
      SourceCheckStatus.fail => '校验失败',
      SourceCheckStatus.skipped => '已跳过',
    };
    final detail = ((item?.message) ?? (cached?.message) ?? '').trim();
    if (detail.isEmpty || detail == base) return base;
    return '$base：$detail';
  }

  static Color inlineCheckColor(
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
        return CupertinoTheme.of(context).primaryColor;
      case SourceCheckStatus.skipped:
        return CupertinoColors.systemGrey.resolveFrom(context);
      case SourceCheckStatus.pending:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  static List<String> buildGroups(List<BookSource> sources) {
    final rawGroups = sources
        .map((source) => source.bookSourceGroup?.trim() ?? '')
        .where((raw) => raw.isNotEmpty);
    return SearchScopeGroupHelper.dealGroups(rawGroups);
  }

  static List<BookSource> buildVisibleList({
    required List<BookSource> allSources,
    required String query,
    required SourceSortMode sortMode,
    required bool sortAscending,
    required bool groupSourcesByDomain,
    required Map<String, String> hostMap,
  }) {
    var filtered = allSources;
    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      filtered = applyQueryFilter(filtered, trimmedQuery);
    }
    final sorted = filtered.toList(growable: false);
    hostMap.clear();
    sortSources(
      sorted,
      sortMode: sortMode,
      sortAscending: sortAscending,
      groupSourcesByDomain: groupSourcesByDomain,
      hostMap: hostMap,
    );
    return sorted;
  }

  static List<BookSource> applyQueryFilter(
    List<BookSource> input,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();
    if (lowerQuery == '已启用' || lowerQuery == '启用') {
      return input.where((source) => source.enabled).toList(growable: false);
    }
    if (lowerQuery == '已禁用' || lowerQuery == '禁用') {
      return input.where((source) => !source.enabled).toList(growable: false);
    }
    if (lowerQuery == '需要登录' || lowerQuery == '需登录') {
      return input
          .where((source) => (source.loginUrl ?? '').trim().isNotEmpty)
          .toList(growable: false);
    }
    if (lowerQuery == '未分组' || lowerQuery == '无分组') {
      return input.where((source) {
        final group = source.bookSourceGroup ?? '';
        return group.isEmpty || group.contains('未分组');
      }).toList(growable: false);
    }
    if (lowerQuery == '已启用发现' || lowerQuery == '启用发现') {
      return input
          .where((source) => source.enabledExplore)
          .toList(growable: false);
    }
    if (lowerQuery == '已禁用发现' || lowerQuery == '禁用发现') {
      return input
          .where((source) => !source.enabledExplore)
          .toList(growable: false);
    }
    if (query.startsWith('group:')) {
      final key = query.substring(6);
      return input
          .where((source) => matchesGroupQueryLegacy(source.bookSourceGroup, key))
          .toList(growable: false);
    }
    return input.where((source) {
      final name = source.bookSourceName.toLowerCase();
      final url = source.bookSourceUrl.toLowerCase();
      final group = (source.bookSourceGroup ?? '').toLowerCase();
      final comment = (source.bookSourceComment ?? '').toLowerCase();
      return name.contains(lowerQuery) ||
          url.contains(lowerQuery) ||
          group.contains(lowerQuery) ||
          comment.contains(lowerQuery);
    }).toList(growable: false);
  }

  static void sortSources(
    List<BookSource> list, {
    required SourceSortMode sortMode,
    required bool sortAscending,
    required bool groupSourcesByDomain,
    required Map<String, String> hostMap,
  }) {
    String hostOf(String url) {
      return hostMap.putIfAbsent(url, () => SourceHostGroupHelper.groupHost(url));
    }

    if (groupSourcesByDomain) {
      list.sort((a, b) {
        final hostA = hostOf(a.bookSourceUrl);
        final hostB = hostOf(b.bookSourceUrl);
        final invalidA = hostA == '#';
        final invalidB = hostB == '#';
        if (invalidA != invalidB) {
          return invalidA ? 1 : -1;
        }
        final hostCompare = hostA.compareTo(hostB);
        if (hostCompare != 0) return hostCompare;
        return b.lastUpdateTime.compareTo(a.lastUpdateTime);
      });
      return;
    }

    int compareByMode(BookSource a, BookSource b) {
      switch (sortMode) {
        case SourceSortMode.manual:
          return a.customOrder.compareTo(b.customOrder);
        case SourceSortMode.weight:
          return a.weight.compareTo(b.weight);
        case SourceSortMode.name:
          return SearchScopeGroupHelper.cnCompareLikeLegado(
            a.bookSourceName,
            b.bookSourceName,
          );
        case SourceSortMode.url:
          return a.bookSourceUrl.compareTo(b.bookSourceUrl);
        case SourceSortMode.update:
          return b.lastUpdateTime.compareTo(a.lastUpdateTime);
        case SourceSortMode.respond:
          return a.respondTime.compareTo(b.respondTime);
        case SourceSortMode.enabled:
          final enabledCompare =
              a.enabled == b.enabled ? 0 : (a.enabled ? -1 : 1);
          if (enabledCompare != 0) return enabledCompare;
          return SearchScopeGroupHelper.cnCompareLikeLegado(
            a.bookSourceName,
            b.bookSourceName,
          );
      }
    }

    list.sort((a, b) {
      if (sortMode == SourceSortMode.enabled) {
        final enabledCompare = sortAscending
            ? (a.enabled == b.enabled ? 0 : (a.enabled ? -1 : 1))
            : (a.enabled == b.enabled ? 0 : (a.enabled ? 1 : -1));
        if (enabledCompare != 0) return enabledCompare;
        return SearchScopeGroupHelper.cnCompareLikeLegado(
          a.bookSourceName,
          b.bookSourceName,
        );
      }
      final compare = compareByMode(a, b);
      return sortAscending ? compare : -compare;
    });
  }

  static String buildCheckTaskProgressText(SourceCheckTaskSnapshot snapshot) {
    final items = snapshot.items;
    final total = items.length;
    final done =
        items.where((item) => item.status != SourceCheckStatus.pending).length;
    final runningItem = items.where((item) => item.status == SourceCheckStatus.running);
    final runningName = runningItem.isEmpty
        ? ''
        : ' · ${runningItem.first.source.bookSourceName}';
    if (snapshot.stopRequested) {
      return '正在停止校验（$done/$total）$runningName';
    }
    return '校验进行中（$done/$total）$runningName';
  }

  static bool matchesGroupQueryLegacy(String? rawGroup, String key) {
    final group = rawGroup ?? '';
    if (group == key) return true;
    if (group.startsWith('$key,')) return true;
    if (group.endsWith(',$key')) return true;
    if (group.contains(',$key,')) return true;
    return false;
  }

  static List<String> splitGroups(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return <String>[];
    return text
        .split(RegExp(r'[,;，；]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static String? joinGroups(List<String> groups) {
    if (groups.isEmpty) return null;
    return groups.toSet().join(',');
  }

  static bool hasInvalidGroup(List<BookSource> allSources) {
    return allSources.any((source) {
      final groups = SourceCheckSourceStateHelper.splitGroups(
        source.bookSourceGroup,
      );
      return groups.any((group) => group.contains('失效'));
    });
  }
}
