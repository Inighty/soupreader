import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/services/reader_key_paging_helper.dart';

void main() {
  test(
      'volume key paging is blocked while read-aloud playing when switch is off',
      () {
    final blockedDown =
        ReaderKeyPagingHelper.shouldBlockVolumePagingDuringReadAloud(
      key: LogicalKeyboardKey.audioVolumeDown,
      readAloudPlaying: true,
      volumeKeyPageOnPlayEnabled: false,
    );
    final blockedUp =
        ReaderKeyPagingHelper.shouldBlockVolumePagingDuringReadAloud(
      key: LogicalKeyboardKey.audioVolumeUp,
      readAloudPlaying: true,
      volumeKeyPageOnPlayEnabled: false,
    );

    expect(blockedDown, isTrue);
    expect(blockedUp, isTrue);
  });

  test(
      'volume key paging is not blocked when read-aloud not playing or switch on',
      () {
    final notPlaying =
        ReaderKeyPagingHelper.shouldBlockVolumePagingDuringReadAloud(
      key: LogicalKeyboardKey.audioVolumeDown,
      readAloudPlaying: false,
      volumeKeyPageOnPlayEnabled: false,
    );
    final switchOn =
        ReaderKeyPagingHelper.shouldBlockVolumePagingDuringReadAloud(
      key: LogicalKeyboardKey.audioVolumeDown,
      readAloudPlaying: true,
      volumeKeyPageOnPlayEnabled: true,
    );
    final nonVolume =
        ReaderKeyPagingHelper.shouldBlockVolumePagingDuringReadAloud(
      key: LogicalKeyboardKey.arrowRight,
      readAloudPlaying: true,
      volumeKeyPageOnPlayEnabled: false,
    );

    expect(notPlaying, isFalse);
    expect(switchOn, isFalse);
    expect(nonVolume, isFalse);
  });

  test('volume keys follow volumeKeyPage switch', () {
    final nextWhenEnabled = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: LogicalKeyboardKey.audioVolumeDown,
      volumeKeyPageEnabled: true,
    );
    final prevWhenEnabled = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: LogicalKeyboardKey.audioVolumeUp,
      volumeKeyPageEnabled: true,
    );
    final nextWhenDisabled = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: LogicalKeyboardKey.audioVolumeDown,
      volumeKeyPageEnabled: false,
    );
    final prevWhenDisabled = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: LogicalKeyboardKey.audioVolumeUp,
      volumeKeyPageEnabled: false,
    );

    expect(nextWhenEnabled, ReaderKeyPagingAction.next);
    expect(prevWhenEnabled, ReaderKeyPagingAction.prev);
    expect(nextWhenDisabled, ReaderKeyPagingAction.none);
    expect(prevWhenDisabled, ReaderKeyPagingAction.none);
  });

  test('arrow/page/space keys are independent from volumeKeyPage', () {
    final keys = <LogicalKeyboardKey>[
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.space,
    ];
    for (final key in keys) {
      expect(
        ReaderKeyPagingHelper.resolveKeyDownAction(
          key: key,
          volumeKeyPageEnabled: true,
        ),
        ReaderKeyPagingAction.next,
      );
      expect(
        ReaderKeyPagingHelper.resolveKeyDownAction(
          key: key,
          volumeKeyPageEnabled: false,
        ),
        ReaderKeyPagingAction.next,
      );
    }

    final prevKeys = <LogicalKeyboardKey>[
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.pageUp,
    ];
    for (final key in prevKeys) {
      expect(
        ReaderKeyPagingHelper.resolveKeyDownAction(
          key: key,
          volumeKeyPageEnabled: true,
        ),
        ReaderKeyPagingAction.prev,
      );
      expect(
        ReaderKeyPagingHelper.resolveKeyDownAction(
          key: key,
          volumeKeyPageEnabled: false,
        ),
        ReaderKeyPagingAction.prev,
      );
    }
  });

  test('unsupported key maps to none', () {
    final action = ReaderKeyPagingHelper.resolveKeyDownAction(
      key: LogicalKeyboardKey.enter,
      volumeKeyPageEnabled: true,
    );
    expect(action, ReaderKeyPagingAction.none);
  });
}
