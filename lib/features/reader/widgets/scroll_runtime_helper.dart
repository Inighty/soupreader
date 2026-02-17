class ScrollRuntimeHelper {
  const ScrollRuntimeHelper._();

  static List<String> splitParagraphs(String content) {
    if (content.trim().isEmpty) {
      return const <String>[];
    }
    return content
        .split(RegExp(r'\n\s*\n|\n'))
        .map((paragraph) => paragraph.trimRight())
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList(growable: false);
  }

  static bool shouldRun({
    required DateTime now,
    required DateTime lastRunAt,
    required int minIntervalMs,
  }) {
    if (minIntervalMs <= 0) {
      return true;
    }
    return now.difference(lastRunAt).inMilliseconds >= minIntervalMs;
  }
}
