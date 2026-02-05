import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../../features/reader/models/reading_settings.dart';

/// 全局设置服务
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyReadingSettings = 'reading_settings';
  static const String _keyAppSettings = 'app_settings';
  static const String _keyBookReadingSettingsPrefix = 'book_reading_settings_';

  late SharedPreferences _prefs;
  late ReadingSettings _readingSettings;
  late AppSettings _appSettings;
  final ValueNotifier<AppSettings> _appSettingsNotifier =
      ValueNotifier(const AppSettings());

  ReadingSettings get readingSettings => _readingSettings;
  AppSettings get appSettings => _appSettings;
  ValueListenable<AppSettings> get appSettingsListenable =>
      _appSettingsNotifier;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final jsonStr = _prefs.getString(_keyReadingSettings);
    if (jsonStr != null) {
      try {
        _readingSettings = ReadingSettings.fromJson(json.decode(jsonStr));
      } catch (e) {
        _readingSettings = const ReadingSettings();
      }
    } else {
      _readingSettings = const ReadingSettings();
    }

    final appJson = _prefs.getString(_keyAppSettings);
    if (appJson != null) {
      try {
        _appSettings = AppSettings.fromJson(json.decode(appJson));
      } catch (_) {
        _appSettings = const AppSettings();
      }
    } else {
      _appSettings = const AppSettings();
    }
    _appSettingsNotifier.value = _appSettings;
  }

  Future<void> saveReadingSettings(ReadingSettings settings) async {
    _readingSettings = settings;
    await _prefs.setString(_keyReadingSettings, json.encode(settings.toJson()));
  }

  String _bookReadingSettingsKey(String bookId) =>
      '$_keyBookReadingSettingsPrefix$bookId';

  bool hasBookReadingSettings(String bookId) {
    final jsonStr = _prefs.getString(_bookReadingSettingsKey(bookId));
    return jsonStr != null && jsonStr.trim().isNotEmpty;
  }

  ReadingSettings? getBookReadingSettings(String bookId) {
    final jsonStr = _prefs.getString(_bookReadingSettingsKey(bookId));
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final raw = json.decode(jsonStr);
      if (raw is Map<String, dynamic>) {
        return ReadingSettings.fromJson(raw);
      }
      if (raw is Map) {
        return ReadingSettings.fromJson(
          raw.map((key, value) => MapEntry('$key', value)),
        );
      }
    } catch (_) {}
    return null;
  }

  ReadingSettings getEffectiveReadingSettingsForBook(String bookId) {
    return getBookReadingSettings(bookId) ?? _readingSettings;
  }

  Future<void> saveBookReadingSettings(
    String bookId,
    ReadingSettings settings,
  ) async {
    await _prefs.setString(
      _bookReadingSettingsKey(bookId),
      json.encode(settings.toJson()),
    );
  }

  Future<void> clearBookReadingSettings(String bookId) async {
    await _prefs.remove(_bookReadingSettingsKey(bookId));
  }

  Map<String, ReadingSettings> exportAllBookReadingSettings() {
    final result = <String, ReadingSettings>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_keyBookReadingSettingsPrefix)) continue;
      final bookId = key.substring(_keyBookReadingSettingsPrefix.length);
      final settings = getBookReadingSettings(bookId);
      if (settings != null) {
        result[bookId] = settings;
      }
    }
    return result;
  }

  Future<void> clearAllBookReadingSettings() async {
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(_keyBookReadingSettingsPrefix))
        .toList(growable: false);
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    _appSettings = settings;
    _appSettingsNotifier.value = settings;
    await _prefs.setString(_keyAppSettings, json.encode(settings.toJson()));
  }

  /// 保存特定书籍的滚动偏移量 (临时方案，可考虑存入 Hive)
  Future<void> saveScrollOffset(String bookId, double offset) async {
    await _prefs.setDouble('scroll_offset_$bookId', offset);
  }

  double getScrollOffset(String bookId) {
    return _prefs.getDouble('scroll_offset_$bookId') ?? 0.0;
  }
}
