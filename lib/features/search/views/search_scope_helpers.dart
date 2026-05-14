import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/book_source.dart';
import '../models/search_scope.dart';
import '../services/search_aggregator.dart';

class SearchScopeHelpers {
  SearchScopeHelpers._();

  static AppSettings sanitizeSettings(AppSettings settings) {
    final filterMode = normalizeSearchFilterMode(settings.searchFilterMode);
    if (filterMode == settings.searchFilterMode) return settings;
    return settings.copyWith(searchFilterMode: filterMode);
  }

  static Set<String> normalizeUrlSet(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static List<BookSource> allSources({
    required SourceRepository repo,
    required List<String>? scopedUrls,
  }) {
    final all = repo.getAllSources();
    if (scopedUrls == null || scopedUrls.isEmpty) return all;
    final allowed = normalizeUrlSet(scopedUrls);
    if (allowed.isEmpty) return const <BookSource>[];
    return all
        .where((s) => allowed.contains(s.bookSourceUrl.trim()))
        .toList(growable: false);
  }

  static List<BookSource> allEnabledSources(List<BookSource> allSources) {
    return allSources
        .where((s) => s.enabled && s.enabledExplore)
        .toList(growable: false);
  }

  static ResolvedSearchScope resolveSearchScope({
    required String scopeText,
    required List<BookSource> allSources,
    required List<BookSource> enabledSources,
  }) {
    final resolved = SearchScope(scopeText).resolve(
      enabledSources,
      allSourcesForSourceMode: allSources,
    );
    return ResolvedSearchScope(
      allSources: allSources,
      allEnabledSources: enabledSources,
      resolvedScope: resolved,
    );
  }
}
