class RemoteServer {
  static const int defaultServerId = -1;
  static const String typeWebDav = 'WEBDAV';

  final int id;
  final String name;
  final String type;
  final String url;
  final String username;
  final String password;
  final int sortNumber;

  const RemoteServer({
    required this.id,
    required this.name,
    this.type = typeWebDav,
    required this.url,
    required this.username,
    required this.password,
    this.sortNumber = 0,
  });

  factory RemoteServer.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw, {int fallback = 0}) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    String parseString(dynamic raw) {
      if (raw == null) return '';
      return raw.toString().trim();
    }

    return RemoteServer(
      id: parseInt(
        json['id'],
        fallback: DateTime.now().microsecondsSinceEpoch,
      ),
      name: parseString(json['name']),
      type: parseString(json['type']).isEmpty
          ? typeWebDav
          : parseString(json['type']),
      url: parseString(json['url']),
      username: parseString(json['username']),
      password: parseString(json['password']),
      sortNumber: parseInt(json['sortNumber']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'url': url,
      'username': username,
      'password': password,
      'sortNumber': sortNumber,
    };
  }

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final trimmedUrl = url.trim();
    if (trimmedUrl.isNotEmpty) return trimmedUrl;
    return '未命名服务器';
  }

  String get normalizedUrl {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  RemoteServer copyWith({
    int? id,
    String? name,
    String? type,
    String? url,
    String? username,
    String? password,
    int? sortNumber,
  }) {
    return RemoteServer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      sortNumber: sortNumber ?? this.sortNumber,
    );
  }
}
