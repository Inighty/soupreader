import 'package:flutter/cupertino.dart';

import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../core/models/book_source.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../services/discovery_filter_helper.dart';

/// 当查询前缀为 `group:` 时，返回去除前缀后的分组名；否则返回 `null`。
String? resolveDiscoveryActiveGroup(String query) {
  final raw = query.trim();
  if (!raw.startsWith('group:')) return null;
  final group = raw.substring(6).trim();
  if (group.isEmpty) return null;
  return group;
}

/// 仅保留 `enabledExplore && hasExploreUrl` 的书源，并按 `customOrder` 升序。
///
/// 对齐 legado `BookSourceDao.flowExplore`：customOrder 相同时保持原序。
List<BookSource> filterDiscoveryEligibleSources(List<BookSource> input) {
  final indexed = input.asMap().entries.where((entry) {
    final source = entry.value;
    final hasExploreUrl = (source.exploreUrl ?? '').trim().isNotEmpty;
    return source.enabledExplore && hasExploreUrl;
  }).toList(growable: false);

  indexed.sort((a, b) {
    final byOrder = a.value.customOrder.compareTo(b.value.customOrder);
    if (byOrder != 0) return byOrder;
    return a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList(growable: false);
}

/// 收集所有书源出现过的分组名，按中文排序去重返回。
List<String> collectDiscoveryGroups(List<BookSource> sources) {
  final groups = <String>{};
  for (final source in sources) {
    groups.addAll(DiscoveryFilterHelper.extractGroups(source.bookSourceGroup));
  }
  final sorted = groups.toList(growable: false)
    ..sort(SearchScopeGroupHelper.cnCompareLikeLegado);
  return sorted;
}

/// 已激活的分组过滤胶囊。
class DiscoveryGroupFilterChip extends StatelessWidget {
  const DiscoveryGroupFilterChip({super.key, required this.activeGroup});

  final String activeGroup;

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    final theme = CupertinoTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: uiTokens.colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(uiTokens.radii.control),
        border: Border.all(
          color: uiTokens.colors.accent.withValues(alpha: 0.28),
          width: SourceUiTokens.borderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          '分组：$activeGroup',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: uiTokens.colors.accent,
          ),
        ),
      ),
    );
  }
}

/// 发现页空态：根据 `eligibleCount` 与 `query` 给出不同的副文案。
class DiscoveryEmptyState extends StatelessWidget {
  const DiscoveryEmptyState({
    super.key,
    required this.eligibleCount,
    required this.query,
  });

  final int eligibleCount;
  final String query;

  @override
  Widget build(BuildContext context) {
    String subtitle;
    if (eligibleCount == 0) {
      subtitle = '请在书源管理导入书源';
    } else if (query.isNotEmpty) {
      subtitle = '当前筛选条件下无书源';
    } else {
      subtitle = '请在书源管理导入书源';
    }
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(),
      title: '没有发现任何内容',
      message: subtitle,
    );
  }
}
