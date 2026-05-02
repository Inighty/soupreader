import 'package:flutter/foundation.dart';

/// 朗读运行状态。
enum ReadAloudState {
  stopped,
  playing,
  paused,
}

/// 切章方向。
enum ReadAloudChapterDirection {
  previous,
  next,
}

/// 朗读运行状态快照。
class ReadAloudStatusSnapshot {
  final ReadAloudState state;
  final int chapterIndex;
  final String chapterTitle;
  final int paragraphIndex;
  final int paragraphCount;
  final int sleepTimerMinutes;
  final int sleepTimerRemainSeconds;

  const ReadAloudStatusSnapshot({
    required this.state,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.paragraphIndex,
    required this.paragraphCount,
    this.sleepTimerMinutes = 0,
    this.sleepTimerRemainSeconds = 0,
  });

  const ReadAloudStatusSnapshot.stopped()
      : state = ReadAloudState.stopped,
        chapterIndex = -1,
        chapterTitle = '',
        paragraphIndex = -1,
        paragraphCount = 0,
        sleepTimerMinutes = 0,
        sleepTimerRemainSeconds = 0;

  bool get isRunning => state != ReadAloudState.stopped;
  bool get isPlaying => state == ReadAloudState.playing;
  bool get isPaused => state == ReadAloudState.paused;
  bool get hasSleepTimer => sleepTimerMinutes > 0;
}

/// 朗读单次操作结果。
class ReadAloudActionResult {
  final bool success;
  final String message;

  const ReadAloudActionResult({
    required this.success,
    required this.message,
  });
}

typedef ReadAloudStateChanged = void Function(ReadAloudStatusSnapshot state);
typedef ReadAloudMessageCallback = void Function(String message);
typedef ReadAloudChapterSwitchCallback = Future<bool> Function(
  ReadAloudChapterDirection direction,
);

/// 朗读引擎抽象 — 解耦 TTS 实现，方便注入测试替身。
abstract class ReadAloudEngine {
  Future<void> initialize({
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  });

  Future<bool> speak(String text);

  Future<void> stop();

  Future<void> dispose();

  Future<void> updateSpeechRate(int rate) async {}
}
