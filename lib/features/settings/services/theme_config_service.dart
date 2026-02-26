import 'dart:convert';

import '../../../core/database/database_service.dart';
import '../models/theme_config_entry.dart';

/// 主题配置存储服务（对齐 legado `ThemeConfig` 的导入与同名覆盖语义）。
class ThemeConfigService {
  static const String _configSettingKey = 'themeConfig.json';

  final DatabaseService _database;

  ThemeConfigService({
    DatabaseService? database,
  }) : _database = database ?? DatabaseService();

  List<ThemeConfigEntry> loadConfigs() {
    final raw = _database.getSetting(_configSettingKey, defaultValue: null);
    final decoded = _decodeStoredList(raw);
    if (decoded == null) return const <ThemeConfigEntry>[];
    final entries = <ThemeConfigEntry>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final mapped = item.map<String, dynamic>(
        (key, value) => MapEntry('$key', value),
      );
      final parsed = ThemeConfigEntry.tryParseJsonObject(mapped);
      if (parsed == null) continue;
      entries.add(parsed);
    }
    return entries;
  }

  Future<bool> importFromClipboardText(String rawText) async {
    final imported = ThemeConfigEntry.tryParseJsonText(rawText);
    if (imported == null) {
      return false;
    }
    final next = List<ThemeConfigEntry>.from(loadConfigs());
    final replaceIndex = next.indexWhere(
      (config) => config.themeName == imported.themeName,
    );
    if (replaceIndex >= 0) {
      next[replaceIndex] = imported;
    } else {
      next.add(imported);
    }
    await _saveConfigs(next);
    return true;
  }

  Future<void> _saveConfigs(List<ThemeConfigEntry> configs) async {
    final payload = configs.map((config) => config.toJson()).toList();
    await _database.putSetting(_configSettingKey, payload);
  }

  List<dynamic>? _decodeStoredList(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is String) {
      final normalized = raw.trim();
      if (normalized.isEmpty) return null;
      try {
        final decoded = jsonDecode(normalized);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
