import 'package:drift/drift.dart';

import '../../../features/rss/models/rss_star.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';

/// RSS 收藏仓储（对齐 legado `RssStarDao`）
class RssStarRepository {
  final SourceDriftDatabase _driftDb;

  RssStarRepository(DatabaseService db) : _driftDb = db.driftDb;

  static Future<void> bootstrap(DatabaseService db) async {
    RssStarRepository(db);
  }

  static String _normalizeText(String? raw) {
    return (raw ?? '').trim();
  }

  static String _normalizeGroup(String? raw) {
    return (raw ?? '').trim();
  }

  Future<RssStar?> get(String origin, String link) async {
    final normalizedOrigin = _normalizeText(origin);
    final normalizedLink = _normalizeText(link);
    if (normalizedOrigin.isEmpty || normalizedLink.isEmpty) return null;
    final row = await (_driftDb.select(_driftDb.rssStarRecords)
          ..where((tbl) =>
              tbl.origin.equals(normalizedOrigin) &
              tbl.link.equals(normalizedLink)))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToModel(row);
  }

  Stream<List<String>> watchGroups() {
    final query = _driftDb.customSelect(
      '''
      select group_name
      from rss_star_records
      group by group_name
      order by group_name
      ''',
      readsFrom: <ResultSetImplementation<Table, dynamic>>{
        _driftDb.rssStarRecords,
      },
    );
    return query.watch().map((rows) {
      return rows
          .map((row) => _normalizeGroup(row.data['group_name']?.toString()))
          .where((group) => group.isNotEmpty)
          .toList(growable: false);
    });
  }

  Stream<List<RssStar>> watchByGroup(String group) {
    final key = _normalizeGroup(group);
    if (key.isEmpty) return Stream<List<RssStar>>.value(const <RssStar>[]);
    final query = _driftDb.select(_driftDb.rssStarRecords)
      ..where((tbl) => tbl.groupName.equals(key))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.starTime),
      ]);
    return query.watch().map((rows) {
      return rows.map(_rowToModel).toList(growable: false);
    });
  }

  Future<void> deleteByGroup(String group) async {
    final key = _normalizeGroup(group);
    if (key.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssStarRecords)
          ..where((tbl) => tbl.groupName.equals(key)))
        .go();
  }

  Future<void> deleteAll() async {
    await _driftDb.delete(_driftDb.rssStarRecords).go();
  }

  Future<void> upsert(RssStar star) async {
    final normalizedOrigin = _normalizeText(star.origin);
    final normalizedLink = _normalizeText(star.link);
    if (normalizedOrigin.isEmpty || normalizedLink.isEmpty) return;
    await _driftDb.into(_driftDb.rssStarRecords).insertOnConflictUpdate(
          _toCompanion(
            star.copyWith(
              origin: normalizedOrigin,
              link: normalizedLink,
            ),
          ),
        );
  }

  Future<void> update(RssStar star) async {
    await upsert(star);
  }

  Future<void> delete(String origin, String link) async {
    final normalizedOrigin = _normalizeText(origin);
    final normalizedLink = _normalizeText(link);
    if (normalizedOrigin.isEmpty || normalizedLink.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssStarRecords)
          ..where((tbl) =>
              tbl.origin.equals(normalizedOrigin) &
              tbl.link.equals(normalizedLink)))
        .go();
  }

  RssStarRecordsCompanion _toCompanion(RssStar star) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return RssStarRecordsCompanion.insert(
      origin: star.origin,
      link: star.link,
      sort: Value(star.sort),
      title: Value(star.title),
      starTime: Value(star.starTime),
      pubDate: Value(star.pubDate),
      description: Value(star.description),
      content: Value(star.content),
      image: Value(star.image),
      groupName: Value(star.group),
      variable: Value(star.variable),
      updatedAt: Value(now),
    );
  }

  static RssStar _rowToModel(RssStarRecord row) {
    return RssStar(
      origin: row.origin,
      sort: row.sort,
      title: row.title,
      starTime: row.starTime,
      link: row.link,
      pubDate: row.pubDate,
      description: row.description,
      content: row.content,
      image: row.image,
      group: row.groupName,
      variable: row.variable,
    );
  }
}
