import '../../../core/database/database_service.dart';
import '../../../core/services/exception_log_service.dart';

/// 远程书籍帮助弹层“已读版本”持久化。
///
/// 对齐 legado `LocalConfig.webDavBookHelpVersionIsLast` 语义：
/// - 同版本只自动弹出一次；
/// - 当帮助内容版本号提升后再次自动弹出一次；
/// - 版本号以 [helpVersion] 为准，后续升级仅需要修改该常量。
class RemoteBooksHelpStore {
  RemoteBooksHelpStore({
    DatabaseService? database,
    ExceptionLogService? exceptionLogService,
  })  : _database = database ?? DatabaseService(),
        _exceptionLogService = exceptionLogService ?? ExceptionLogService();

  /// 帮助内容版本号：后续帮助内容有变更时，仅修改这里即可触发再次自动弹出。
  static const int helpVersion = 1;

  /// 与 legado 偏好键保持同名，便于对照与迁移一致性确认。
  static const String _readVersionSettingKey = 'webDavBookHelpVersion';

  final DatabaseService _database;
  final ExceptionLogService _exceptionLogService;

  /// 是否需要在进入远程书籍页时自动弹出帮助。
  ///
  /// 说明：读取失败时降级为“不自动弹出”，避免出现无法关闭的循环弹窗；
  /// 同时会记录异常日志，便于定位持久化层问题。
  bool shouldAutoShowHelp() {
    final readVersion = getReadVersion();
    if (readVersion == null) return false;
    return readVersion < helpVersion;
  }

  /// 获取已读版本号。
  ///
  /// 返回 `null` 表示读取失败（例如数据库未初始化或数据格式异常）。
  int? getReadVersion() {
    try {
      final raw = _database.getSetting(
        _readVersionSettingKey,
        defaultValue: 0,
      );
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? 0;
      return 0;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'RemoteBooksHelpStore',
        message: '读取远程书籍帮助已读版本失败',
        error: error,
        stackTrace: stackTrace,
        context: const <String, dynamic>{
          'key': _readVersionSettingKey,
        },
      );
      return null;
    }
  }

  /// 标记当前帮助版本为“已读”。
  ///
  /// 返回 `true` 表示持久化成功；失败时返回 `false` 并记录日志（不抛出，避免影响页面主流程）。
  Future<bool> markCurrentVersionAsRead() async {
    return _saveReadVersion(helpVersion);
  }

  /// 清除已读记录（仅用于人工回归/调试）。
  ///
  /// 返回 `true` 表示清除成功；失败时返回 `false` 并记录日志。
  Future<bool> clearReadVersion() async {
    try {
      await _database.deleteSetting(_readVersionSettingKey);
      return true;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'RemoteBooksHelpStore',
        message: '清除远程书籍帮助已读版本失败',
        error: error,
        stackTrace: stackTrace,
        context: const <String, dynamic>{
          'key': _readVersionSettingKey,
        },
      );
      return false;
    }
  }

  Future<bool> _saveReadVersion(int version) async {
    try {
      await _database.putSetting(_readVersionSettingKey, version);
      return true;
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'RemoteBooksHelpStore',
        message: '保存远程书籍帮助已读版本失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'key': _readVersionSettingKey,
          'version': version,
        },
      );
      return false;
    }
  }
}
