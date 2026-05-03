import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/services/exception_log_service.dart';

/// 封装 RSS 阅读页朗读相关状态：tts 实例懒加载 + 播放/停止/释放。
class RssReadAloudController extends ChangeNotifier {
  FlutterTts? _tts;
  bool _ready = false;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<FlutterTts> _ensureReady() async {
    final existing = _tts;
    if (existing != null && _ready) return existing;
    final tts = existing ?? FlutterTts();
    _tts ??= tts;
    if (!_ready) {
      tts.setStartHandler(() {
        _playing = true;
        notifyListeners();
      });
      tts.setCompletionHandler(() {
        _playing = false;
        notifyListeners();
      });
      tts.setCancelHandler(() {
        _playing = false;
        notifyListeners();
      });
      tts.setErrorHandler((_) {
        _playing = false;
        notifyListeners();
      });
      await tts.awaitSpeakCompletion(true);
      _ready = true;
    }
    return tts;
  }

  /// 停止朗读但保留 tts 实例，供再次启动复用。
  Future<void> stop({String? originKey, String? linkKey}) async {
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_aloud',
        message: '停止 RSS 朗读失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': originKey ?? '',
          'link': linkKey ?? '',
        },
      );
    }
    _playing = false;
    notifyListeners();
  }

  /// 切换播放/停止。
  Future<void> toggle({
    required String text,
    String? originKey,
    String? linkKey,
  }) async {
    if (_playing) {
      await stop(originKey: originKey, linkKey: linkKey);
      return;
    }
    if (text.isEmpty) return;
    try {
      final tts = await _ensureReady();
      await tts.stop();
      final result = await tts.speak(text);
      final success = result == null || result == 1 || result == true;
      if (!success) {
        ExceptionLogService().record(
          node: 'rss_read.menu_aloud',
          message: '启动 RSS 朗读失败',
          context: <String, dynamic>{
            'origin': originKey ?? '',
            'link': linkKey ?? '',
            'ttsResult': result.toString(),
          },
        );
        return;
      }
      _playing = true;
      notifyListeners();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_aloud',
        message: '启动 RSS 朗读失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': originKey ?? '',
          'link': linkKey ?? '',
        },
      );
    }
  }

  /// 页面销毁阶段静默清理。
  Future<void> disposeAsync() async {
    final tts = _tts;
    _tts = null;
    _ready = false;
    _playing = false;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (_) {
      // 与 legado 同义静默清理。
    }
  }
}
