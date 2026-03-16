import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/controllers/reader_bookmark_controller.dart';

void main() {
  group('ReaderBookmarkController', () {
    group('encodeChapterPos / decodeChapterProgress', () {
      late ReaderBookmarkController controller;

      setUp(() {
        controller = ReaderBookmarkController(
          bookId: 'test-book',
          bookTitle: 'Test Book',
        );
      });

      tearDown(() => controller.dispose());

      test('encodes 0.0 progress as 0', () {
        expect(controller.encodeChapterPos(0.0), 0);
      });

      test('encodes 1.0 progress as 10000', () {
        expect(controller.encodeChapterPos(1.0), 10000);
      });

      test('encodes 0.5 progress as 5000', () {
        expect(controller.encodeChapterPos(0.5), 5000);
      });

      test('clamps progress above 1.0', () {
        expect(controller.encodeChapterPos(1.5), 10000);
      });

      test('clamps progress below 0.0', () {
        expect(controller.encodeChapterPos(-0.5), 0);
      });

      test('decodes 0 as 0.0', () {
        expect(controller.decodeChapterProgress(0), 0.0);
      });

      test('decodes 10000 as 1.0', () {
        expect(controller.decodeChapterProgress(10000), 1.0);
      });

      test('decodes 5000 as 0.5', () {
        expect(controller.decodeChapterProgress(5000), 0.5);
      });

      test('round-trips correctly', () {
        for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final encoded = controller.encodeChapterPos(progress);
          final decoded = controller.decodeChapterProgress(encoded);
          expect(decoded, closeTo(progress, 0.001));
        }
      });
    });

    group('composePreview', () {
      test('returns note when bookText is empty', () {
        expect(
          ReaderBookmarkController.composePreview(
            bookText: '',
            note: '这是笔记',
          ),
          '这是笔记',
        );
      });

      test('returns bookText when note is empty', () {
        expect(
          ReaderBookmarkController.composePreview(
            bookText: '书签文本',
            note: '',
          ),
          '书签文本',
        );
      });

      test('combines both with separator', () {
        expect(
          ReaderBookmarkController.composePreview(
            bookText: '书签文本',
            note: '笔记内容',
          ),
          '书签文本\n\n笔记：笔记内容',
        );
      });

      test('trims whitespace', () {
        expect(
          ReaderBookmarkController.composePreview(
            bookText: '  书签文本  ',
            note: '  笔记  ',
          ),
          '书签文本\n\n笔记：笔记',
        );
      });

      test('returns empty when both empty', () {
        expect(
          ReaderBookmarkController.composePreview(
            bookText: '',
            note: '',
          ),
          '',
        );
      });
    });
  });
}
