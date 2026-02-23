import '../../../core/database/database_service.dart';
import '../models/remote_server.dart';

/// 远程书籍服务器配置持久层。
///
/// 对齐 legado `servers` 表与 `remoteServerId` 偏好键的最小能力：
/// - 持久化服务器列表；
/// - 持久化当前选中服务器 id（`-1` 表示默认 WebDav）。
class RemoteServerStore {
  RemoteServerStore({DatabaseService? database})
      : _database = database ?? DatabaseService();

  static const String _serversSettingKey = 'remote_books.servers';
  static const String _selectedServerIdSettingKey = 'remoteServerId';

  final DatabaseService _database;

  List<RemoteServer> getServers() {
    final raw = _database.getSetting(_serversSettingKey);
    if (raw is! List) return const <RemoteServer>[];
    final servers = <RemoteServer>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        servers.add(RemoteServer.fromJson(item));
        continue;
      }
      if (item is Map) {
        servers.add(
          RemoteServer.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        );
      }
    }
    return servers;
  }

  Future<void> saveServers(List<RemoteServer> servers) async {
    await _database.putSetting(
      _serversSettingKey,
      servers.map((server) => server.toJson()).toList(),
    );
  }

  int getSelectedServerId({
    int fallback = RemoteServer.defaultServerId,
  }) {
    final raw = _database.getSetting(
      _selectedServerIdSettingKey,
      defaultValue: fallback,
    );
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      return int.tryParse(raw.trim()) ?? fallback;
    }
    return fallback;
  }

  Future<void> saveSelectedServerId(int serverId) async {
    await _database.putSetting(_selectedServerIdSettingKey, serverId);
  }

  RemoteServer? getServerById(int serverId) {
    for (final server in getServers()) {
      if (server.id == serverId) return server;
    }
    return null;
  }

  Future<void> upsertServer(RemoteServer server) async {
    final servers = getServers();
    final index = servers.indexWhere((item) => item.id == server.id);
    if (index >= 0) {
      servers[index] = server;
    } else {
      servers.add(server);
    }
    await saveServers(servers);
  }

  Future<void> deleteServer(int serverId) async {
    final servers = getServers()
      ..removeWhere((server) => server.id == serverId);
    await saveServers(servers);
  }
}
