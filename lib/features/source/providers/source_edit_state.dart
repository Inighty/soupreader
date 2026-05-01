import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_debug/key_parser.dart';

const sourceEditSentinel = Object();

class DebugLine {
  final int state;
  final String text;

  const DebugLine({
    required this.state,
    required this.text,
  });
}

class SourceEditState {
  final BookSource source;
  final BookSource? savedSource;
  final String? currentOriginalUrl;
  final String rawJson;
  final String? jsonError;
  final bool loginStateLoading;
  final String loginHeaderCache;
  final String loginInfo;
  final bool debugLoading;
  final String? debugError;
  final List<DebugLine> debugLines;
  final List<DebugLine> debugLinesAll;
  final bool debugAutoFollowLogs;
  final String debugKey;
  final String? debugListSrcHtml;
  final String? debugBookSrcHtml;
  final String? debugTocSrcHtml;
  final String? debugContentSrcHtml;
  final String? debugContentResult;
  final String? debugMethodDecision;
  final String? debugRetryDecision;
  final String? debugRequestCharsetDecision;
  final String? debugBodyDecision;
  final String? debugResponseCharset;
  final String? debugResponseCharsetDecision;
  final Map<String, String> debugRuntimeVarsSnapshot;
  final SourceDebugIntentType? debugIntentType;
  final String? previewChapterName;
  final String? previewChapterUrl;
  final bool debugAwaitingChapterNameValue;
  final bool debugAwaitingChapterUrlValue;
  final bool showDebugQuickHelp;
  final List<MapEntry<String, String>> cachedExploreQuickEntries;
  final bool refreshingExploreQuickActions;

  const SourceEditState({
    required this.source,
    this.savedSource,
    this.currentOriginalUrl,
    required this.rawJson,
    this.jsonError,
    this.loginStateLoading = false,
    this.loginHeaderCache = '',
    this.loginInfo = '',
    this.debugLoading = false,
    this.debugError,
    this.debugLines = const [],
    this.debugLinesAll = const [],
    this.debugAutoFollowLogs = true,
    this.debugKey = '',
    this.debugListSrcHtml,
    this.debugBookSrcHtml,
    this.debugTocSrcHtml,
    this.debugContentSrcHtml,
    this.debugContentResult,
    this.debugMethodDecision,
    this.debugRetryDecision,
    this.debugRequestCharsetDecision,
    this.debugBodyDecision,
    this.debugResponseCharset,
    this.debugResponseCharsetDecision,
    this.debugRuntimeVarsSnapshot = const {},
    this.debugIntentType,
    this.previewChapterName,
    this.previewChapterUrl,
    this.debugAwaitingChapterNameValue = false,
    this.debugAwaitingChapterUrlValue = false,
    this.showDebugQuickHelp = true,
    this.cachedExploreQuickEntries = const [],
    this.refreshingExploreQuickActions = false,
  });

  SourceEditState copyWith({
    BookSource? source,
    Object? savedSource = sourceEditSentinel,
    Object? currentOriginalUrl = sourceEditSentinel,
    String? rawJson,
    Object? jsonError = sourceEditSentinel,
    bool? loginStateLoading,
    String? loginHeaderCache,
    String? loginInfo,
    bool? debugLoading,
    Object? debugError = sourceEditSentinel,
    List<DebugLine>? debugLines,
    List<DebugLine>? debugLinesAll,
    bool? debugAutoFollowLogs,
    String? debugKey,
    Object? debugListSrcHtml = sourceEditSentinel,
    Object? debugBookSrcHtml = sourceEditSentinel,
    Object? debugTocSrcHtml = sourceEditSentinel,
    Object? debugContentSrcHtml = sourceEditSentinel,
    Object? debugContentResult = sourceEditSentinel,
    Object? debugMethodDecision = sourceEditSentinel,
    Object? debugRetryDecision = sourceEditSentinel,
    Object? debugRequestCharsetDecision = sourceEditSentinel,
    Object? debugBodyDecision = sourceEditSentinel,
    Object? debugResponseCharset = sourceEditSentinel,
    Object? debugResponseCharsetDecision = sourceEditSentinel,
    Map<String, String>? debugRuntimeVarsSnapshot,
    Object? debugIntentType = sourceEditSentinel,
    Object? previewChapterName = sourceEditSentinel,
    Object? previewChapterUrl = sourceEditSentinel,
    bool? debugAwaitingChapterNameValue,
    bool? debugAwaitingChapterUrlValue,
    bool? showDebugQuickHelp,
    List<MapEntry<String, String>>? cachedExploreQuickEntries,
    bool? refreshingExploreQuickActions,
  }) {
    return SourceEditState(
      source: source ?? this.source,
      savedSource: savedSource == sourceEditSentinel
          ? this.savedSource
          : savedSource as BookSource?,
      currentOriginalUrl: currentOriginalUrl == sourceEditSentinel
          ? this.currentOriginalUrl
          : currentOriginalUrl as String?,
      rawJson: rawJson ?? this.rawJson,
      jsonError: jsonError == sourceEditSentinel
          ? this.jsonError
          : jsonError as String?,
      loginStateLoading: loginStateLoading ?? this.loginStateLoading,
      loginHeaderCache: loginHeaderCache ?? this.loginHeaderCache,
      loginInfo: loginInfo ?? this.loginInfo,
      debugLoading: debugLoading ?? this.debugLoading,
      debugError: debugError == sourceEditSentinel
          ? this.debugError
          : debugError as String?,
      debugLines: debugLines ?? this.debugLines,
      debugLinesAll: debugLinesAll ?? this.debugLinesAll,
      debugAutoFollowLogs: debugAutoFollowLogs ?? this.debugAutoFollowLogs,
      debugKey: debugKey ?? this.debugKey,
      debugListSrcHtml: debugListSrcHtml == sourceEditSentinel
          ? this.debugListSrcHtml
          : debugListSrcHtml as String?,
      debugBookSrcHtml: debugBookSrcHtml == sourceEditSentinel
          ? this.debugBookSrcHtml
          : debugBookSrcHtml as String?,
      debugTocSrcHtml: debugTocSrcHtml == sourceEditSentinel
          ? this.debugTocSrcHtml
          : debugTocSrcHtml as String?,
      debugContentSrcHtml: debugContentSrcHtml == sourceEditSentinel
          ? this.debugContentSrcHtml
          : debugContentSrcHtml as String?,
      debugContentResult: debugContentResult == sourceEditSentinel
          ? this.debugContentResult
          : debugContentResult as String?,
      debugMethodDecision: debugMethodDecision == sourceEditSentinel
          ? this.debugMethodDecision
          : debugMethodDecision as String?,
      debugRetryDecision: debugRetryDecision == sourceEditSentinel
          ? this.debugRetryDecision
          : debugRetryDecision as String?,
      debugRequestCharsetDecision:
          debugRequestCharsetDecision == sourceEditSentinel
              ? this.debugRequestCharsetDecision
              : debugRequestCharsetDecision as String?,
      debugBodyDecision: debugBodyDecision == sourceEditSentinel
          ? this.debugBodyDecision
          : debugBodyDecision as String?,
      debugResponseCharset: debugResponseCharset == sourceEditSentinel
          ? this.debugResponseCharset
          : debugResponseCharset as String?,
      debugResponseCharsetDecision:
          debugResponseCharsetDecision == sourceEditSentinel
              ? this.debugResponseCharsetDecision
              : debugResponseCharsetDecision as String?,
      debugRuntimeVarsSnapshot:
          debugRuntimeVarsSnapshot ?? this.debugRuntimeVarsSnapshot,
      debugIntentType: debugIntentType == sourceEditSentinel
          ? this.debugIntentType
          : debugIntentType as SourceDebugIntentType?,
      previewChapterName: previewChapterName == sourceEditSentinel
          ? this.previewChapterName
          : previewChapterName as String?,
      previewChapterUrl: previewChapterUrl == sourceEditSentinel
          ? this.previewChapterUrl
          : previewChapterUrl as String?,
      debugAwaitingChapterNameValue:
          debugAwaitingChapterNameValue ?? this.debugAwaitingChapterNameValue,
      debugAwaitingChapterUrlValue:
          debugAwaitingChapterUrlValue ?? this.debugAwaitingChapterUrlValue,
      showDebugQuickHelp: showDebugQuickHelp ?? this.showDebugQuickHelp,
      cachedExploreQuickEntries:
          cachedExploreQuickEntries ?? this.cachedExploreQuickEntries,
      refreshingExploreQuickActions:
          refreshingExploreQuickActions ?? this.refreshingExploreQuickActions,
    );
  }
}

class SourceEditArgs {
  final String? originalUrl;
  final String? initialRawJson;
  final Object sessionId;

  const SourceEditArgs({
    this.originalUrl,
    this.initialRawJson,
    required this.sessionId,
  });

  @override
  bool operator ==(Object other) =>
      other is SourceEditArgs &&
      other.originalUrl == originalUrl &&
      other.initialRawJson == initialRawJson &&
      identical(other.sessionId, sessionId);

  @override
  int get hashCode =>
      Object.hash(originalUrl, initialRawJson, identityHashCode(sessionId));
}
