import 'package:flutter/services.dart';

enum ReaderKeyPagingAction {
  none,
  prev,
  next,
}

class ReaderKeyPagingHelper {
  static bool shouldBlockVolumePagingDuringReadAloud({
    required LogicalKeyboardKey key,
    required bool readAloudPlaying,
    required bool volumeKeyPageOnPlayEnabled,
  }) {
    final isVolumeKey = _isVolumeNextKey(key) || _isVolumePrevKey(key);
    return isVolumeKey && readAloudPlaying && !volumeKeyPageOnPlayEnabled;
  }

  static ReaderKeyPagingAction resolveKeyDownAction({
    required LogicalKeyboardKey key,
    required bool volumeKeyPageEnabled,
  }) {
    if (_isNextKey(key)) return ReaderKeyPagingAction.next;
    if (_isPrevKey(key)) return ReaderKeyPagingAction.prev;
    if (_isVolumeNextKey(key)) {
      return volumeKeyPageEnabled
          ? ReaderKeyPagingAction.next
          : ReaderKeyPagingAction.none;
    }
    if (_isVolumePrevKey(key)) {
      return volumeKeyPageEnabled
          ? ReaderKeyPagingAction.prev
          : ReaderKeyPagingAction.none;
    }
    return ReaderKeyPagingAction.none;
  }

  static bool _isNextKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space;
  }

  static bool _isPrevKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp;
  }

  static bool _isVolumeNextKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.audioVolumeDown;
  }

  static bool _isVolumePrevKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.audioVolumeUp;
  }
}
