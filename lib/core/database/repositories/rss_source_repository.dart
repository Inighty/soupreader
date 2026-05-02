import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/rss/models/rss_source.dart';
import '../../../features/rss/services/rss_source_filter_helper.dart';
import '../../utils/legado_json.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';
import 'rss_source_repository_helpers.dart';

/// RSS 源仓库（对齐 legado `RssSourceDao` 核心语义）
class RssSourceRepository {
  final SourceDriftDatabase _driftDb;

  static final StreamController<List<RssSource>> _watchController =
      StreamController<List<RssSource>>.broadcast();
  static StreamSubscription<List<RssSourceRecord>>? _watchSub;
  static final Map<String, RssSource> _cacheByUrl = <String, RssSource>{};
  static final Map<String, String> _rawJsonByUrl = <String, String>{};
  static bool _cacheReady = false;

  RssSourceRepository(DatabaseService db) : _driftDb = db.driftDb {
    _ensureWatchStarted();
  }

  static Future<void> bootstrap(DatabaseService db) async {
    final repo = RssSourceRepository(db);
    await repo._reloadCacheFromDb();
    repo._ensureWatchStarted();
  }

  void _ensureWatchStarted() {
    if (_watchSub != null) return;
    final query = _driftDb.select(_driftDb.rssSourceRecords)
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.customOrder),
      ]);
    _watchSub = query.watch().listen((rows) {
      _updateCacheFromRows(rows);
    });
  }

  Future<void> _reloadCacheFromDb() async {
    final query = _driftDb.select(_driftDb.rssSourceRecords)
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.customOrder),
      ]);
    final rows = await query.get();
    _updateCacheFromRows(rows);
  }

  static void _updateCacheFromRows(List<RssSourceRecord> rows) {
    _cacheByUrl
      ..clear()
      ..addEntries(rows.map((row) {
        final source = RssSourceRepositoryHelpers.rowToModel(row);
        return MapEntry(source.sourceUrl, source);
      }));

    _rawJsonByUrl
      ..clear()
      ..addEntries(rows.where((row) {
        final raw = row.rawJson;
        return raw != null && raw.trim().isNotEmpty;
      }).map((row) {
        return MapEntry(row.sourceUrl, row.rawJson!.trim());
      }));

    _emitCacheSnapshot();
  }

  static void _emitCacheSnapshot() {
    _cacheReady = true;
    final sources = RssSourceFilterHelper.sortByCustomOrder(
      _cacheByUrl.values.toList(growable: false),
    );
    _watchController.add(sources);
  }

  List<RssSource> getAllSources() {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
      return const <RssSource>[];
    }
    return RssSourceFilterHelper.sortByCustomOrder(_cacheByUrl.values);
  }

  Stream<List<RssSource>> watchAllSources() async* {
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }
    yield getAllSources();
    yield* _watchController.stream;
  }

  RssSource? getByKey(String key) {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
    }
    final normalized = RssSourceRepositoryHelpers.normalizeUrlKey(key);
    if (normalized.isEmpty) return null;
    return _cacheByUrl[normalized];
  }

  String? getRawJsonByUrl(String sourceUrl) {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
    }
    final normalized = RssSourceRepositoryHelpers.normalizeUrlKey(sourceUrl);
    if (normalized.isEmpty) return null;
    return _rawJsonByUrl[normalized];
  }

  int get size => _cacheByUrl.length;

  int get minOrder {
    if (_cacheByUrl.isEmpty) return 0;
    return _cacheByUrl.values
        .map((source) => source.customOrder)
        .reduce((left, right) => left < right ? left : right);
  }

  int get maxOrder {
    if (_cacheByUrl.isEmpty) return 0;
    return _cacheByUrl.values
        .map((source) => source.customOrder)
        .reduce((left, right) => left > right ? left : right);
  }

  bool has(String key) {
    final normalized = RssSourceRepositoryHelpers.normalizeUrlKey(key);
    if (normalized.isEmpty) return false;
    return _cacheByUrl.containsKey(normalized);
  }

  Future<void> addSource(RssSource source) async {
    final normalizedSource = RssSourceRepositoryHelpers.normalizeSource(source);
    final url =
        RssSourceRepositoryHelpers.normalizeUrlKey(normalizedSource.sourceUrl);
    if (url.isEmpty) {
      throw const FormatException('sourceUrl 不能为空');
    }
    final mergedRawJson = RssSourceRepositoryHelpers.buildMergedRawJson(
      source: normalizedSource,
      existingRawJson: _rawJsonByUrl[url],
    );
    await _driftDb.into(_driftDb.rssSourceRecords).insertOnConflictUpdate(
          RssSourceRepositoryHelpers.modelToCompanion(
            normalizedSource,
            rawJsonOverride: mergedRawJson,
          ),
        );
    _cacheByUrl[url] = normalizedSource;
    _rawJsonByUrl[url] = mergedRawJson;
    _emitCacheSnapshot();
  }

  Future<void> addSources(List<RssSource> sources) async {
    if (sources.isEmpty) return;
    final normalizedSources = sources
        .map(RssSourceRepositoryHelpers.normalizeSource)
        .where((source) =>
            RssSourceRepositoryHelpers.normalizeUrlKey(source.sourceUrl)
                .isNotEmpty)
        .toList(growable: false);
    if (normalizedSources.isEmpty) return;

    final mergedRawByUrl = <String, String>{};
    final companions = normalizedSources.map((source) {
      final url = RssSourceRepositoryHelpers.normalizeUrlKey(source.sourceUrl);
      final mergedRaw = RssSourceRepositoryHelpers.buildMergedRawJson(
        source: source,
        existingRawJson: _rawJsonByUrl[url],
      );
      mergedRawByUrl[url] = mergedRaw;
      return RssSourceRepositoryHelpers.modelToCompanion(
        source,
        rawJsonOverride: mergedRaw,
      );
    }).toList(growable: false);
    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.rssSourceRecords, companions);
    });

    for (final source in normalizedSources) {
      final url = RssSourceRepositoryHelpers.normalizeUrlKey(source.sourceUrl);
      _cacheByUrl[url] = source;
      _rawJsonByUrl[url] = mergedRawByUrl[url]!;
    }
    _emitCacheSnapshot();
  }

  Future<void> updateSource(RssSource source) async {
    await addSource(source);
  }

  Future<void> updateSources(List<RssSource> sources) async {
    await addSources(sources);
  }

  Future<void> upsertSourceRawJson({
    String? originalUrl,
    required String rawJson,
  }) async {
    final decoded = json.decode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('RSS 源 JSON 必须是对象（Map）');
    }
    final map = decoded is Map<String, dynamic>
        ? decoded
        : decoded.map((key, value) => MapEntry('$key', value));

    final source = RssSourceRepositoryHelpers.normalizeSource(
      RssSource.fromJson(map),
    );
    final url = RssSourceRepositoryHelpers.normalizeUrlKey(source.sourceUrl);
    if (url.isEmpty) {
      throw const FormatException('sourceUrl 不能为空');
    }

    map['sourceUrl'] = url;
    final normalizedRawJson = LegadoJson.encode(map);
    final companion = RssSourceRepositoryHelpers.modelToCompanion(
      source,
      rawJsonOverride: normalizedRawJson,
    );
    final normalizedOriginalUrl =
        RssSourceRepositoryHelpers.normalizeUrlKey(originalUrl);

    await _driftDb.transaction(() async {
      if (normalizedOriginalUrl.isNotEmpty && normalizedOriginalUrl != url) {
        await (_driftDb.delete(_driftDb.rssSourceRecords)
              ..where((tbl) => tbl.sourceUrl.equals(normalizedOriginalUrl)))
            .go();
      }
      await _driftDb
          .into(_driftDb.rssSourceRecords)
          .insertOnConflictUpdate(companion);
    });

    if (normalizedOriginalUrl.isNotEmpty && normalizedOriginalUrl != url) {
      _cacheByUrl.remove(normalizedOriginalUrl);
      _rawJsonByUrl.remove(normalizedOriginalUrl);
    }
    _cacheByUrl[url] = source;
    _rawJsonByUrl[url] = normalizedRawJson;
    _emitCacheSnapshot();
  }

  Future<void> deleteSource(String sourceUrl) async {
    final normalized = RssSourceRepositoryHelpers.normalizeUrlKey(sourceUrl);
    if (normalized.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssSourceRecords)
          ..where((tbl) => tbl.sourceUrl.equals(normalized)))
        .go();
    _cacheByUrl.remove(normalized);
    _rawJsonByUrl.remove(normalized);
    _emitCacheSnapshot();
  }

  /// 删除 RSS 源并同步清理该源文章（对齐 legado `SourceHelp.deleteRssSourceInternal`）
  Future<void> deleteSourceWithArticles(String sourceUrl) async {
    final normalized = RssSourceRepositoryHelpers.normalizeUrlKey(sourceUrl);
    if (normalized.isEmpty) return;
    await _driftDb.transaction(() async {
      await (_driftDb.delete(_driftDb.rssSourceRecords)
            ..where((tbl) => tbl.sourceUrl.equals(normalized)))
          .go();
      await (_driftDb.delete(_driftDb.rssArticleRecords)
            ..where((tbl) => tbl.origin.equals(normalized)))
          .go();
    });
    _cacheByUrl.remove(normalized);
    _rawJsonByUrl.remove(normalized);
    _emitCacheSnapshot();
  }

  Future<void> deleteSources(Iterable<String> sourceUrls) async {
    final normalized = sourceUrls
        .map(RssSourceRepositoryHelpers.normalizeUrlKey)
        .where((url) => url.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssSourceRecords)
          ..where((tbl) => tbl.sourceUrl.isIn(normalized)))
        .go();
    for (final url in normalized) {
      _cacheByUrl.remove(url);
      _rawJsonByUrl.remove(url);
    }
    _emitCacheSnapshot();
  }

  Future<void> deleteDefault() async {
    final targets = _cacheByUrl.values.where((source) {
      return (source.sourceGroup ?? '').trim() == 'legado';
    }).toList(growable: false);
    if (targets.isEmpty) return;
    await deleteSources(targets.map((source) => source.sourceUrl));
  }

  Future<void> enable(String sourceUrl, bool enabled) async {
    final normalized = RssSourceRepositoryHelpers.normalizeUrlKey(sourceUrl);
    if (normalized.isEmpty) return;
    final existing = _cacheByUrl[normalized];
    if (existing == null) return;
    final updated = existing.copyWith(enabled: enabled);
    final mergedRawJson = RssSourceRepositoryHelpers.buildMergedRawJson(
      source: updated,
      existingRawJson: _rawJsonByUrl[normalized],
    );
    await _driftDb.into(_driftDb.rssSourceRecords).insertOnConflictUpdate(
          RssSourceRepositoryHelpers.modelToCompanion(
            updated,
            rawJsonOverride: mergedRawJson,
          ),
        );
    _cacheByUrl[normalized] = updated;
    _rawJsonByUrl[normalized] = mergedRawJson;
    _emitCacheSnapshot();
  }

  Stream<List<RssSource>> flowAll() => watchAllSources();

  Stream<List<RssSource>> flowSearch(String key) {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterSearch(sources, key),
    );
  }

  Stream<List<RssSource>> flowGroupSearch(String key) {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterGroupSearch(sources, key),
    );
  }

  Stream<List<RssSource>> flowEnabled() {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterEnabled(sources),
    );
  }

  Stream<List<RssSource>> flowDisabled() {
    return watchAllSources().map(RssSourceFilterHelper.filterDisabled);
  }

  Stream<List<RssSource>> flowLogin() {
    return watchAllSources().map(RssSourceFilterHelper.filterLogin);
  }

  Stream<List<RssSource>> flowNoGroup() {
    return watchAllSources().map(RssSourceFilterHelper.filterNoGroup);
  }

  Stream<List<RssSource>> flowEnabledSearch(String searchKey) {
    return watchAllSources().map(
      (sources) =>
          RssSourceFilterHelper.filterEnabled(sources, searchKey: searchKey),
    );
  }

  Stream<List<RssSource>> flowEnabledByGroup(String searchKey) {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterEnabledByGroup(
        sources,
        searchKey,
      ),
    );
  }

  List<String> get allGroupsUnProcessed {
    final groups = <String>{};
    for (final source in getAllSources()) {
      final raw = source.sourceGroup?.trim();
      if (raw == null || raw.isEmpty) continue;
      groups.add(raw);
    }
    return groups.toList(growable: false);
  }

  Stream<List<String>> flowGroupsUnProcessed() {
    return watchAllSources().map((sources) {
      final groups = <String>{};
      for (final source in sources) {
        final raw = source.sourceGroup?.trim();
        if (raw == null || raw.isEmpty) continue;
        groups.add(raw);
      }
      return groups.toList(growable: false);
    });
  }

  Stream<List<String>> flowEnabledGroupsUnProcessed() {
    return flowEnabled().map((sources) {
      final groups = <String>{};
      for (final source in sources) {
        final raw = source.sourceGroup?.trim();
        if (raw == null || raw.isEmpty) continue;
        groups.add(raw);
      }
      return groups.toList(growable: false);
    });
  }

  List<String> allGroups() {
    return RssSourceFilterHelper.dealGroups(allGroupsUnProcessed);
  }

  Stream<List<String>> flowGroups() {
    return flowGroupsUnProcessed().map(
      RssSourceFilterHelper.dealGroups,
    );
  }

  Stream<List<String>> flowEnabledGroups() {
    return flowEnabledGroupsUnProcessed().map(
      RssSourceFilterHelper.dealGroups,
    );
  }

  List<RssSource> getNoGroup() {
    return RssSourceFilterHelper.filterNoGroup(getAllSources());
  }

  List<RssSource> getByGroup(String group) {
    final key = group.trim();
    if (key.isEmpty) return const <RssSource>[];
    return getAllSources().where((source) {
      final raw = source.sourceGroup;
      if (raw == null || raw.isEmpty) return false;
      return raw.contains(key);
    }).toList(growable: false);
  }
}
