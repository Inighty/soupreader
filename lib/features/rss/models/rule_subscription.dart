class RuleSubscription {
  const RuleSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.customOrder,
    this.autoUpdate = false,
    this.update = 0,
  });

  final int id;
  final String name;
  final String url;
  final int type;
  final int customOrder;
  final bool autoUpdate;
  final int update;

  RuleSubscription copyWith({
    int? id,
    String? name,
    String? url,
    int? type,
    int? customOrder,
    bool? autoUpdate,
    int? update,
  }) {
    return RuleSubscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      customOrder: customOrder ?? this.customOrder,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      update: update ?? this.update,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'customOrder': customOrder,
      'autoUpdate': autoUpdate,
      'update': update,
    };
  }

  static RuleSubscription? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.map((key, value) => MapEntry('$key', value));

    final id = _toInt(map['id']);
    final customOrder = _toInt(map['customOrder']);
    if (id <= 0 || customOrder <= 0) return null;

    final name = (map['name'] ?? '').toString();
    final url = (map['url'] ?? '').toString();
    if (url.trim().isEmpty) return null;

    final typeRaw = _toInt(map['type']);
    final type = switch (typeRaw) {
      1 => 1,
      2 => 2,
      _ => 0,
    };

    final autoUpdate = _toBool(map['autoUpdate']);
    final update = _toInt(map['update']);

    return RuleSubscription(
      id: id,
      name: name,
      url: url,
      type: type,
      customOrder: customOrder,
      autoUpdate: autoUpdate,
      update: update,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = '$value'.trim().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
}
