import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';

typedef SourceRawUpsert = Future<void> Function({
  String? originalUrl,
  required String rawJson,
});

typedef SourceClearExploreKindsCache = Future<void> Function(BookSource source);

typedef SourceClearJsLibScope = void Function(String? jsLib);

class SourceLegacySaveService {
  SourceLegacySaveService({
    required SourceRawUpsert upsertSourceRawJson,
    required SourceClearExploreKindsCache clearExploreKindsCache,
    SourceClearJsLibScope? clearJsLibScope,
    int Function()? nowMillis,
  })  : _upsertSourceRawJson = upsertSourceRawJson,
        _clearExploreKindsCache = clearExploreKindsCache,
        _clearJsLibScope = clearJsLibScope,
        _nowMillis = nowMillis ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SourceRawUpsert _upsertSourceRawJson;
  final SourceClearExploreKindsCache _clearExploreKindsCache;
  final SourceClearJsLibScope? _clearJsLibScope;
  final int Function() _nowMillis;

  Future<BookSource> save({
    required BookSource source,
    BookSource? originalSource,
  }) async {
    final name = source.bookSourceName.trim();
    final url = source.bookSourceUrl.trim();
    if (name.isEmpty || url.isEmpty) {
      throw const FormatException('bookSourceName 与 bookSourceUrl 不能为空');
    }

    final normalizedSource = source.copyWith(
      bookSourceName: source.bookSourceName,
      bookSourceUrl: url,
    );

    final oldSource = originalSource;
    var saving = normalizedSource;
    if (_hasChanged(oldSource, normalizedSource)) {
      saving = normalizedSource.copyWith(lastUpdateTime: _nowMillis());
    }

    if (oldSource != null) {
      if ((oldSource.exploreUrl ?? '') != (saving.exploreUrl ?? '')) {
        await _clearExploreKindsCache(oldSource);
      }
      if ((oldSource.jsLib ?? '') != (saving.jsLib ?? '')) {
        _clearJsLibScope?.call(oldSource.jsLib);
      }
    }

    await _upsertSourceRawJson(
      originalUrl: oldSource?.bookSourceUrl,
      rawJson: LegadoJson.encode(saving.toJson()),
    );

    return saving;
  }

  bool _hasChanged(BookSource? oldSource, BookSource current) {
    if (oldSource == null) return true;
    return LegadoJson.encode(oldSource.toJson()) !=
        LegadoJson.encode(current.toJson());
  }
}
