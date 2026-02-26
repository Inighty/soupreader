import '../../../core/database/database_service.dart';
import '../models/check_source_settings.dart';

class CheckSourceSettingsService {
  static const String _prefCheckTimeoutMs = 'source_check_timeout_ms';
  static const String _prefCheckSearch = 'source_check_search';
  static const String _prefCheckDiscovery = 'source_check_discovery';
  static const String _prefCheckInfo = 'source_check_info';
  static const String _prefCheckCategory = 'source_check_category';
  static const String _prefCheckContent = 'source_check_content';
  static const String _legacySummaryKey = 'checkSource';

  final DatabaseService _database;

  CheckSourceSettingsService({
    DatabaseService? database,
  }) : _database = database ?? DatabaseService();

  CheckSourceSettings loadSettings() {
    final timeoutMs = _readInt(
      _prefCheckTimeoutMs,
      CheckSourceSettings.defaultTimeoutMs,
    );
    final checkInfo = _readBool(_prefCheckInfo, true);
    final checkCategory = checkInfo && _readBool(_prefCheckCategory, true);
    final checkContent = checkCategory && _readBool(_prefCheckContent, true);
    return CheckSourceSettings(
      timeoutMs: timeoutMs,
      checkSearch: _readBool(_prefCheckSearch, true),
      checkDiscovery: _readBool(_prefCheckDiscovery, true),
      checkInfo: checkInfo,
      checkCategory: checkCategory,
      checkContent: checkContent,
    ).normalized();
  }

  String loadSummary() {
    final raw = _database.getSetting(_legacySummaryKey);
    if (raw is String) {
      final text = raw.trim();
      if (text.isNotEmpty) return text;
    }
    return loadSettings().summary();
  }

  Future<void> saveSettings(CheckSourceSettings settings) async {
    final normalized = settings.normalized();
    await _database.putSetting(_prefCheckTimeoutMs, normalized.timeoutMs);
    await _database.putSetting(_prefCheckSearch, normalized.checkSearch);
    await _database.putSetting(_prefCheckDiscovery, normalized.checkDiscovery);
    await _database.putSetting(_prefCheckInfo, normalized.checkInfo);
    await _database.putSetting(_prefCheckCategory, normalized.checkCategory);
    await _database.putSetting(_prefCheckContent, normalized.checkContent);
    await _database.putSetting(_legacySummaryKey, normalized.summary());
  }

  bool _readBool(String key, bool fallback) {
    final value = _database.getSetting(key, defaultValue: fallback);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case '1':
        case 'true':
        case 'yes':
        case 'on':
          return true;
        case '0':
        case 'false':
        case 'no':
        case 'off':
          return false;
      }
    }
    return fallback;
  }

  int _readInt(String key, int fallback) {
    final value = _database.getSetting(key, defaultValue: fallback);
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }
}
