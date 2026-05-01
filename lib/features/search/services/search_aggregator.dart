import 'dart:collection';

import '../../../core/models/book_source.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../models/search_scope.dart';
class ResolvedSearchScope {
  final List<BookSource> allSources;
  final List<BookSource> allEnabledSources;
  final SearchScopeResolveResult resolvedScope;

  const ResolvedSearchScope({
    required this.allSources,
    required this.allEnabledSources,
    required this.resolvedScope,
  });

  List<BookSource> get sources => resolvedScope.sources;
}

class SearchDisplayItem {
  final String key;
  final SearchResult primary;
  final List<SearchResult> origins;
  final bool inBookshelf;
  final String displayCoverUrl;
  final String displayCoverSourceUrl;

  const SearchDisplayItem({
    required this.key,
    required this.primary,
    required this.origins,
    required this.inBookshelf,
    required this.displayCoverUrl,
    required this.displayCoverSourceUrl,
  });
}

class LegadoSearchAggregator {
  final Map<String, SearchResult> _rawBySourceBookKey =
      <String, SearchResult>{};
  final Map<String, LegadoSearchGroup> _groupMap =
      <String, LegadoSearchGroup>{};
  int _seenOrderSeed = 0;

  void reset() {
    _rawBySourceBookKey.clear();
    _groupMap.clear();
    _seenOrderSeed = 0;
  }

  List<SearchResult> get rawResults =>
      _rawBySourceBookKey.values.toList(growable: false);

  AggregatorIngestStat ingest(List<SearchResult> incoming) {
    var changed = false;
    for (final item in incoming) {
      final normalized = _normalizeResult(item);
      if (normalized == null) continue;
      final sourceBookKey = _sourceBookKey(normalized);
      final groupKey = _groupKey(normalized);
      if (groupKey.isEmpty) continue;

      final existingRaw = _rawBySourceBookKey[sourceBookKey];
      if (existingRaw == null) {
        _rawBySourceBookKey[sourceBookKey] = normalized;
        changed = true;
      }

      final group = _groupMap[groupKey];
      if (group == null) {
        final nextGroup = LegadoSearchGroup(
          key: groupKey,
          primary: normalized,
          orderRank: _seenOrderSeed++,
        );
        nextGroup.addResult(sourceBookKey, normalized);
        _groupMap[groupKey] = nextGroup;
        changed = true;
        continue;
      }

      if (group.addResult(sourceBookKey, normalized)) {
        changed = true;
      }
    }
    return AggregatorIngestStat(changed: changed);
  }

  List<SearchDisplayItem> buildDisplayItems({
    required String searchKeyword,
    required bool precision,
    required bool Function(SearchResult item) isInBookshelf,
  }) {
    final exact = <LegadoSearchGroup>[];
    final contains = <LegadoSearchGroup>[];
    final others = <LegadoSearchGroup>[];

    final groups = _groupMap.values.toList(growable: false)
      ..sort((a, b) => a.orderRank.compareTo(b.orderRank));
    for (final group in groups) {
      final rank = _matchRank(group.primary, searchKeyword);
      if (rank == 0) {
        exact.add(group);
      } else if (rank == 1) {
        contains.add(group);
      } else if (!precision) {
        others.add(group);
      }
    }

    _stableSortByOriginCountDesc(exact);
    _stableSortByOriginCountDesc(contains);

    final ordered = <LegadoSearchGroup>[...exact, ...contains, ...others];
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].orderRank = i;
    }

    return ordered.map((group) {
      final originList = group.originRepresentatives;
      final primary = group.primary;
      return SearchDisplayItem(
        key: group.key,
        primary: primary,
        origins: originList,
        inBookshelf: isInBookshelf(primary),
        displayCoverUrl: primary.coverUrl.trim(),
        displayCoverSourceUrl: primary.sourceUrl.trim(),
      );
    }).toList(growable: false);
  }

  static void _stableSortByOriginCountDesc(List<LegadoSearchGroup> groups) {
    if (groups.length < 2) return;
    final indexed = groups.asMap().entries.toList(growable: false);
    indexed.sort((a, b) {
      final originCompare =
          b.value.origins.length.compareTo(a.value.origins.length);
      if (originCompare != 0) {
        return originCompare;
      }
      return a.key.compareTo(b.key);
    });
    groups
      ..clear()
      ..addAll(indexed.map((entry) => entry.value));
  }

  static SearchResult? _normalizeResult(SearchResult item) {
    final name = item.name.trim();
    final bookUrl = item.bookUrl.trim();
    final sourceUrl = item.sourceUrl.trim();
    if (name.isEmpty || bookUrl.isEmpty || sourceUrl.isEmpty) {
      return null;
    }
    return SearchResult(
      name: name,
      author: item.author.trim(),
      coverUrl: item.coverUrl.trim(),
      intro: item.intro.trim(),
      kind: item.kind.trim(),
      lastChapter: item.lastChapter.trim(),
      updateTime: item.updateTime.trim(),
      wordCount: item.wordCount.trim(),
      bookUrl: bookUrl,
      sourceUrl: sourceUrl,
      sourceName: () {
        final trimmed = item.sourceName.trim();
        return trimmed.isNotEmpty ? trimmed : sourceUrl;
      }(),
    );
  }

  static String _sourceBookKey(SearchResult item) =>
      '${item.sourceUrl}|${item.bookUrl}';

  static String _groupKey(SearchResult item) => '${item.name}|${item.author}';

  static int _matchRank(SearchResult result, String searchKeyword) {
    if (searchKeyword.isEmpty) return 2;
    final name = result.name;
    final author = result.author;
    if (name == searchKeyword || author == searchKeyword) {
      return 0;
    }
    if (name.contains(searchKeyword) || author.contains(searchKeyword)) {
      return 1;
    }
    return 2;
  }
}

class LegadoSearchGroup {
  final String key;
  int orderRank;
  SearchResult primary;
  final LinkedHashMap<String, SearchResult> _resultBySourceBookKey =
      LinkedHashMap<String, SearchResult>();
  final LinkedHashMap<String, SearchResult> _representativeByOrigin =
      LinkedHashMap<String, SearchResult>();

  LegadoSearchGroup({
    required this.key,
    required this.primary,
    required this.orderRank,
  });

  Set<String> get origins => _representativeByOrigin.keys.toSet();

  List<SearchResult> get originRepresentatives =>
      _representativeByOrigin.values.toList(growable: false);

  bool addResult(String sourceBookKey, SearchResult result) {
    var changed = false;
    final oldSourceBook = _resultBySourceBookKey[sourceBookKey];
    if (oldSourceBook == null) {
      _resultBySourceBookKey[sourceBookKey] = result;
      changed = true;
    }

    final originKey = result.sourceUrl;
    final oldRepresentative = _representativeByOrigin[originKey];
    if (oldRepresentative == null) {
      _representativeByOrigin[originKey] = result;
      changed = true;
    }

    return changed;
  }
}

class AggregatorIngestStat {
  final bool changed;

  const AggregatorIngestStat({
    required this.changed,
  });
}

class SourceRunIssue {
  final String sourceName;
  final String reason;

  const SourceRunIssue({
    required this.sourceName,
    required this.reason,
  });
}
