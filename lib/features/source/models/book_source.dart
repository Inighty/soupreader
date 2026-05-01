import 'dart:convert';

import 'package:soupreader/features/source/models/book_source_rules.dart';

export 'package:soupreader/features/source/models/book_source_rules.dart';

/// 书源模型 - 字段结构对齐 Legado（开源阅读）
///
/// 目标：
/// - JSON 字段名与 Legado 完全一致
/// - 默认不序列化 null 字段（Gson 默认行为）由上层统一处理或本类 toJson 负责
///
/// 说明：
/// - Legado 的 BookSource 中，搜索 URL 在顶层字段 `searchUrl`，而不是 ruleSearch.url
/// - 发现 URL 在顶层字段 `exploreUrl`
class BookSource {
  // 基础字段（与 Legado 对齐）
  final String bookSourceUrl;
  final String bookSourceName;
  final String? bookSourceGroup;
  final int bookSourceType;
  final String? bookUrlPattern;
  final int customOrder;
  final bool enabled;
  final bool enabledExplore;

  // BaseSource 字段（与 Legado BaseSource 对齐）
  final String? jsLib;
  final bool? enabledCookieJar;
  final String? concurrentRate;
  final String? header;
  final String? loginUrl;
  final String? loginUi;

  // 额外字段（与 Legado 对齐）
  final String? loginCheckJs;
  final String? coverDecodeJs;
  final String? bookSourceComment;
  final String? variableComment;
  final int lastUpdateTime; // Long 毫秒
  final int respondTime; // Long 毫秒
  final int weight;

  // 发现
  final String? exploreUrl;
  final String? exploreScreen;
  final ExploreRule? ruleExplore;

  // 搜索
  final String? searchUrl;
  final SearchRule? ruleSearch;

  // 详情/目录/正文/段评
  final BookInfoRule? ruleBookInfo;
  final TocRule? ruleToc;
  final ContentRule? ruleContent;
  final ReviewRule? ruleReview;

  const BookSource({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    this.bookSourceType = 0,
    this.bookUrlPattern,
    this.customOrder = 0,
    this.enabled = true,
    this.enabledExplore = true,
    this.jsLib,
    this.enabledCookieJar = false,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.bookSourceComment,
    this.variableComment,
    this.lastUpdateTime = 0,
    this.respondTime = 180000,
    this.weight = 0,
    this.exploreUrl,
    this.exploreScreen,
    this.ruleExplore,
    this.searchUrl,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.ruleReview,
  });

  String get id => bookSourceUrl;

  BookSource copyWith({
    String? bookSourceUrl,
    String? bookSourceName,
    String? bookSourceGroup,
    int? bookSourceType,
    String? bookUrlPattern,
    int? customOrder,
    bool? enabled,
    bool? enabledExplore,
    String? jsLib,
    bool? enabledCookieJar,
    String? concurrentRate,
    String? header,
    String? loginUrl,
    String? loginUi,
    String? loginCheckJs,
    String? coverDecodeJs,
    String? bookSourceComment,
    String? variableComment,
    int? lastUpdateTime,
    int? respondTime,
    int? weight,
    String? exploreUrl,
    String? exploreScreen,
    ExploreRule? ruleExplore,
    String? searchUrl,
    SearchRule? ruleSearch,
    BookInfoRule? ruleBookInfo,
    TocRule? ruleToc,
    ContentRule? ruleContent,
    ReviewRule? ruleReview,
  }) {
    return BookSource(
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
      bookSourceName: bookSourceName ?? this.bookSourceName,
      bookSourceGroup: bookSourceGroup ?? this.bookSourceGroup,
      bookSourceType: bookSourceType ?? this.bookSourceType,
      bookUrlPattern: bookUrlPattern ?? this.bookUrlPattern,
      customOrder: customOrder ?? this.customOrder,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore ?? this.enabledExplore,
      jsLib: jsLib ?? this.jsLib,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      concurrentRate: concurrentRate ?? this.concurrentRate,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      loginCheckJs: loginCheckJs ?? this.loginCheckJs,
      coverDecodeJs: coverDecodeJs ?? this.coverDecodeJs,
      bookSourceComment: bookSourceComment ?? this.bookSourceComment,
      variableComment: variableComment ?? this.variableComment,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      respondTime: respondTime ?? this.respondTime,
      weight: weight ?? this.weight,
      exploreUrl: exploreUrl ?? this.exploreUrl,
      exploreScreen: exploreScreen ?? this.exploreScreen,
      ruleExplore: ruleExplore ?? this.ruleExplore,
      searchUrl: searchUrl ?? this.searchUrl,
      ruleSearch: ruleSearch ?? this.ruleSearch,
      ruleBookInfo: ruleBookInfo ?? this.ruleBookInfo,
      ruleToc: ruleToc ?? this.ruleToc,
      ruleContent: ruleContent ?? this.ruleContent,
      ruleReview: ruleReview ?? this.ruleReview,
    );
  }

  factory BookSource.fromJson(Map<String, dynamic> json) {
    T? parseRule<T>(
      dynamic raw,
      T Function(Map<String, dynamic> map) fromMap,
    ) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) return fromMap(raw);
      if (raw is Map) {
        return fromMap(raw.map((k, v) => MapEntry(k.toString(), v)));
      }
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) return fromMap(decoded);
          if (decoded is Map) {
            return fromMap(decoded.map((k, v) => MapEntry(k.toString(), v)));
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    int parseInt(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final t = raw.trim().toLowerCase();
        if (t == 'true' || t == '1') return true;
        if (t == 'false' || t == '0') return false;
      }
      return fallback;
    }

    bool? parseNullableBool(dynamic raw) {
      if (raw == null) return null;
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final t = raw.trim().toLowerCase();
        if (t == 'true' || t == '1') return true;
        if (t == 'false' || t == '0') return false;
      }
      return null;
    }

    String? parseHeader(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) return raw;
      if (raw is Map) {
        final m = <String, String>{};
        raw.forEach((k, v) {
          if (k == null || v == null) return;
          final key = k.toString().trim();
          if (key.isEmpty) return;
          m[key] = v.toString();
        });
        if (m.isEmpty) return null;
        return jsonEncode(m);
      }
      final t = raw.toString();
      return t.trim().isEmpty ? null : t;
    }

    return BookSource(
      bookSourceUrl: (json['bookSourceUrl'] ?? '').toString().trim(),
      bookSourceName: (json['bookSourceName'] ?? '').toString(),
      bookSourceGroup: json['bookSourceGroup']?.toString(),
      bookSourceType: parseInt(json['bookSourceType'], 0),
      bookUrlPattern: json['bookUrlPattern']?.toString(),
      customOrder: parseInt(json['customOrder'], 0),
      enabled: parseBool(json['enabled'], true),
      enabledExplore: parseBool(json['enabledExplore'], true),
      jsLib: json['jsLib']?.toString(),
      enabledCookieJar: json.containsKey('enabledCookieJar')
          ? (parseNullableBool(json['enabledCookieJar']) ?? false)
          : false,
      concurrentRate: json['concurrentRate']?.toString(),
      // 对标 legado：header 允许为 JSON 字符串或 Map；统一归一为字符串，交由解析引擎兼容处理。
      header: parseHeader(json['header']),
      loginUrl: json['loginUrl']?.toString(),
      loginUi: json['loginUi']?.toString(),
      loginCheckJs: json['loginCheckJs']?.toString(),
      coverDecodeJs: json['coverDecodeJs']?.toString(),
      bookSourceComment: json['bookSourceComment']?.toString(),
      variableComment: json['variableComment']?.toString(),
      lastUpdateTime: parseInt(json['lastUpdateTime'], 0),
      respondTime: parseInt(json['respondTime'], 180000),
      weight: parseInt(json['weight'], 0),
      exploreUrl: json['exploreUrl']?.toString(),
      exploreScreen: json['exploreScreen']?.toString(),
      ruleExplore: parseRule(json['ruleExplore'], ExploreRule.fromJson),
      searchUrl: json['searchUrl']?.toString(),
      ruleSearch: parseRule(json['ruleSearch'], SearchRule.fromJson),
      ruleBookInfo: parseRule(json['ruleBookInfo'], BookInfoRule.fromJson),
      ruleToc: parseRule(json['ruleToc'], TocRule.fromJson),
      ruleContent: parseRule(json['ruleContent'], ContentRule.fromJson),
      ruleReview: parseRule(json['ruleReview'], ReviewRule.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookSourceUrl': bookSourceUrl,
      'bookSourceName': bookSourceName,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceType': bookSourceType,
      'bookUrlPattern': bookUrlPattern,
      'customOrder': customOrder,
      'enabled': enabled,
      'enabledExplore': enabledExplore,
      'jsLib': jsLib,
      'enabledCookieJar': enabledCookieJar,
      'concurrentRate': concurrentRate,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'loginCheckJs': loginCheckJs,
      'coverDecodeJs': coverDecodeJs,
      'bookSourceComment': bookSourceComment,
      'variableComment': variableComment,
      'lastUpdateTime': lastUpdateTime,
      'respondTime': respondTime,
      'weight': weight,
      'exploreUrl': exploreUrl,
      'exploreScreen': exploreScreen,
      'ruleExplore': ruleExplore?.toJson(),
      'searchUrl': searchUrl,
      'ruleSearch': ruleSearch?.toJson(),
      'ruleBookInfo': ruleBookInfo?.toJson(),
      'ruleToc': ruleToc?.toJson(),
      'ruleContent': ruleContent?.toJson(),
      'ruleReview': ruleReview?.toJson(),
    };
  }
}
