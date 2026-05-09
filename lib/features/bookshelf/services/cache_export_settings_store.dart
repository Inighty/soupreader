import '../../../core/database/database_service.dart';

/// CacheExport 相关 setting key + get/save。
///
/// 把所有设置访问从 [CacheExportTaskService] 抽离，让主类只关心导出业务流程。
class CacheExportSettingsStore {
  CacheExportSettingsStore(this._database);

  static const String _exportDirectorySettingKey =
      'bookshelf.cache.export_directory';
  static const String _enableCustomExportSettingKey = 'enableCustomExport';
  static const String _exportToWebDavSettingKey = 'webDavCacheBackup';
  static const String _exportNoChapterNameSettingKey = 'exportNoChapterName';
  static const String _exportUseReplaceSettingKey = 'exportUseReplace';
  static const String _exportPictureFileSettingKey = 'exportPictureFile';
  static const String _parallelExportBookSettingKey = 'parallelExportBook';
  static const String _bookExportFileNameSettingKey = 'bookExportFileName';
  static const String _exportTypeSettingKey = 'exportType';
  static const String _exportCharsetSettingKey = 'exportCharset';

  static const List<String> legacyExportTypes = <String>['txt', 'epub'];
  static const String defaultExportCharset = 'UTF-8';

  final DatabaseService _database;

  String? getSavedExportDirectory() {
    final raw = _database.getSetting(
      _exportDirectorySettingKey,
      defaultValue: null,
    );
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveExportDirectory(String directoryPath) async {
    final normalized = directoryPath.trim();
    if (normalized.isEmpty) return;
    await _database.putSetting(_exportDirectorySettingKey, normalized);
  }

  bool getEnableCustomExport() =>
      _readBool(_enableCustomExportSettingKey, fallback: false);

  Future<void> saveEnableCustomExport(bool enabled) =>
      _database.putSetting(_enableCustomExportSettingKey, enabled);

  bool getExportToWebDav() =>
      _readBool(_exportToWebDavSettingKey, fallback: false);

  Future<void> saveExportToWebDav(bool enabled) =>
      _database.putSetting(_exportToWebDavSettingKey, enabled);

  bool getExportNoChapterName() =>
      _readBool(_exportNoChapterNameSettingKey, fallback: false);

  Future<void> saveExportNoChapterName(bool enabled) =>
      _database.putSetting(_exportNoChapterNameSettingKey, enabled);

  bool getExportUseReplace() =>
      _readBool(_exportUseReplaceSettingKey, fallback: true);

  Future<void> saveExportUseReplace(bool enabled) =>
      _database.putSetting(_exportUseReplaceSettingKey, enabled);

  bool getExportPictureFile() =>
      _readBool(_exportPictureFileSettingKey, fallback: false);

  Future<void> saveExportPictureFile(bool enabled) =>
      _database.putSetting(_exportPictureFileSettingKey, enabled);

  bool getParallelExportBook() =>
      _readBool(_parallelExportBookSettingKey, fallback: false);

  Future<void> saveParallelExportBook(bool enabled) =>
      _database.putSetting(_parallelExportBookSettingKey, enabled);

  String? getBookExportFileName() {
    final raw = _database.getSetting(
      _bookExportFileNameSettingKey,
      defaultValue: null,
    );
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString();
  }

  Future<void> saveBookExportFileName(String? jsRule) =>
      _database.putSetting(_bookExportFileNameSettingKey, jsRule);

  int getExportTypeIndex() {
    final raw = _database.getSetting(_exportTypeSettingKey, defaultValue: 0);
    if (raw is num) return _normalizeIndex(raw.toInt());
    if (raw is bool) return raw ? 1 : 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return 0;
    final numeric = int.tryParse(text);
    if (numeric != null) return _normalizeIndex(numeric);
    final index = legacyExportTypes.indexOf(text);
    return index >= 0 ? index : 0;
  }

  String getExportTypeName() => legacyExportTypes[getExportTypeIndex()];

  List<String> getExportTypeOptions() =>
      List<String>.unmodifiable(legacyExportTypes);

  Future<void> saveExportTypeIndex(int index) =>
      _database.putSetting(_exportTypeSettingKey, _normalizeIndex(index));

  String getExportCharset() {
    final raw =
        _database.getSetting(_exportCharsetSettingKey, defaultValue: null);
    final value = raw?.toString() ?? '';
    if (value.trim().isEmpty) return defaultExportCharset;
    return value;
  }

  Future<void> saveExportCharset(String charset) =>
      _database.putSetting(_exportCharsetSettingKey, charset);

  bool _readBool(String key, {required bool fallback}) {
    final raw = _database.getSetting(key, defaultValue: fallback);
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }

  int _normalizeIndex(int index) {
    if (index < 0 || index >= legacyExportTypes.length) return 0;
    return index;
  }
}
