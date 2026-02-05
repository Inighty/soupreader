import 'dart:convert';

import '../../../features/source/models/book_source.dart';
import '../database_service.dart';
import '../entities/book_entity.dart';

/// 书源存储仓库
class SourceRepository {
  final DatabaseService _db;

  SourceRepository(this._db);

  List<BookSource> getAllSources() {
    return _db.sourcesBox.values.map(_entityToSource).toList();
  }

  BookSource? getSourceByUrl(String url) {
    final entity = _db.sourcesBox.get(url);
    return entity != null ? _entityToSource(entity) : null;
  }

  Future<void> addSource(BookSource source) async {
    await _db.sourcesBox.put(source.bookSourceUrl, _sourceToEntity(source));
  }

  Future<void> addSources(List<BookSource> sources) async {
    final entries = <String, BookSourceEntity>{};
    for (final source in sources) {
      entries[source.bookSourceUrl] = _sourceToEntity(source);
    }
    await _db.sourcesBox.putAll(entries);
  }

  Future<void> updateSource(BookSource source) async {
    await addSource(source);
  }

  Future<void> deleteSource(String url) async {
    await _db.sourcesBox.delete(url);
  }

  Future<void> deleteDisabledSources() async {
    final disabled = _db.sourcesBox.values
        .where((source) => !source.enabled)
        .map((source) => source.bookSourceUrl)
        .toList();
    await _db.sourcesBox.deleteAll(disabled);
  }

  List<BookSource> fromEntities(Iterable<BookSourceEntity> entities) {
    return entities.map(_entityToSource).toList();
  }

  BookSourceEntity _sourceToEntity(BookSource source) {
    return BookSourceEntity(
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: source.bookSourceName,
      bookSourceGroup: source.bookSourceGroup,
      bookSourceType: source.bookSourceType,
      enabled: source.enabled,
      bookSourceComment: source.bookSourceComment,
      weight: source.weight,
      header: source.header,
      loginUrl: source.loginUrl,
      lastUpdateTime: source.lastUpdateTime,
      ruleSearchJson: _encodeRule(source.ruleSearch?.toJson()),
      ruleBookInfoJson: _encodeRule(source.ruleBookInfo?.toJson()),
      ruleTocJson: _encodeRule(source.ruleToc?.toJson()),
      ruleContentJson: _encodeRule(source.ruleContent?.toJson()),
    );
  }

  BookSource _entityToSource(BookSourceEntity entity) {
    return BookSource(
      bookSourceName: entity.bookSourceName,
      bookSourceUrl: entity.bookSourceUrl,
      bookSourceType: entity.bookSourceType,
      bookSourceGroup: entity.bookSourceGroup,
      bookSourceComment: entity.bookSourceComment,
      enabled: entity.enabled,
      weight: entity.weight,
      header: entity.header,
      loginUrl: entity.loginUrl,
      lastUpdateTime: entity.lastUpdateTime,
      ruleSearch: _decodeRule(entity.ruleSearchJson, SearchRule.fromJson),
      ruleBookInfo:
          _decodeRule(entity.ruleBookInfoJson, BookInfoRule.fromJson),
      ruleToc: _decodeRule(entity.ruleTocJson, TocRule.fromJson),
      ruleContent:
          _decodeRule(entity.ruleContentJson, ContentRule.fromJson),
    );
  }

  String? _encodeRule(Map<String, dynamic>? rule) {
    if (rule == null) return null;
    return json.encode(rule);
  }

  T? _decodeRule<T>(
    String? jsonString,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (jsonString == null || jsonString.trim().isEmpty) return null;
    final raw = json.decode(jsonString);
    if (raw is Map<String, dynamic>) {
      return mapper(raw);
    }
    if (raw is Map) {
      return mapper(raw.map((key, value) => MapEntry('$key', value)));
    }
    return null;
  }
}
