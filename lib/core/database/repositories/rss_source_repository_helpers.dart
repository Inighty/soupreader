import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/rss/models/rss_source.dart';
import '../../utils/legado_json.dart';
import '../drift/source_drift_database.dart';

/// RSS 源仓库内部使用的字段规范化、JSON 合并与 row/model 转换辅助。
class RssSourceRepositoryHelpers {
  RssSourceRepositoryHelpers._();

  static String normalizeUrlKey(String? raw) {
    return (raw ?? '').trim();
  }

  static RssSource normalizeSource(RssSource source) {
    final normalizedUrl = normalizeUrlKey(source.sourceUrl);
    if (normalizedUrl == source.sourceUrl) return source;
    return source.copyWith(sourceUrl: normalizedUrl);
  }

  static Map<String, dynamic> decodeRawJsonToMap(String? rawJson) {
    final raw = rawJson?.trim() ?? '';
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.of(decoded);
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // ignore and fallback to empty map
    }
    return <String, dynamic>{};
  }

  static String buildMergedRawJson({
    required RssSource source,
    String? existingRawJson,
  }) {
    final normalized = normalizeSource(source);
    final merged = decodeRawJsonToMap(existingRawJson);
    merged.addAll(normalized.toJson());
    merged['sourceUrl'] = normalized.sourceUrl;
    return LegadoJson.encode(merged);
  }

  static RssSourceRecordsCompanion modelToCompanion(
    RssSource source, {
    String? rawJsonOverride,
  }) {
    final normalized = normalizeSource(source);
    final url = normalizeUrlKey(normalized.sourceUrl);
    if (url.isEmpty) {
      throw const FormatException('sourceUrl 不能为空');
    }
    final rawJson = rawJsonOverride ?? LegadoJson.encode(normalized.toJson());
    final now = DateTime.now().millisecondsSinceEpoch;
    return RssSourceRecordsCompanion.insert(
      sourceUrl: url,
      sourceName: Value(normalized.sourceName),
      sourceIcon: Value(normalized.sourceIcon),
      sourceGroup: Value(normalized.sourceGroup),
      sourceComment: Value(normalized.sourceComment),
      enabled: Value(normalized.enabled),
      loginUrl: Value(normalized.loginUrl),
      sortUrl: Value(normalized.sortUrl),
      singleUrl: Value(normalized.singleUrl),
      customOrder: Value(normalized.customOrder),
      lastUpdateTime: Value(normalized.lastUpdateTime),
      rawJson: Value(rawJson),
      updatedAt: Value(now),
    );
  }

  static RssSource rowToModel(RssSourceRecord row) {
    final raw = row.rawJson;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          return RssSource.fromJson(decoded);
        }
        if (decoded is Map) {
          return RssSource.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        // ignore and fallback
      }
    }

    return RssSource(
      sourceUrl: row.sourceUrl,
      sourceName: row.sourceName,
      sourceIcon: row.sourceIcon ?? '',
      sourceGroup: row.sourceGroup,
      sourceComment: row.sourceComment,
      enabled: row.enabled,
      loginUrl: row.loginUrl,
      sortUrl: row.sortUrl,
      singleUrl: row.singleUrl,
      customOrder: row.customOrder,
      lastUpdateTime: row.lastUpdateTime,
    );
  }
}
