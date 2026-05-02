import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/services/preferences_store.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../models/dict_rule.dart';
import 'dict_rule_html_helpers.dart';
import 'dict_rule_import_models.dart';

export 'dict_rule_import_models.dart';

class DictRuleStore {
  static const String _prefsKey = 'dict_rules';
  static const String _defaultAssetPath = 'assets/source/dictRules.json';
  static const String _requestWithoutUaSuffix = '#requestWithoutUA';
  static const int _maxImportDepth = 3;

  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Upgrade-Insecure-Requests': '1',
  };

  final Dio _httpClient;
  final PreferencesStore _preferencesStore;
  final RuleParserEngine _ruleParserEngine;

  DictRuleStore({
    Dio? httpClient,
    PreferencesStore? preferencesStore,
    RuleParserEngine? ruleParserEngine,
  })  : _httpClient = httpClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                followRedirects: true,
                maxRedirects: 8,
                headers: _defaultHeaders,
              ),
            ),
        _preferencesStore = preferencesStore ?? defaultPreferencesStore,
        _ruleParserEngine = ruleParserEngine ?? RuleParserEngine();

  Future<List<DictRule>> loadRules() async {
    final raw = (await _preferencesStore.getString(_prefsKey))?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        return DictRule.listFromJsonText(raw);
      } catch (_) {
        // 配置损坏时自动回退到默认资产，避免阻塞 menu_dict 主链路。
      }
    }
    return _loadDefaultRulesFromAsset();
  }

  Future<void> saveRules(List<DictRule> rules) async {
    await _preferencesStore.setString(_prefsKey, DictRule.listToJsonText(rules));
  }

  Future<void> saveRule({
    required String originalName,
    required DictRule newRule,
  }) async {
    final mergedByName = <String, DictRule>{
      for (final rule in await loadRules()) rule.name: rule,
    };
    mergedByName.remove(originalName);
    mergedByName[newRule.name] = newRule;
    await saveRules(mergedByName.values.toList(growable: false));
  }

  Future<List<DictRuleImportCandidate>> previewImportCandidates(
    String rawInput,
  ) async {
    final incoming = await _parseImportInput(rawInput, depth: 0);
    if (incoming.isEmpty) {
      throw const FormatException('格式不对');
    }
    final localRules = await loadRules();
    final localByName = <String, DictRule>{
      for (final rule in localRules) rule.name: rule,
    };
    return incoming.map((rule) {
      final localRule = localByName[rule.name];
      final state = _compareImportState(localRule: localRule);
      return DictRuleImportCandidate(
        rule: rule,
        localRule: localRule,
        state: state,
      );
    }).toList(growable: false);
  }

  Future<int> importCandidates({
    required List<DictRuleImportCandidate> candidates,
    required Set<int> selectedIndexes,
  }) async {
    if (selectedIndexes.isEmpty) {
      return 0;
    }
    final rules = await loadRules();
    final mergedByName = <String, DictRule>{
      for (final rule in rules) rule.name: rule,
    };
    var importedCount = 0;
    final sortedIndexes = selectedIndexes.toList()..sort();
    for (final index in sortedIndexes) {
      if (index < 0 || index >= candidates.length) {
        continue;
      }
      final candidate = candidates[index];
      mergedByName[candidate.rule.name] = candidate.rule;
      importedCount++;
    }
    await saveRules(mergedByName.values.toList(growable: false));
    return importedCount;
  }

  Future<int> importDefaultRules() async {
    final defaults = await _loadDefaultRulesFromAssetStrict();
    final mergedByName = <String, DictRule>{
      for (final rule in await loadRules()) rule.name: rule,
    };
    for (final rule in defaults) {
      mergedByName[rule.name] = rule;
    }
    await saveRules(mergedByName.values.toList(growable: false));
    return defaults.length;
  }

  Future<void> setEnabledForRuleNames({
    required Iterable<String> ruleNames,
    required bool enabled,
  }) async {
    final targetNames = ruleNames.toSet();
    if (targetNames.isEmpty) {
      return;
    }
    final rules = await loadRules();
    final updated = rules.map((rule) {
      if (!targetNames.contains(rule.name)) {
        return rule;
      }
      return rule.copyWith(enabled: enabled);
    }).toList(growable: false);
    await saveRules(updated);
  }

  Future<void> deleteRulesByNames(Iterable<String> ruleNames) async {
    final targetNames = ruleNames.toSet();
    if (targetNames.isEmpty) {
      return;
    }
    final rules = await loadRules();
    if (rules.isEmpty) {
      return;
    }
    final filtered = rules
        .where((rule) => !targetNames.contains(rule.name))
        .toList(growable: false);
    if (filtered.length == rules.length) {
      return;
    }
    await saveRules(filtered);
  }

  Future<List<DictRule>> loadEnabledRules() async {
    final rules = await loadRules();
    final enabled = rules.where((rule) => rule.enabled).toList(growable: false)
      ..sort((a, b) => a.sortNumber.compareTo(b.sortNumber));
    return enabled;
  }

  Future<String> search({
    required DictRule rule,
    required String word,
  }) async {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) return '';

    final url = _buildSearchUrl(rule.urlRule, normalizedWord);
    if (url.isEmpty) return '';

    final response = await _httpClient.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = Uint8List.fromList(response.data ?? const <int>[]);
    final body = decodeHtmlResponseBytes(bytes, response.headers);
    final baseUrl = (response.realUri.toString()).trim();
    return _applyShowRule(
      showRule: rule.showRule,
      body: body,
      baseUrl: baseUrl.isEmpty ? url : baseUrl,
    );
  }

  Future<List<DictRule>> _loadDefaultRulesFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_defaultAssetPath);
      return DictRule.listFromJsonText(raw);
    } catch (_) {
      return const <DictRule>[];
    }
  }

  Future<List<DictRule>> _loadDefaultRulesFromAssetStrict() async {
    final raw = await rootBundle.loadString(_defaultAssetPath);
    return DictRule.listFromJsonText(raw);
  }

  Future<List<DictRule>> _parseImportInput(
    String input, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      throw const FormatException('导入链接重定向层级过深');
    }
    final text = _sanitizeImportInput(input);
    if (text.isEmpty) {
      throw const FormatException('格式不对');
    }
    if (_looksLikeJson(text)) {
      return DictRule.listFromJsonText(text);
    }
    final parsedUri = Uri.tryParse(text);
    if (parsedUri != null) {
      final scheme = parsedUri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        final remoteText = await _loadTextFromUrl(text);
        return _parseImportInput(remoteText, depth: depth + 1);
      }
      if (scheme == 'file') {
        final localText = await File.fromUri(parsedUri).readAsString();
        return _parseImportInput(localText, depth: depth + 1);
      }
    }
    final localFile = File(text);
    if (await localFile.exists()) {
      final localText = await localFile.readAsString();
      return _parseImportInput(localText, depth: depth + 1);
    }
    throw const FormatException('格式不对');
  }

  Future<String> _loadTextFromUrl(String rawUrl) async {
    var url = rawUrl.trim();
    var requestWithoutUa = false;
    if (url.endsWith(_requestWithoutUaSuffix)) {
      requestWithoutUa = true;
      url = url.substring(0, url.length - _requestWithoutUaSuffix.length);
    }
    final response = await _httpClient.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: requestWithoutUa
            ? const <String, String>{'User-Agent': 'null'}
            : null,
      ),
    );
    final data = response.data;
    if (data == null || data.trim().isEmpty) {
      throw const FormatException('格式不对');
    }
    return data;
  }

  static String _sanitizeImportInput(String input) {
    var value = input.trim();
    if (value.startsWith('﻿')) {
      value = value.replaceFirst(RegExp(r'^﻿+'), '');
    }
    return value.trim();
  }

  static bool _looksLikeJson(String value) {
    return value.startsWith('{') || value.startsWith('[');
  }

  static DictRuleImportCandidateState _compareImportState({
    required DictRule? localRule,
  }) {
    if (localRule == null) {
      return DictRuleImportCandidateState.newRule;
    }
    return DictRuleImportCandidateState.existing;
  }

  String _buildSearchUrl(String urlRule, String word) {
    final normalizedRule = urlRule.trim();
    if (normalizedRule.isEmpty) return '';
    final encodedWord = Uri.encodeComponent(word);
    return normalizedRule
        .replaceAll('{{key}}', encodedWord)
        .replaceAll('{key}', encodedWord);
  }

  String _applyShowRule({
    required String showRule,
    required String body,
    required String baseUrl,
  }) {
    final ruleText = showRule.trim();
    if (ruleText.isEmpty) return body;

    if (looksLikeJsoupScript(ruleText)) {
      return applyJsoupLikeScript(
        sourceHtml: body,
        jsRule: ruleText,
      );
    }

    final document = html_parser.parse(body);
    return _ruleParserEngine
        .parseRuleForContext(document, ruleText, baseUrl)
        .trim();
  }
}
