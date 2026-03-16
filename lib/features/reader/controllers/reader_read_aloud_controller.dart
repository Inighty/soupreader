import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/config/migration_exclusions.dart';
import '../../../core/services/settings_service.dart';
import '../services/http_tts_engine.dart';
import '../services/http_tts_rule_store.dart';
import '../services/read_aloud_service.dart';

/// Manages all TTS / read-aloud state that was previously inlined inside
/// `_SimpleReaderViewState`.
///
/// Responsibilities:
/// - Initialise and own the [ReadAloudService] lifecycle.
/// - Manage one-shot "speak selected text" via [FlutterTts].
/// - Expose an observable [ReadAloudStatusSnapshot] so the UI can rebuild.
/// - Encapsulate migration-exclusion guards for TTS entry points.
///
/// The controller deliberately does **not** hold references to Widgets,
/// BuildContext, or navigation. UI-only concerns (toasts, dialogs) are
/// communicated through callbacks supplied by the View.
class ReaderReadAloudController extends ChangeNotifier {
  ReaderReadAloudController({
    required SettingsService settingsService,
    required ReadAloudChapterSwitchCallback onRequestChapterSwitch,
    required void Function(String message) onMessage,
  })  : _settingsService = settingsService,
        _onRequestChapterSwitch = onRequestChapterSwitch,
        _onMessage = onMessage;

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final SettingsService _settingsService;
  final ReadAloudChapterSwitchCallback _onRequestChapterSwitch;
  final void Function(String message) _onMessage;

  final HttpTtsRuleStore _httpTtsRuleStore = HttpTtsRuleStore();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  ReadAloudService? _serviceOrNull;
  ReadAloudStatusSnapshot _snapshot =
      const ReadAloudStatusSnapshot.stopped();
  int _speechRate = 10;
  int _contentSelectSpeakMode = 0;
  bool _audioPlayUseWakeLock = false;
  bool _showingExclusionDialog = false;

  // One-shot FlutterTts for "speak selected text only" mode.
  FlutterTts? _oneShotTts;
  bool _oneShotTtsReady = false;

  /// Pattern used to decide whether a line contains speakable content.
  static final RegExp _speakablePattern =
      RegExp(r'[\u4E00-\u9FFFA-Za-z0-9]');

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// Current read-aloud status (stopped / playing / paused, timer, etc.).
  ReadAloudStatusSnapshot get snapshot => _snapshot;

  /// Current speech rate (0-20 scale forwarded to the engine).
  int get speechRate => _speechRate;

  /// 0 = speak selection only, 1 = start continuous read-aloud from selection.
  int get contentSelectSpeakMode => _contentSelectSpeakMode;

  /// Whether the audio-play wake-lock toggle is on.
  bool get audioPlayUseWakeLock => _audioPlayUseWakeLock;

  /// Whether the migration-exclusion dialog is currently shown.
  bool get showingExclusionDialog => _showingExclusionDialog;

  /// Convenience: is TTS excluded by migration config?
  bool get isTtsExcluded => MigrationExclusions.excludeTts;

  // ---------------------------------------------------------------------------
  // Initialisation / disposal
  // ---------------------------------------------------------------------------

  /// Call once after construction to restore persisted prefs and create the
  /// engine.
  Future<void> init() async {
    _audioPlayUseWakeLock = _settingsService.getAudioPlayUseWakeLock();
    _contentSelectSpeakMode =
        _settingsService.getContentSelectSpeakMode();

    final selectedRuleId = await _httpTtsRuleStore.loadSelectedRuleId();
    final speechRate = await _httpTtsRuleStore.loadSpeechRate();

    ReadAloudEngine engine;
    if (selectedRuleId != null) {
      final rules = await _httpTtsRuleStore.loadRules();
      final rule = rules.where((r) => r.id == selectedRuleId).firstOrNull;
      engine = rule != null
          ? HttpTtsReadAloudEngine(rule: rule, speechRate: speechRate)
          : FlutterReadAloudEngine();
    } else {
      engine = FlutterReadAloudEngine();
    }

    _serviceOrNull = ReadAloudService(
      engine: engine,
      onStateChanged: _handleStateChanged,
      onMessage: _onMessage,
      onRequestChapterSwitch: _onRequestChapterSwitch,
    );
    _speechRate = speechRate;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_serviceOrNull?.dispose());
    unawaited(_disposeOneShotTts());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Service proxy (safe access)
  // ---------------------------------------------------------------------------

  ReadAloudService get _service {
    final s = _serviceOrNull;
    if (s == null) {
      throw StateError(
        'ReaderReadAloudController.init() has not been called yet.',
      );
    }
    return s;
  }

  // ---------------------------------------------------------------------------
  // Core actions
  // ---------------------------------------------------------------------------

  /// Start / pause / resume read-aloud for the current chapter.
  ///
  /// Returns an [ReadAloudActionResult]; the caller should display the
  /// result message as a toast.
  Future<ReadAloudActionResult> toggleReadAloud({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
  }) async {
    if (!_snapshot.isRunning) {
      return _service.start(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        content: content,
      );
    }
    if (_snapshot.isPaused) {
      return _service.resume();
    }
    return _service.pause();
  }

  /// Stop read-aloud entirely.
  Future<void> stop() async {
    await _service.stop();
  }

  /// Move to the previous paragraph.
  Future<ReadAloudActionResult> previousParagraph() =>
      _service.previousParagraph();

  /// Move to the next paragraph.
  Future<ReadAloudActionResult> nextParagraph() =>
      _service.nextParagraph();

  /// Toggle pause/resume.
  Future<ReadAloudActionResult> togglePauseResume() =>
      _service.togglePauseResume();

  /// Update the chapter context after the reader loads a new chapter.
  void syncChapterContext({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
  }) {
    if (MigrationExclusions.excludeTts) return;
    unawaited(
      _service.updateChapter(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        content: content,
      ),
    );
  }

  /// Set the sleep timer (minutes). Pass 0 to cancel.
  void setTimer(int minutes) {
    _service.setTimer(minutes);
    notifyListeners();
  }

  /// Update speech rate and persist.
  Future<void> updateSpeechRate(int rate) async {
    _speechRate = rate;
    notifyListeners();
    unawaited(_service.updateSpeechRate(rate));
    unawaited(_httpTtsRuleStore.saveSpeechRate(rate));
  }

  // ---------------------------------------------------------------------------
  // Selected-text read-aloud
  // ---------------------------------------------------------------------------

  /// Handle a "read aloud" action triggered from the text-selection menu.
  ///
  /// Returns `true` if the action was consumed, `false` if no-op.
  Future<bool> handleSelectedTextReadAloud({
    required String selectedText,
    required String currentContent,
    required int chapterIndex,
    required String chapterTitle,
    required double chapterProgress,
  }) async {
    final text = _normalizeSelectedText(selectedText);
    if (text.isEmpty) return false;

    if (_contentSelectSpeakMode == 1) {
      return _startFromSelectedText(
        selectedText: text,
        currentContent: currentContent,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        chapterProgress: chapterProgress,
      );
    }
    return _speakOnce(text);
  }

  /// Toggle between "speak selection" and "continuous from selection" modes.
  void toggleContentSelectSpeakMode() {
    _contentSelectSpeakMode = _contentSelectSpeakMode == 1 ? 0 : 1;
    notifyListeners();
    unawaited(
      _settingsService.saveContentSelectSpeakMode(_contentSelectSpeakMode),
    );
  }

  /// Toggle the audio-play wake-lock setting.
  Future<void> toggleAudioPlayWakeLock() async {
    _audioPlayUseWakeLock = !_audioPlayUseWakeLock;
    notifyListeners();
    await _settingsService.saveAudioPlayUseWakeLock(_audioPlayUseWakeLock);
  }

  // ---------------------------------------------------------------------------
  // Capability check
  // ---------------------------------------------------------------------------

  /// Evaluate whether read-aloud can be started right now.
  ReadAloudCapability detectCapability({
    required List<dynamic> chapters,
    required String currentContent,
  }) {
    if (kIsWeb) {
      return const ReadAloudCapability(
        available: false,
        reason: '当前平台暂不支持语音朗读',
      );
    }
    if (chapters.isEmpty) {
      return const ReadAloudCapability(
        available: false,
        reason: '当前书籍暂无可朗读章节',
      );
    }
    if (currentContent.trim().isEmpty) {
      return const ReadAloudCapability(
        available: false,
        reason: '当前章节暂无可朗读内容',
      );
    }
    return const ReadAloudCapability(available: true, reason: '');
  }

  // ---------------------------------------------------------------------------
  // Exclusion dialog guard
  // ---------------------------------------------------------------------------

  /// Mark the exclusion dialog as shown/hidden so we don't stack them.
  void setShowingExclusionDialog(bool value) {
    _showingExclusionDialog = value;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _handleStateChanged(ReadAloudStatusSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<bool> _startFromSelectedText({
    required String selectedText,
    required String currentContent,
    required int chapterIndex,
    required String chapterTitle,
    required double chapterProgress,
  }) async {
    final selectionStart = _resolveSelectionStartIndex(
      selectedText: selectedText,
      content: currentContent,
      chapterProgress: chapterProgress,
    );

    ReadAloudActionResult result;
    if (selectionStart >= 0) {
      result = await _service.start(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        content: currentContent.substring(selectionStart),
        startParagraphIndex: 0,
      );
    } else {
      final startParagraph = _resolveStartParagraphIndex(
        selectedText: selectedText,
        content: currentContent,
      );
      result = await _service.start(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        content: currentContent,
        startParagraphIndex: startParagraph,
      );
    }
    if (!result.success) {
      _onMessage(result.message);
    }
    return result.success;
  }

  Future<bool> _speakOnce(String text) async {
    if (kIsWeb) {
      _onMessage('当前平台暂不支持语音朗读');
      return false;
    }
    try {
      final tts = await _ensureOneShotTtsReady();
      await tts.stop();
      final result = await tts.speak(text);
      if (result != 1) {
        _onMessage('启动朗读失败');
        return false;
      }
      return true;
    } catch (error) {
      _onMessage('启动朗读失败：$error');
      return false;
    }
  }

  Future<FlutterTts> _ensureOneShotTtsReady() async {
    final existing = _oneShotTts;
    if (existing != null && _oneShotTtsReady) return existing;
    final tts = existing ?? FlutterTts();
    _oneShotTts ??= tts;
    if (!_oneShotTtsReady) {
      await tts.awaitSpeakCompletion(true);
      _oneShotTtsReady = true;
    }
    return tts;
  }

  Future<void> _disposeOneShotTts() async {
    final tts = _oneShotTts;
    _oneShotTts = null;
    _oneShotTtsReady = false;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (_) {
      // ignore dispose errors
    }
  }

  int _resolveSelectionStartIndex({
    required String selectedText,
    required String content,
    required double chapterProgress,
  }) {
    if (selectedText.isEmpty || content.isEmpty) return -1;
    final matches = <int>[];
    var cursor = 0;
    while (cursor < content.length) {
      final idx = content.indexOf(selectedText, cursor);
      if (idx < 0) break;
      matches.add(idx);
      cursor = idx + 1;
    }
    if (matches.isEmpty) return -1;
    final estimated =
        (content.length * chapterProgress.clamp(0.0, 1.0))
            .round()
            .clamp(0, content.length);
    matches.sort(
      (a, b) =>
          (a - estimated).abs().compareTo((b - estimated).abs()),
    );
    return matches.first;
  }

  int _resolveStartParagraphIndex({
    required String selectedText,
    required String content,
  }) {
    final paragraphs = buildSpeakableParagraphs(content);
    if (paragraphs.isEmpty) return 0;
    final normalized = selectedText.trim();
    if (normalized.isEmpty) return 0;
    final exact =
        paragraphs.indexWhere((p) => p.contains(normalized));
    if (exact >= 0) return exact;
    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return 0;
    final compactIdx = paragraphs.indexWhere(
      (p) => p.replaceAll(RegExp(r'\s+'), '').contains(compact),
    );
    return compactIdx >= 0 ? compactIdx : 0;
  }

  static String _normalizeSelectedText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Split chapter content into speakable paragraphs (non-empty lines that
  /// contain at least one CJK / alphanumeric character).
  static List<String> buildSpeakableParagraphs(String content) {
    final normalized =
        content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalized
        .split('\n')
        .map((line) => line.trim())
        .where(
          (line) => line.isNotEmpty && _speakablePattern.hasMatch(line),
        )
        .toList(growable: false);
  }
}

/// Result of [ReaderReadAloudController.detectCapability].
class ReadAloudCapability {
  final bool available;
  final String reason;

  const ReadAloudCapability({
    required this.available,
    required this.reason,
  });
}
