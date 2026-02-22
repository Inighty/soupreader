import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/bookmark_repository.dart';
import 'package:soupreader/core/database/repositories/book_repository.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/reader/services/reader_bookmark_export_service.dart';
import 'package:soupreader/features/search/views/search_book_info_view.dart';
import 'package:soupreader/features/source/models/book_source.dart';

Widget _buildTestApp(Widget home) {
  final shadTheme = AppShadcnTheme.light();
  return ShadApp.custom(
    theme: shadTheme,
    darkTheme: shadTheme,
    appBuilder: (context) {
      final shad = ShadTheme.of(context);
      final cupertinoTheme = CupertinoTheme.of(context).copyWith(
        barBackgroundColor: shad.colorScheme.background.withValues(alpha: 0.92),
      );
      return CupertinoApp(
        theme: cupertinoTheme,
        home: home,
        builder: (context, child) => ShadAppBuilder(child: child!),
      );
    },
  );
}

Book _buildBook({
  required String id,
  required String sourceUrl,
}) {
  return Book(
    id: id,
    title: '目录搜索测试书',
    author: '测试作者',
    sourceUrl: sourceUrl,
    sourceId: sourceUrl,
    bookUrl: 'https://book.example.com/$id',
    isLocal: false,
  );
}

BookSource _buildSource(String sourceUrl) {
  return BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: '目录搜索测试源',
  );
}

List<Chapter> _buildChapters(String bookId) {
  return <Chapter>[
    Chapter(
      id: '${bookId}_0',
      bookId: bookId,
      title: '第一章 起始',
      url: 'https://book.example.com/$bookId/1',
      index: 0,
    ),
    Chapter(
      id: '${bookId}_1',
      bookId: bookId,
      title: '第二章 进展',
      url: 'https://book.example.com/$bookId/2',
      index: 1,
    ),
    Chapter(
      id: '${bookId}_2',
      bookId: bookId,
      title: '番外篇',
      url: 'https://book.example.com/$bookId/3',
      index: 2,
    ),
  ];
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_toc_search_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
    await SettingsService().init();
  });

  tearDownAll(() async {
    try {
      await DatabaseService().close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseService().clearAll();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  testWidgets('目录页 menu_search 默认折叠，展开后按章节标题过滤', (WidgetTester tester) async {
    const sourceUrl = 'https://source-toc-search-action.example.com';
    const bookId = 'book-toc-search-action';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final chapterRepo = ChapterRepository(DatabaseService());
    final book = _buildBook(id: bookId, sourceUrl: sourceUrl);

    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
      await bookRepo.addBook(book);
      await chapterRepo.addChapters(_buildChapters(bookId));
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final openTocButton = find.widgetWithText(CupertinoButton, '查看').first;
    expect(openTocButton, findsOneWidget);
    await tester.tap(openTocButton);
    await tester.pumpAndSettle();

    const menuSearchActionKey = Key('search_book_toc_menu_search_action');
    const menuSearchFieldKey = Key('search_book_toc_menu_search_field');
    const menuSearchCloseKey = Key('search_book_toc_menu_search_close');

    expect(find.byKey(menuSearchActionKey), findsOneWidget);
    expect(find.byKey(menuSearchFieldKey), findsNothing);

    await tester.tap(find.byKey(menuSearchActionKey));
    await tester.pumpAndSettle();
    expect(find.byKey(menuSearchFieldKey), findsOneWidget);

    await tester.enterText(find.byKey(menuSearchFieldKey), '第二章');
    await tester.pumpAndSettle();

    expect(find.text('第二章 进展'), findsOneWidget);
    expect(find.text('第一章 起始'), findsNothing);
    expect(find.text('番外篇'), findsNothing);

    await tester.tap(find.byKey(menuSearchCloseKey));
    await tester.pumpAndSettle();

    expect(find.byKey(menuSearchFieldKey), findsNothing);
    expect(find.text('第一章 起始'), findsOneWidget);
    expect(find.text('第二章 进展'), findsOneWidget);
    expect(find.text('番外篇'), findsOneWidget);
  });

  testWidgets('目录页 menu_reverse_toc 通过更多菜单触发反转目录', (WidgetTester tester) async {
    const sourceUrl = 'https://source-toc-reverse-action.example.com';
    const bookId = 'book-toc-reverse-action';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final chapterRepo = ChapterRepository(DatabaseService());
    final book = _buildBook(id: bookId, sourceUrl: sourceUrl);

    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
      await bookRepo.addBook(book);
      await chapterRepo.addChapters(_buildChapters(bookId));
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final openTocButton = find.widgetWithText(CupertinoButton, '查看').first;
    expect(openTocButton, findsOneWidget);
    await tester.tap(openTocButton);
    await tester.pumpAndSettle();

    double topOf(String title) => tester.getTopLeft(find.text(title)).dy;

    expect(topOf('第一章 起始'), lessThan(topOf('番外篇')));

    const menuMoreActionKey = Key('search_book_toc_menu_more_action');
    const menuReverseTocActionKey =
        Key('search_book_toc_menu_reverse_toc_action');

    await tester.tap(find.byKey(menuMoreActionKey));
    await tester.pumpAndSettle();
    expect(find.byKey(menuReverseTocActionKey), findsOneWidget);
    expect(find.text('反转目录'), findsOneWidget);

    await tester.tap(find.byKey(menuReverseTocActionKey));
    await tester.pumpAndSettle();

    expect(topOf('第一章 起始'), greaterThan(topOf('番外篇')));
  });

  testWidgets('目录页 menu_export_bookmark 通过更多菜单触发导出',
      (WidgetTester tester) async {
    const sourceUrl = 'https://source-toc-export-bookmark-action.example.com';
    const bookId = 'book-toc-export-bookmark-action';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final bookmarkRepo = BookmarkRepository();
    final chapterRepo = ChapterRepository(DatabaseService());
    final book = _buildBook(id: bookId, sourceUrl: sourceUrl);
    final exportService = ReaderBookmarkExportService(
      saveFile: ({
        required String dialogTitle,
        required String fileName,
        required List<String> allowedExtensions,
      }) async {
        expect(dialogTitle, '导出书签');
        expect(fileName.endsWith('.json'), isTrue);
        expect(allowedExtensions, <String>['json']);
        return '${tempDir.path}/export-bookmark-test.json';
      },
      writeFile: ({
        required String path,
        required String content,
      }) async {},
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
      await bookRepo.addBook(book);
      await chapterRepo.addChapters(_buildChapters(bookId));
      await bookmarkRepo.init();
      await bookmarkRepo.addBookmark(
        bookId: bookId,
        bookName: book.title,
        bookAuthor: book.author,
        chapterIndex: 1,
        chapterTitle: '第二章 进展',
        chapterPos: 0,
        content: '测试书签内容',
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(
          book: book,
          bookmarkExportService: exportService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final openTocButton = find.widgetWithText(CupertinoButton, '查看').first;
    expect(openTocButton, findsOneWidget);
    await tester.tap(openTocButton);
    await tester.pumpAndSettle();

    const menuMoreActionKey = Key('search_book_toc_menu_more_action');
    const menuExportBookmarkActionKey =
        Key('search_book_toc_menu_export_bookmark_action');

    await tester.tap(find.byKey(menuMoreActionKey));
    await tester.pumpAndSettle();

    expect(find.byKey(menuExportBookmarkActionKey), findsOneWidget);
    expect(find.text('导出'), findsOneWidget);

    await tester.tap(find.byKey(menuExportBookmarkActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('导出成功'), findsOneWidget);
    await tester.tap(find.text('好').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('目录页 menu_export_md 通过更多菜单触发导出(MD)', (WidgetTester tester) async {
    const sourceUrl = 'https://source-toc-export-markdown-action.example.com';
    const bookId = 'book-toc-export-markdown-action';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final bookmarkRepo = BookmarkRepository();
    final chapterRepo = ChapterRepository(DatabaseService());
    final book = _buildBook(id: bookId, sourceUrl: sourceUrl);
    final exportService = ReaderBookmarkExportService(
      saveFile: ({
        required String dialogTitle,
        required String fileName,
        required List<String> allowedExtensions,
      }) async {
        expect(dialogTitle, '导出 Markdown');
        expect(fileName.endsWith('.md'), isTrue);
        expect(allowedExtensions, <String>['md']);
        return '${tempDir.path}/export-bookmark-test.md';
      },
      writeFile: ({
        required String path,
        required String content,
      }) async {},
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
      await bookRepo.addBook(book);
      await chapterRepo.addChapters(_buildChapters(bookId));
      await bookmarkRepo.init();
      await bookmarkRepo.addBookmark(
        bookId: bookId,
        bookName: book.title,
        bookAuthor: book.author,
        chapterIndex: 2,
        chapterTitle: '番外篇',
        chapterPos: 0,
        content: 'Markdown 书签内容',
      );
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(
          book: book,
          bookmarkExportService: exportService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final openTocButton = find.widgetWithText(CupertinoButton, '查看').first;
    expect(openTocButton, findsOneWidget);
    await tester.tap(openTocButton);
    await tester.pumpAndSettle();

    const menuMoreActionKey = Key('search_book_toc_menu_more_action');
    const menuExportBookmarkMarkdownActionKey =
        Key('search_book_toc_menu_export_markdown_action');

    await tester.tap(find.byKey(menuMoreActionKey));
    await tester.pumpAndSettle();

    expect(find.byKey(menuExportBookmarkMarkdownActionKey), findsOneWidget);
    expect(find.text('导出(MD)'), findsOneWidget);

    await tester.tap(find.byKey(menuExportBookmarkMarkdownActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('导出成功'), findsOneWidget);
    await tester.tap(find.text('好').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  });
}
