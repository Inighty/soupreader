import '../../../core/database/database_service.dart';

class OtherSourceSettingsService {
  static const String keyUserAgent = 'userAgent';
  static const String keyDefaultBookTreeUri = 'defaultBookTreeUri';
  static const String keySourceEditMaxLine = 'sourceEditMaxLine';

  static const int minSourceEditMaxLine = 10;
  static const int defaultSourceEditMaxLine = 2147483647;
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  final DatabaseService _database;

  OtherSourceSettingsService({
    DatabaseService? database,
  }) : _database = database ?? DatabaseService();

  String getUserAgent() {
    final raw = _database.getSetting(keyUserAgent);
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return defaultUserAgent;
  }

  Future<void> saveUserAgent(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await _database.deleteSetting(keyUserAgent);
      return;
    }
    await _database.putSetting(keyUserAgent, normalized);
  }

  String? getDefaultBookTreeUri() {
    final raw = _database.getSetting(keyDefaultBookTreeUri);
    if (raw is String) {
      final text = raw.trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }

  Future<void> saveDefaultBookTreeUri(String? value) async {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      await _database.deleteSetting(keyDefaultBookTreeUri);
      return;
    }
    await _database.putSetting(keyDefaultBookTreeUri, normalized);
  }

  int getSourceEditMaxLine() {
    final raw = _database.getSetting(
      keySourceEditMaxLine,
      defaultValue: defaultSourceEditMaxLine,
    );
    int parsed;
    if (raw is int) {
      parsed = raw;
    } else if (raw is num) {
      parsed = raw.toInt();
    } else if (raw is String) {
      parsed = int.tryParse(raw.trim()) ?? defaultSourceEditMaxLine;
    } else {
      parsed = defaultSourceEditMaxLine;
    }
    return parsed >= minSourceEditMaxLine ? parsed : defaultSourceEditMaxLine;
  }

  Future<void> saveSourceEditMaxLine(int value) async {
    final normalized =
        value >= minSourceEditMaxLine ? value : defaultSourceEditMaxLine;
    await _database.putSetting(keySourceEditMaxLine, normalized);
  }

  String sourceEditMaxLineSummary(int value) {
    return '$value,设置行数小于屏幕可显示的最大行数可以更方便的滑动到其他的字段进行编辑';
  }
}
