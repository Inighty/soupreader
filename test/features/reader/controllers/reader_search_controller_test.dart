import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/controllers/reader_search_controller.dart';

void main() {
  group('ReaderSearchController', () {
    late ReaderSearchController controller;
    late List<String> chapters;

    setUp(() {
      chapters = [
        '这是第一章的内容，包含关键词测试。',
        '第二章没有匹配的内容。',
        '第三章也有关键词测试出现。',
      ];

      controller = ReaderSearchController(
        contentLoader: (index, {required taskToken}) async {
          if (index < 0 || index >= chapters.length) return null;
          return chapters[index];
        },
        readableChapterCount: () => chapters.length,
        chapterTitleAt: (index) => '第${index + 1}章',
      );
    });

    test('initial state is empty', () {
      expect(controller.query, '');
      expect(controller.hits, isEmpty);
      expect(controller.currentHitIndex, -1);
      expect(controller.isSearching, false);
      expect(controller.hasHits, false);
      expect(controller.activeHighlightQuery, isNull);
    });

    test('search finds hits across chapters', () async {
      await controller.search('测试');
      expect(controller.isSearching, false);
      expect(controller.hits.length, 2);
      expect(controller.hits[0].chapterIndex, 0);
      expect(controller.hits[1].chapterIndex, 2);
      expect(controller.currentHitIndex, 0);
      expect(controller.hasHits, true);
      expect(controller.activeHighlightQuery, '测试');
    });

    test('search with no results', () async {
      await controller.search('不存在的词');
      expect(controller.hits, isEmpty);
      expect(controller.currentHitIndex, -1);
      expect(controller.hasHits, false);
    });

    test('navigate moves between hits', () async {
      await controller.search('测试');
      expect(controller.currentHitIndex, 0);

      controller.navigate(1);
      expect(controller.currentHitIndex, 1);

      controller.navigate(1);
      expect(controller.currentHitIndex, 1); // clamped

      controller.navigate(-1);
      expect(controller.currentHitIndex, 0);

      controller.navigate(-1);
      expect(controller.currentHitIndex, 0); // clamped
    });

    test('clear resets all state', () async {
      await controller.search('测试');
      expect(controller.hasHits, true);

      controller.clear();
      expect(controller.query, '');
      expect(controller.hits, isEmpty);
      expect(controller.currentHitIndex, -1);
      expect(controller.isSearching, false);
    });

    test('captureProgressSnapshot stores position', () {
      expect(controller.progressSnapshot, isNull);
      controller.captureProgressSnapshot(
        chapterIndex: 3,
        chapterProgress: 0.42,
      );
      expect(controller.progressSnapshot, isNotNull);
      expect(controller.progressSnapshot!.chapterIndex, 3);
      expect(controller.progressSnapshot!.chapterProgress, 0.42);
    });

    test('captureProgressSnapshot does not overwrite existing', () {
      controller.captureProgressSnapshot(
        chapterIndex: 1,
        chapterProgress: 0.1,
      );
      controller.captureProgressSnapshot(
        chapterIndex: 5,
        chapterProgress: 0.9,
      );
      expect(controller.progressSnapshot!.chapterIndex, 1);
    });

    test('toggleUseReplace toggles the flag', () {
      expect(controller.useReplace, false);
      controller.toggleUseReplace();
      expect(controller.useReplace, true);
      controller.toggleUseReplace();
      expect(controller.useReplace, false);
    });

    test('context before/after is populated in hits', () async {
      await controller.search('关键词');
      expect(controller.hits.isNotEmpty, true);
      final hit = controller.hits.first;
      expect(hit.contextBefore, isNotEmpty);
      expect(hit.matchText, '关键词');
    });

    test('empty query is a no-op', () async {
      await controller.search('');
      expect(controller.hits, isEmpty);
      expect(controller.isSearching, false);
    });

    test('notifies listeners during search', () async {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      await controller.search('测试');
      // At minimum: start (isSearching=true) + end (isSearching=false)
      expect(notifyCount, greaterThanOrEqualTo(2));
    });
  });
}
