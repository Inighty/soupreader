import '../../replace/models/replace_rule.dart';
import '../services/reader_image_marker_codec.dart';

/// Image style constants used by the reader and scroll widgets.
class ReaderImageStyles {
  ReaderImageStyles._();

  static const String defaultStyle = 'DEFAULT';
  static const String full = 'FULL';
  static const String text = 'TEXT';
  static const String single = 'SINGLE';

  static final RegExp imgTagRegex = RegExp(
    r"""<img[^>]*src=['"]([^'"]*(?:['"][^>]+\})?)['"][^>]*>""",
    caseSensitive: false,
  );
}

/// Data models used internally by the reader view.
///
/// These were originally private classes inside `simple_reader_view.dart`.
/// Extracted to a separate file to reduce the view's line count.

class ReaderOfflineCacheInput {
  final String startChapter;
  final String endChapter;

  const ReaderOfflineCacheInput({
    required this.startChapter,
    required this.endChapter,
  });
}

class ReaderOfflineCacheRange {
  final int startIndex;
  final int endIndex;

  const ReaderOfflineCacheRange({
    required this.startIndex,
    required this.endIndex,
  });
}

enum ReaderTextActionMenuAction {
  replace,
  copy,
  bookmark,
  readAloud,
  dict,
  searchContent,
  browser,
  share,
  processText,
  more,
  collapse,
}

enum ReaderAudioPlayMenuAction {
  login,
  changeSource,
  copyAudioUrl,
  editSource,
  wakeLock,
  log,
}

class ReaderDuplicateTitleRemovalResult {
  final String content;
  final bool removed;

  const ReaderDuplicateTitleRemovalResult({
    required this.content,
    required this.removed,
  });
}

class ReaderSimulatedReadingInput {
  final bool enabled;
  final String startChapter;
  final String dailyChapters;
  final DateTime startDate;

  const ReaderSimulatedReadingInput({
    required this.enabled,
    required this.startChapter,
    required this.dailyChapters,
    required this.startDate,
  });
}

class ReaderBookmarkDraft {
  final String chapterTitle;
  final int chapterPos;
  final String pageText;

  const ReaderBookmarkDraft({
    required this.chapterTitle,
    required this.chapterPos,
    required this.pageText,
  });
}

class ReaderBookmarkEditResult {
  final String bookText;
  final String note;

  const ReaderBookmarkEditResult({
    required this.bookText,
    required this.note,
  });
}

class ReaderTipOption {
  final int value;
  final String label;

  const ReaderTipOption(this.value, this.label);
}

class EffectiveReplaceMenuEntry {
  final String label;
  final ReplaceRule? rule;
  final bool isChineseConverter;

  const EffectiveReplaceMenuEntry._({
    required this.label,
    required this.rule,
    required this.isChineseConverter,
  });

  const EffectiveReplaceMenuEntry.rule({
    required String label,
    required ReplaceRule rule,
  }) : this._(label: label, rule: rule, isChineseConverter: false);

  const EffectiveReplaceMenuEntry.chineseConverter({
    required String label,
  }) : this._(label: label, rule: null, isChineseConverter: true);
}

class ReplaceStageCache {
  final String rawTitle;
  final String rawContent;
  final String title;
  final String content;
  final List<ReplaceRule> effectiveContentReplaceRules;

  const ReplaceStageCache({
    required this.rawTitle,
    required this.rawContent,
    required this.title,
    required this.content,
    required this.effectiveContentReplaceRules,
  });
}

class ResolvedChapterSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int baseTitleHash;
  final int baseContentHash;
  final String title;
  final String content;
  final bool isDeferredPlaceholder;

  const ResolvedChapterSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.baseTitleHash,
    required this.baseContentHash,
    required this.title,
    required this.content,
    this.isDeferredPlaceholder = false,
  });
}

class ChapterImageMetaSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int contentHash;
  final List<ReaderImageMarkerMeta> metas;

  const ChapterImageMetaSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.contentHash,
    required this.metas,
  });
}

class ReaderSearchHit {
  final int chapterIndex;
  final String chapterTitle;
  final int chapterContentLength;
  final int start;
  final int end;
  final String query;
  final int occurrenceIndex;
  final String previewBefore;
  final String previewMatch;
  final String previewAfter;
  final int? pageIndex;

  const ReaderSearchHit({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.chapterContentLength,
    required this.start,
    required this.end,
    required this.query,
    required this.occurrenceIndex,
    required this.previewBefore,
    required this.previewMatch,
    required this.previewAfter,
    required this.pageIndex,
  });
}

class ReaderSearchProgressSnapshot {
  final int chapterIndex;
  final double chapterProgress;

  const ReaderSearchProgressSnapshot({
    required this.chapterIndex,
    required this.chapterProgress,
  });
}

class ScrollSegmentSeed {
  final String chapterId;
  final String title;
  final String content;

  const ScrollSegmentSeed({
    required this.chapterId,
    required this.title,
    required this.content,
  });
}

class ReaderRenderBlock {
  final String? text;
  final String? imageSrc;

  const ReaderRenderBlock._({this.text, this.imageSrc});

  const ReaderRenderBlock.text(String value) : this._(text: value);
  const ReaderRenderBlock.image(String value) : this._(imageSrc: value);

  bool get isImage => imageSrc != null;
}

class ScrollSegment {
  final int chapterIndex;
  final String chapterId;
  final String title;
  final String content;
  final double estimatedHeight;

  const ScrollSegment({
    required this.chapterIndex,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.estimatedHeight,
  });
}

class ScrollSegmentOffsetRange {
  final ScrollSegment segment;
  final double start;
  final double end;
  final double height;

  const ScrollSegmentOffsetRange({
    required this.segment,
    required this.start,
    required this.end,
    required this.height,
  });
}

class ScrollTipData {
  final String title;
  final String bookTitle;
  final double bookProgress;
  final double chapterProgress;
  final int currentPage;
  final int totalPages;
  final String currentTime;

  const ScrollTipData({
    required this.title,
    required this.bookTitle,
    required this.bookProgress,
    required this.chapterProgress,
    required this.currentPage,
    required this.totalPages,
    required this.currentTime,
  });
}
