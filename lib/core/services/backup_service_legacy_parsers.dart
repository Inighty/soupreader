import '../models/book.dart';
import '../models/book_source.dart';
import '../../features/replace/models/replace_rule.dart';

/// 解析"老版本"备份中的 Book JSON 节点（兼容字段名差异）。
Book? parseLegacyBackupBook(Map<String, dynamic> map) {
  String readText(dynamic raw) {
    if (raw == null) return '';
    return raw.toString().trim();
  }

  int readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  double readDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim()) ?? 0.0;
    return 0.0;
  }

  DateTime? readDate(dynamic raw) {
    final ms = readInt(raw);
    if (ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  final infoRaw = map['bookInfoBean'];
  final info = infoRaw is Map
      ? infoRaw.map((k, v) => MapEntry('$k', v))
      : const <String, dynamic>{};

  var title = readText(map['title']);
  if (title.isEmpty) title = readText(info['name']);
  var author = readText(map['author']);
  if (author.isEmpty) author = readText(info['author']);
  final bookUrl = readText(map['bookUrl']).isNotEmpty
      ? readText(map['bookUrl'])
      : readText(map['noteUrl']);
  if (title.isEmpty && bookUrl.isEmpty) return null;
  final idCandidate = readText(map['id']);
  final resolvedId = idCandidate.isNotEmpty
      ? idCandidate
      : (bookUrl.isNotEmpty
          ? bookUrl
          : '${title}_${author}_${DateTime.now().millisecondsSinceEpoch}');
  final totalChapters = readInt(map['totalChapters']) > 0
      ? readInt(map['totalChapters'])
      : readInt(map['chapterListSize']);
  final currentChapter = readInt(map['currentChapter']) > 0
      ? readInt(map['currentChapter'])
      : readInt(map['durChapter']);

  final explicitProgress = readDouble(map['readProgress']);
  final readProgress = explicitProgress > 0
      ? explicitProgress.clamp(0.0, 1.0)
      : (totalChapters > 0 ? (currentChapter / totalChapters) : 0.0)
          .clamp(0.0, 1.0);

  final origin = readText(map['origin']);
  final isLocal = map['isLocal'] == true || origin == 'loc_book';
  final coverUrl = readText(map['coverUrl']).isNotEmpty
      ? readText(map['coverUrl'])
      : readText(info['coverUrl']);
  final latestChapter = readText(map['latestChapter']).isNotEmpty
      ? readText(map['latestChapter'])
      : readText(map['lastChapterName']);
  final intro = readText(map['intro']).isNotEmpty
      ? readText(map['intro'])
      : readText(info['introduce']);

  return Book(
    id: resolvedId,
    title: title.isEmpty ? '未命名书籍' : title,
    author: author.isEmpty ? '未知' : author,
    coverUrl: coverUrl.isEmpty ? null : coverUrl,
    intro: intro.isEmpty ? null : intro,
    sourceUrl: readText(map['sourceUrl']).isEmpty
        ? null
        : readText(map['sourceUrl']),
    bookUrl: bookUrl.isEmpty ? null : bookUrl,
    latestChapter: latestChapter.isEmpty ? null : latestChapter,
    totalChapters: totalChapters < 0 ? 0 : totalChapters,
    currentChapter: currentChapter < 0 ? 0 : currentChapter,
    readProgress: readProgress,
    lastReadTime:
        readDate(map['lastReadTime']) ?? readDate(map['durChapterTime']),
    addedTime: readDate(map['addedTime']) ?? readDate(map['finalDate']),
    isLocal: isLocal,
    localPath: readText(map['localPath']).isEmpty
        ? null
        : readText(map['localPath']),
  );
}

BookSource? parseLegacyBackupSource(Map<String, dynamic> map) {
  try {
    final source = BookSource.fromJson(map);
    if (source.bookSourceUrl.trim().isEmpty) {
      return null;
    }
    return source;
  } catch (_) {
    return null;
  }
}

ReplaceRule? parseLegacyBackupReplaceRule(
  Map<String, dynamic> map, {
  required int fallbackIdSeed,
}) {
  try {
    final withId = Map<String, dynamic>.from(map);
    final rawId = withId['id'];
    final hasValidId = rawId is num ||
        (rawId is String && int.tryParse(rawId.trim()) != null);
    if (!hasValidId) {
      withId['id'] = DateTime.now().millisecondsSinceEpoch + fallbackIdSeed;
    }
    return ReplaceRule.fromJson(withId);
  } catch (_) {
    return null;
  }
}
