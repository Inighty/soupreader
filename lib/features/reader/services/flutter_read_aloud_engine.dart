import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'read_aloud_models.dart';

/// 基于 `flutter_tts` 的默认 [ReadAloudEngine] 实现。
class FlutterReadAloudEngine implements ReadAloudEngine {
  FlutterReadAloudEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;

  @override
  Future<void> initialize({
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    _tts.setCompletionHandler(onCompleted);
    _tts.setErrorHandler((message) {
      onError((message ?? '').trim().isEmpty ? 'TTS 引擎异常' : message!);
    });

    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
  }

  @override
  Future<bool> speak(String text) async {
    final result = await _tts.speak(text);
    return result == 1;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
    _initialized = false;
  }

  @override
  Future<void> updateSpeechRate(int rate) async {
    await _tts.setSpeechRate(rate.clamp(1, 20) / 10.0);
  }
}
