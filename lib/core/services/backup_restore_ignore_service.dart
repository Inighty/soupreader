import '../database/database_service.dart';
import '../models/backup_restore_ignore_config.dart';

class BackupRestoreIgnoreService {
  static final BackupRestoreIgnoreService _instance =
      BackupRestoreIgnoreService._internal();
  factory BackupRestoreIgnoreService() => _instance;
  BackupRestoreIgnoreService._internal();

  static const String _storageKey = 'backup_restore_ignore_v1';

  final DatabaseService _databaseService = DatabaseService();

  BackupRestoreIgnoreConfig load() {
    final raw = _databaseService.getSetting(
      _storageKey,
      defaultValue: const <String, dynamic>{},
    );
    return BackupRestoreIgnoreConfig.fromJson(raw);
  }

  Future<void> save(BackupRestoreIgnoreConfig config) async {
    await _databaseService.putSetting(_storageKey, config.toJson());
  }

  Future<void> saveSelectedKeys(Iterable<String> keys) async {
    final next = <String, bool>{};
    for (final rawKey in keys) {
      final key = rawKey.trim();
      if (key.isEmpty) continue;
      next[key] = true;
    }
    await save(
      BackupRestoreIgnoreConfig(
        ignoredMap: Map<String, bool>.unmodifiable(next),
      ),
    );
  }
}
