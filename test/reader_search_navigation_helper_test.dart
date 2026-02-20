import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_search_navigation_helper.dart';

void main() {
  group('ReaderSearchNavigationHelper.resolvePageIndexByOccurrence', () {
    test('按命中序号定位到正确页', () {
      const pages = <String>[
        'alpha foo beta',
        'gamma foo delta',
        'epsilon foo zeta',
      ];

      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: 'foo',
          occurrenceIndex: 0,
        ),
        0,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: 'foo',
          occurrenceIndex: 1,
        ),
        1,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: 'foo',
          occurrenceIndex: 2,
        ),
        2,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: 'foo',
          occurrenceIndex: 3,
        ),
        isNull,
      );
    });

    test('首屏可剥离标题前缀，避免标题命中干扰正文定位', () {
      const chapterTitle = '第一章 序幕';
      const pages = <String>[
        '第一章 序幕\n\n关键词 在正文里',
        '下一页 关键词',
      ];

      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: '第一章',
          occurrenceIndex: 0,
          chapterTitle: chapterTitle,
          trimFirstPageTitlePrefix: true,
        ),
        isNull,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: '关键词',
          occurrenceIndex: 0,
          chapterTitle: chapterTitle,
          trimFirstPageTitlePrefix: true,
        ),
        0,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: '关键词',
          occurrenceIndex: 1,
          chapterTitle: chapterTitle,
          trimFirstPageTitlePrefix: true,
        ),
        1,
      );
    });

    test('空 query、空页或非法序号返回空', () {
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: const <String>[],
          query: 'foo',
          occurrenceIndex: 0,
        ),
        isNull,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: const <String>['foo'],
          query: '   ',
          occurrenceIndex: 0,
        ),
        isNull,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: const <String>['foo'],
          query: 'foo',
          occurrenceIndex: -1,
        ),
        isNull,
      );
    });

    test('大小写敏感匹配，行为与 legacy indexOf 一致', () {
      const pages = <String>[
        'Foo in first page',
        'foo in second page',
      ];

      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: 'foo',
          occurrenceIndex: 0,
        ),
        1,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOccurrence(
          pages: pages,
          query: 'Foo',
          occurrenceIndex: 0,
        ),
        0,
      );
    });
  });

  group('ReaderSearchNavigationHelper.resolvePageIndexByOffset', () {
    test('按字符偏移定位到正确页（含越界兜底）', () {
      const pages = <String>[
        'abc',
        'defg',
        'h',
      ];

      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOffset(
          pages: pages,
          contentOffset: 0,
        ),
        0,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOffset(
          pages: pages,
          contentOffset: 2,
        ),
        0,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOffset(
          pages: pages,
          contentOffset: 3,
        ),
        1,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOffset(
          pages: pages,
          contentOffset: 7,
        ),
        2,
      );
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOffset(
          pages: pages,
          contentOffset: 999,
        ),
        2,
      );
    });

    test('空页返回空', () {
      expect(
        ReaderSearchNavigationHelper.resolvePageIndexByOffset(
          pages: const <String>[],
          contentOffset: 0,
        ),
        isNull,
      );
    });
  });

  group('ReaderSearchNavigationHelper.resolveNextHitIndex', () {
    test('中间命中按增减量移动', () {
      expect(
        ReaderSearchNavigationHelper.resolveNextHitIndex(
          currentIndex: 1,
          delta: 1,
          totalHits: 4,
        ),
        2,
      );
      expect(
        ReaderSearchNavigationHelper.resolveNextHitIndex(
          currentIndex: 2,
          delta: -1,
          totalHits: 4,
        ),
        1,
      );
    });

    test('到达边界后钳制，不循环', () {
      expect(
        ReaderSearchNavigationHelper.resolveNextHitIndex(
          currentIndex: 0,
          delta: -1,
          totalHits: 3,
        ),
        0,
      );
      expect(
        ReaderSearchNavigationHelper.resolveNextHitIndex(
          currentIndex: 2,
          delta: 1,
          totalHits: 3,
        ),
        2,
      );
    });

    test('空结果返回 -1', () {
      expect(
        ReaderSearchNavigationHelper.resolveNextHitIndex(
          currentIndex: 0,
          delta: 1,
          totalHits: 0,
        ),
        -1,
      );
    });
  });
}
