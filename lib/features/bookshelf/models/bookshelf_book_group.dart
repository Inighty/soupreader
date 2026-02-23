import 'dart:convert';

/// 书架分组模型（对齐 legado BookGroup 的最小承载字段）。
class BookshelfBookGroup {
  const BookshelfBookGroup({
    required this.groupId,
    required this.groupName,
    required this.show,
    required this.order,
    this.cover,
    required this.bookSort,
    required this.enableRefresh,
  });

  static const int longMinValue = -9223372036854775808;
  static const int idAll = -1;
  static const int idLocal = -2;
  static const int idAudio = -3;
  static const int idNetNone = -4;
  static const int idLocalNone = -5;
  static const int idError = -11;

  final int groupId;
  final String groupName;
  final bool show;
  final int order;
  final String? cover;
  final int bookSort;
  final bool enableRefresh;

  bool get isCustomGroup => groupId > 0 || groupId == longMinValue;

  String get manageName {
    switch (groupId) {
      case idAll:
        return '$groupName(全部)';
      case idAudio:
        return '$groupName(音频)';
      case idLocal:
        return '$groupName(本地)';
      case idNetNone:
        return '$groupName(网络未分组)';
      case idLocalNone:
        return '$groupName(本地未分组)';
      case idError:
        return '$groupName(更新失败)';
      default:
        return groupName;
    }
  }

  BookshelfBookGroup copyWith({
    int? groupId,
    String? groupName,
    bool? show,
    int? order,
    String? cover,
    bool clearCover = false,
    int? bookSort,
    bool? enableRefresh,
  }) {
    return BookshelfBookGroup(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      show: show ?? this.show,
      order: order ?? this.order,
      cover: clearCover ? null : (cover ?? this.cover),
      bookSort: bookSort ?? this.bookSort,
      enableRefresh: enableRefresh ?? this.enableRefresh,
    );
  }

  factory BookshelfBookGroup.fromJson(Map<String, dynamic> json) {
    String parseName(dynamic raw) {
      final value = (raw ?? '').toString().trim();
      return value;
    }

    int parseInt(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        return int.tryParse(raw.trim()) ?? fallback;
      }
      return fallback;
    }

    bool parseBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }

    final name = parseName(json['groupName']);
    return BookshelfBookGroup(
      groupId: parseInt(json['groupId'], 0),
      groupName: name,
      show: parseBool(json['show'], true),
      order: parseInt(json['order'], 0),
      cover: parseName(json['cover']).isEmpty ? null : parseName(json['cover']),
      bookSort: parseInt(json['bookSort'], -1),
      enableRefresh: parseBool(json['enableRefresh'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'groupId': groupId,
      'groupName': groupName,
      'show': show,
      'order': order,
      'cover': cover,
      'bookSort': bookSort,
      'enableRefresh': enableRefresh,
    };
  }

  static List<BookshelfBookGroup> listFromJsonText(String text) {
    final decoded = json.decode(text);
    if (decoded is! List) return const <BookshelfBookGroup>[];
    final groups = <BookshelfBookGroup>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final normalized = item.map((key, value) => MapEntry('$key', value));
      final group = BookshelfBookGroup.fromJson(normalized);
      if (group.groupName.trim().isEmpty) continue;
      groups.add(group);
    }
    groups.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
    return groups;
  }

  static String listToJsonText(List<BookshelfBookGroup> groups) {
    final list = groups.map((group) => group.toJson()).toList(growable: false);
    return json.encode(list);
  }
}
