import 'dart:convert';

import '../../../core/utils/legado_json.dart';

class TxtTocRule {
  const TxtTocRule({
    required this.id,
    required this.enabled,
    required this.name,
    required this.rule,
    required this.example,
    required this.serialNumber,
  });

  final int id;
  final bool enabled;
  final String name;
  final String rule;
  final String? example;
  final int serialNumber;

  TxtTocRule copyWith({
    int? id,
    bool? enabled,
    String? name,
    String? rule,
    String? example,
    int? serialNumber,
  }) {
    return TxtTocRule(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      rule: rule ?? this.rule,
      example: example ?? this.example,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }

  factory TxtTocRule.fromJson(Map<String, dynamic> json) {
    return TxtTocRule(
      id: _toInt(json['id']),
      enabled: _toBool(json['enable'], fallback: true),
      name: _toStringOrEmpty(json['name']),
      rule: _toStringOrEmpty(json['rule']),
      example: _toNullableString(json['example']),
      serialNumber: _toInt(json['serialNumber']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'enable': enabled,
      'name': name,
      'rule': rule,
      'example': example,
      'serialNumber': serialNumber,
    };
  }

  bool sameContentAs(TxtTocRule other) {
    return id == other.id &&
        enabled == other.enabled &&
        name == other.name &&
        rule == other.rule &&
        (example ?? '') == (other.example ?? '') &&
        serialNumber == other.serialNumber;
  }

  static List<TxtTocRule> listFromJsonText(String text) {
    final dynamic decoded = json.decode(text);
    final items = <dynamic>[];
    if (decoded is List) {
      items.addAll(decoded);
    } else if (decoded is Map) {
      items.add(decoded);
    } else {
      throw const FormatException('格式不对');
    }
    final rules = <TxtTocRule>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        rules.add(TxtTocRule.fromJson(item));
        continue;
      }
      if (item is Map) {
        rules.add(
          TxtTocRule.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        );
      }
    }
    return rules;
  }

  static String listToJsonText(List<TxtTocRule> rules) {
    return LegadoJson.encode(
      rules.map((rule) => rule.toJson()).toList(growable: false),
    );
  }

  static String _toStringOrEmpty(dynamic value) {
    if (value == null) return '';
    return '$value'.trim();
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty) return null;
    return text;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value'.trim()) ?? 0;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }
}
