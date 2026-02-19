import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/services/reader_source_switch_helper.dart';
import 'package:soupreader/features/reader/widgets/source_switch_candidate_sheet.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

BookSource _source({required String url, required String name}) {
  return BookSource(bookSourceUrl: url, bookSourceName: name);
}

SearchResult _search({
  required String sourceUrl,
  required String sourceName,
  required String author,
  required String lastChapter,
  required String bookUrl,
}) {
  return SearchResult(
    name: '测试书',
    author: author,
    coverUrl: '',
    intro: '',
    lastChapter: lastChapter,
    bookUrl: bookUrl,
    sourceUrl: sourceUrl,
    sourceName: sourceName,
  );
}

ReaderSourceSwitchCandidate _candidate({
  required String sourceUrl,
  required String sourceName,
  required String author,
  required String lastChapter,
  required String bookUrl,
}) {
  return ReaderSourceSwitchCandidate(
    source: _source(url: sourceUrl, name: sourceName),
    book: _search(
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      author: author,
      lastChapter: lastChapter,
      bookUrl: bookUrl,
    ),
  );
}

void main() {
  testWidgets(
      'source switch sheet filters by source/chapter and returns selection', (
    tester,
  ) async {
    final candidates = <ReaderSourceSwitchCandidate>[
      _candidate(
        sourceUrl: 'https://source-a',
        sourceName: '星河书源',
        author: '作者甲',
        lastChapter: '第128章 深空',
        bookUrl: 'https://book-a',
      ),
      _candidate(
        sourceUrl: 'https://source-b',
        sourceName: '晨光书源',
        author: '作者乙',
        lastChapter: '第129章 终章',
        bookUrl: 'https://book-b',
      ),
      _candidate(
        sourceUrl: 'https://source-c',
        sourceName: '山海书源',
        author: '作者丙',
        lastChapter: '番外篇',
        bookUrl: 'https://book-c',
      ),
    ];

    ReaderSourceSwitchCandidate? selected;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () async {
                  selected = await showSourceSwitchCandidateSheet(
                    context: context,
                    keyword: '测试书',
                    candidates: candidates,
                  );
                },
                child: const Text('打开换源'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开换源'));
    await tester.pumpAndSettle();

    expect(find.text('换源（测试书）'), findsOneWidget);
    expect(find.text('候选 3 条'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), '晨光');
    await tester.pumpAndSettle();

    expect(find.text('晨光书源'), findsOneWidget);
    expect(find.text('星河书源'), findsNothing);
    expect(find.text('山海书源'), findsNothing);

    await tester.enterText(find.byType(CupertinoSearchTextField), '终章');
    await tester.pumpAndSettle();

    expect(find.text('晨光书源'), findsOneWidget);

    await tester.tap(find.text('晨光书源'));
    await tester.pumpAndSettle();

    expect(selected?.source.bookSourceName, '晨光书源');
    expect(selected?.book.bookUrl, 'https://book-b');
  });

  testWidgets('source switch sheet shows empty message when no match',
      (tester) async {
    final candidates = <ReaderSourceSwitchCandidate>[
      _candidate(
        sourceUrl: 'https://source-a',
        sourceName: '星河书源',
        author: '作者甲',
        lastChapter: '第128章 深空',
        bookUrl: 'https://book-a',
      ),
    ];

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () {
                  showSourceSwitchCandidateSheet(
                    context: context,
                    keyword: '测试书',
                    candidates: candidates,
                  );
                },
                child: const Text('打开换源'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开换源'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoSearchTextField), '不存在');
    await tester.pumpAndSettle();

    expect(find.text('无匹配候选'), findsOneWidget);
  });
}
