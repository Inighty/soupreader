import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/read_aloud_service.dart';

void main() {
  group('ReadAloudService', () {
    test('可开始、暂停、继续朗读', () async {
      final engine = _FakeReadAloudEngine();
      final service = ReadAloudService(engine: engine);

      final start = await service.start(
        chapterIndex: 0,
        chapterTitle: '第一章',
        content: '第一段\n第二段',
      );
      expect(start.success, isTrue);
      expect(start.message, '开始朗读');
      expect(service.isPlaying, isTrue);
      expect(engine.spokenTexts, <String>['第一段']);

      final pause = await service.pause();
      expect(pause.success, isTrue);
      expect(service.isPaused, isTrue);
      expect(engine.stopCount, 1);

      final resume = await service.resume();
      expect(resume.success, isTrue);
      expect(service.isPlaying, isTrue);
      expect(engine.spokenTexts, <String>['第一段', '第一段']);

      await service.dispose();
    });

    test('过滤空白与标点行，仅保留可朗读段落', () async {
      final engine = _FakeReadAloudEngine();
      final service = ReadAloudService(engine: engine);

      final result = await service.start(
        chapterIndex: 0,
        chapterTitle: '第一章',
        content: '\n……\n！！！\n可朗读内容\n',
      );

      expect(result.success, isTrue);
      expect(engine.spokenTexts, <String>['可朗读内容']);
      await service.dispose();
    });

    test('段落播报完成后自动进入下一段，并在末尾切换章节', () async {
      final engine = _FakeReadAloudEngine();
      final requested = <ReadAloudChapterDirection>[];
      late ReadAloudService service;
      service = ReadAloudService(
        engine: engine,
        onRequestChapterSwitch: (direction) async {
          requested.add(direction);
          await service.updateChapter(
            chapterIndex: 1,
            chapterTitle: '第二章',
            content: '第二章第一段',
          );
          return true;
        },
      );

      await service.start(
        chapterIndex: 0,
        chapterTitle: '第一章',
        content: '第一段\n第二段',
      );
      expect(engine.spokenTexts, <String>['第一段']);

      engine.completeCurrent();
      await _flushMicrotasks();
      expect(engine.spokenTexts, <String>['第一段', '第二段']);

      engine.completeCurrent();
      await _flushMicrotasks();
      expect(requested,
          <ReadAloudChapterDirection>[ReadAloudChapterDirection.next]);
      expect(engine.spokenTexts.last, '第二章第一段');

      await service.dispose();
    });

    test('章节无可朗读内容时会返回失败', () async {
      final engine = _FakeReadAloudEngine();
      final service = ReadAloudService(engine: engine);

      final result = await service.start(
        chapterIndex: 0,
        chapterTitle: '空章节',
        content: ' \n\t\n',
      );

      expect(result.success, isFalse);
      expect(result.message, '当前章节暂无可朗读内容');
      expect(service.isRunning, isFalse);
      expect(engine.spokenTexts, isEmpty);
      await service.dispose();
    });

    test('朗读到末尾且无下一章时停止并提示', () async {
      final engine = _FakeReadAloudEngine();
      final messages = <String>[];
      final service = ReadAloudService(
        engine: engine,
        onMessage: messages.add,
        onRequestChapterSwitch: (_) async => false,
      );

      await service.start(
        chapterIndex: 0,
        chapterTitle: '第一章',
        content: '仅一段',
      );

      engine.completeCurrent();
      await _flushMicrotasks();

      expect(service.isRunning, isFalse);
      expect(messages, contains('朗读已停止'));
      await service.dispose();
    });

    test('上一段越界时可切换到上一章并继续朗读', () async {
      final engine = _FakeReadAloudEngine();
      final requested = <ReadAloudChapterDirection>[];
      late ReadAloudService service;
      service = ReadAloudService(
        engine: engine,
        onRequestChapterSwitch: (direction) async {
          requested.add(direction);
          await service.updateChapter(
            chapterIndex: 0,
            chapterTitle: '上一章',
            content: '上一章第一段',
          );
          return true;
        },
      );

      await service.start(
        chapterIndex: 1,
        chapterTitle: '当前章',
        content: '当前章第一段',
      );

      final result = await service.previousParagraph();
      expect(result.success, isTrue);
      expect(result.message, '朗读上一章');
      expect(requested,
          <ReadAloudChapterDirection>[ReadAloudChapterDirection.previous]);
      expect(engine.spokenTexts.last, '上一章第一段');
      await service.dispose();
    });

    test('朗读引擎报错时会停止并给出可观测提示', () async {
      final engine = _FakeReadAloudEngine();
      final messages = <String>[];
      final service = ReadAloudService(
        engine: engine,
        onMessage: messages.add,
      );

      await service.start(
        chapterIndex: 0,
        chapterTitle: '第一章',
        content: '第一段',
      );

      engine.emitError('network error');
      await _flushMicrotasks();

      expect(service.isRunning, isFalse);
      expect(messages, contains('朗读出错：network error'));
      await service.dispose();
    });
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeReadAloudEngine implements ReadAloudEngine {
  VoidCallback? _onCompleted;
  ValueChanged<String>? _onError;
  final List<String> spokenTexts = <String>[];
  int stopCount = 0;
  bool shouldFailSpeak = false;

  @override
  Future<void> initialize({
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    _onCompleted = onCompleted;
    _onError = onError;
  }

  @override
  Future<bool> speak(String text) async {
    if (shouldFailSpeak) return false;
    spokenTexts.add(text);
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> dispose() async {}

  void completeCurrent() {
    _onCompleted?.call();
  }

  void emitError(String message) {
    _onError?.call(message);
  }
}
