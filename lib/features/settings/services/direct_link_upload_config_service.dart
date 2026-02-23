import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/database/database_service.dart';
import '../models/direct_link_upload_rule.dart';

/// 直链上传规则配置服务（对齐 legado `DirectLinkUpload` 存取语义）。
class DirectLinkUploadConfigService {
  static const String _configSettingKey = 'directLinkUploadRule.json';
  static const String _defaultAssetPath = 'assets/source/directLinkUpload.json';

  final DatabaseService _database;
  List<DirectLinkUploadRule>? _defaultRulesCache;

  DirectLinkUploadConfigService({
    DatabaseService? database,
  }) : _database = database ?? DatabaseService();

  Future<DirectLinkUploadRule> loadRule() async {
    final saved = loadSavedRule();
    if (saved != null) {
      return saved;
    }
    final defaults = await loadDefaultRules();
    if (defaults.isNotEmpty) {
      return defaults.first;
    }
    return DirectLinkUploadRule.empty();
  }

  DirectLinkUploadRule? loadSavedRule() {
    final raw = _database.getSetting(_configSettingKey, defaultValue: null);
    if (raw is Map) {
      try {
        final mapped = raw.map<String, dynamic>(
          (key, value) => MapEntry('$key', value),
        );
        return DirectLinkUploadRule.fromJson(mapped);
      } catch (_) {
        return null;
      }
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final mapped = decoded.map<String, dynamic>(
            (key, value) => MapEntry('$key', value),
          );
          return DirectLinkUploadRule.fromJson(mapped);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> saveRule(DirectLinkUploadRule rule) async {
    await _database.putSetting(_configSettingKey, rule.toJson());
  }

  Future<List<DirectLinkUploadRule>> loadDefaultRules() async {
    if (_defaultRulesCache != null) {
      return List<DirectLinkUploadRule>.from(_defaultRulesCache!);
    }
    try {
      final raw = await rootBundle.loadString(_defaultAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _defaultRulesCache = const <DirectLinkUploadRule>[];
        return const <DirectLinkUploadRule>[];
      }
      final rules = decoded.whereType<Map>().map((item) {
        final mapped = item.map<String, dynamic>(
          (key, value) => MapEntry('$key', value),
        );
        return DirectLinkUploadRule.fromJson(mapped);
      }).toList(growable: false);
      _defaultRulesCache = rules;
      return List<DirectLinkUploadRule>.from(rules);
    } catch (_) {
      _defaultRulesCache = const <DirectLinkUploadRule>[];
      return const <DirectLinkUploadRule>[];
    }
  }
}
