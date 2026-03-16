import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/reader/controllers/reader_read_aloud_controller.dart';

void main() {
  group('ReaderReadAloudController', () {
    group('detectCapability', () {
      late ReaderReadAloudController controller;

      setUp(() {
        controller = ReaderReadAloudController(
          settingsService: SettingsService(),
          onRequestChapterSwitch: (_) async => false,
          onMessage: (_) {},
        );
      });

      tearDown(() => controller.dispose());

      test('unavailable when chapters empty', () {
        final result = controller.detectCapability(
          chapters: [],
          currentContent: 'some content',
        );
        expect(result.available, false);
        expect(result.reason, contains('暂无可朗读章节'));
      });

      test('unavailable when content empty', () {
        final result = controller.detectCapability(
          chapters: ['ch1'],
          currentContent: '   ',
        );
        expect(result.available, false);
        expect(result.reason, contains('暂无可朗读内容'));
      });

      test('available when chapters and content exist', () {
        final result = controller.detectCapability(
          chapters: ['ch1'],
          currentContent: '这是正文内容',
        );
        expect(result.available, true);
        expect(result.reason, isEmpty);
      });
    });

    group('buildSpeakableParagraphs', () {
      test('splits by newlines and filters empty', () {
        final paragraphs =
            ReaderReadAloudController.buildSpeakableParagraphs(
          '第一段\n\n第二段\n\n\n第三段',
        );
        expect(paragraphs, ['第一段', '第二段', '第三段']);
      });

      test('filters lines without speakable chars', () {
        final paragraphs =
            ReaderReadAloudController.buildSpeakableParagraphs(
          '正常段落\n---\n。。。\nAnother line',
        );
        expect(paragraphs, ['正常段落', 'Another line']);
      });

      test('handles CR/LF', () {
        final paragraphs =
            ReaderReadAloudController.buildSpeakableParagraphs(
          '行一\r\n行二\r行三',
        );
        expect(paragraphs, ['行一', '行二', '行三']);
      });

      test('returns empty for empty content', () {
        expect(
          ReaderReadAloudController.buildSpeakableParagraphs(''),
          isEmpty,
        );
      });

      test('trims whitespace from lines', () {
        final paragraphs =
            ReaderReadAloudController.buildSpeakableParagraphs(
          '  有空格的段落  \n  另一段  ',
        );
        expect(paragraphs, ['有空格的段落', '另一段']);
      });
    });

    group('toggleContentSelectSpeakMode', () {
      late ReaderReadAloudController controller;

      setUp(() {
        controller = ReaderReadAloudController(
          settingsService: SettingsService(),
          onRequestChapterSwitch: (_) async => false,
          onMessage: (_) {},
        );
      });

      tearDown(() => controller.dispose());

      test('toggles between 0 and 1', () {
        expect(controller.contentSelectSpeakMode, 0);
        controller.toggleContentSelectSpeakMode();
        expect(controller.contentSelectSpeakMode, 1);
        controller.toggleContentSelectSpeakMode();
        expect(controller.contentSelectSpeakMode, 0);
      });

      test('notifies listeners on toggle', () {
        int count = 0;
        controller.addListener(() => count++);
        controller.toggleContentSelectSpeakMode();
        expect(count, 1);
      });
    });
  });
}

