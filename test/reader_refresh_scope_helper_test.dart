import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/reader/services/reader_legacy_menu_helper.dart';
import 'package:soupreader/features/reader/services/reader_refresh_scope_helper.dart';

Chapter _chapter({
  required int index,
  String? content,
  bool isDownloaded = false,
}) {
  return Chapter(
    id: 'chapter-$index',
    bookId: 'book-1',
    title: '第${index + 1}章',
    url: 'https://example.com/$index',
    index: index,
    content: content,
    isDownloaded: isDownloaded,
  );
}

void main() {
  test('menu_refresh_after 对应从当前章开始清理后续章节', () {
    final selection = ReaderRefreshScopeHelper.selectionFromLegacyAction(
      action: ReaderLegacyRefreshMenuAction.after,
      currentChapterIndex: 3,
    );

    expect(selection.startIndex, 3);
    expect(selection.clearFollowing, isTrue);
  });

  test('menu_refresh_all 对应从首章开始清理全部章节', () {
    final selection = ReaderRefreshScopeHelper.selectionFromLegacyAction(
      action: ReaderLegacyRefreshMenuAction.all,
      currentChapterIndex: 3,
    );

    expect(selection.startIndex, 0);
    expect(selection.clearFollowing, isTrue);
  });

  test('刷新之后章节仅清理当前及后续缓存，前序章节保持不变', () {
    final chapters = <Chapter>[
      _chapter(index: 0, content: 'chapter0', isDownloaded: true),
      _chapter(index: 1, content: 'chapter1', isDownloaded: true),
      _chapter(index: 2, content: 'chapter2', isDownloaded: true),
      _chapter(index: 3),
    ];

    final result = ReaderRefreshScopeHelper.clearCachedRange(
      chapters: chapters,
      startIndex: 1,
      clearFollowing: true,
    );

    expect(result.startIndex, 1);
    expect(result.endIndex, 3);
    expect(result.hasRange, isTrue);

    expect(result.nextChapters[0], same(chapters[0]));

    expect(result.nextChapters[1].content, isNull);
    expect(result.nextChapters[1].isDownloaded, isFalse);
    expect(result.nextChapters[2].content, isNull);
    expect(result.nextChapters[2].isDownloaded, isFalse);
    expect(result.nextChapters[3].content, isNull);
    expect(result.nextChapters[3].isDownloaded, isFalse);

    expect(result.updates.map((chapter) => chapter.id).toList(),
        <String>['chapter-1', 'chapter-2']);
  });

  test('刷新全部章节清理全量缓存并回写已变更章节', () {
    final chapters = <Chapter>[
      _chapter(index: 0, content: 'chapter0', isDownloaded: true),
      _chapter(index: 1, content: null, isDownloaded: false),
      _chapter(index: 2, content: 'chapter2', isDownloaded: false),
      _chapter(index: 3, content: null, isDownloaded: true),
    ];

    final result = ReaderRefreshScopeHelper.clearCachedRange(
      chapters: chapters,
      startIndex: 0,
      clearFollowing: true,
    );

    expect(result.startIndex, 0);
    expect(result.endIndex, 3);
    expect(result.hasRange, isTrue);

    for (var index = 0; index < result.nextChapters.length; index += 1) {
      expect(result.nextChapters[index].content, isNull);
      expect(result.nextChapters[index].isDownloaded, isFalse);
    }

    expect(result.updates.map((chapter) => chapter.id).toList(),
        <String>['chapter-0', 'chapter-2', 'chapter-3']);
  });

  test('刷新范围计算可处理空章节列表', () {
    final result = ReaderRefreshScopeHelper.clearCachedRange(
      chapters: const <Chapter>[],
      startIndex: 0,
      clearFollowing: true,
    );

    expect(result.hasRange, isFalse);
    expect(result.nextChapters, isEmpty);
    expect(result.updates, isEmpty);
  });
}
