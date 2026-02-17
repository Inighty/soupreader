import 'dart:convert';

class SourceLoginUiRow {
  final String name;
  final String type;
  final String? action;

  const SourceLoginUiRow({
    required this.name,
    required this.type,
    required this.action,
  });

  bool get isTextLike => type == 'text' || type == 'password';

  bool get isPassword => type == 'password';

  bool get isButton => type == 'button';
}

class SourceLoginUiHelper {
  const SourceLoginUiHelper._();

  static bool hasLoginUi(String? raw) {
    return parseRows(raw).isNotEmpty;
  }

  static bool isAbsUrl(String raw) {
    final t = raw.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  static List<SourceLoginUiRow> parseRows(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return const <SourceLoginUiRow>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return const <SourceLoginUiRow>[];
    }
    if (decoded is! List) return const <SourceLoginUiRow>[];

    final out = <SourceLoginUiRow>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final normalized = item.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      final name = (normalized['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final rawType = (normalized['type'] ?? 'text').toString().trim();
      final lowerType = rawType.toLowerCase();
      final type = switch (lowerType) {
        'password' => 'password',
        'button' => 'button',
        _ => 'text',
      };
      final actionRaw = normalized['action']?.toString();
      final action = actionRaw == null || actionRaw.trim().isEmpty
          ? null
          : actionRaw.trim();

      out.add(
        SourceLoginUiRow(
          name: name,
          type: type,
          action: action,
        ),
      );
    }
    return out;
  }
}
