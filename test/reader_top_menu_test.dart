import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/app/theme/colors.dart';
import 'package:soupreader/app/theme/design_tokens.dart';
import 'package:soupreader/features/reader/widgets/reader_menu_surface_style.dart';
import 'package:soupreader/features/reader/widgets/reader_menus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpTopMenu(
    WidgetTester tester, {
    required double logicalWidth,
    required ReaderTopMenu menu,
  }) async {
    final view = tester.view;
    view.physicalSize = Size(logicalWidth * 2, 1800);
    view.devicePixelRatio = 2.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox.expand(
            child: Stack(
              children: [menu],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ReaderTopMenu buildMenu({
    ReadingThemeColors? theme,
    bool readBarStyleFollowPage = false,
  }) {
    return ReaderTopMenu(
      bookTitle: '明克街13号',
      chapterTitle: '第五百九十九章 前不久，我刚杀了一个',
      chapterUrl: 'https://www.example.com/chapter/599',
      sourceName: '笔趣阁',
      currentTheme: theme ?? AppColors.readingThemes.first,
      onOpenBookInfo: () {},
      onOpenChapterLink: () {},
      onToggleChapterLinkOpenMode: () {},
      onShowSourceActions: () {},
      onShowMoreMenu: () {},
      showSourceAction: true,
      showChapterLink: true,
      showTitleAddition: true,
      readBarStyleFollowPage: readBarStyleFollowPage,
    );
  }

  testWidgets('ReaderTopMenu 窄屏下隐藏 URL 但保留章节名与书源按钮', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 360,
      menu: buildMenu(),
    );

    expect(find.text('第五百九十九章 前不久，我刚杀了一个'), findsOneWidget);
    expect(find.text('笔趣阁'), findsOneWidget);
    expect(find.text('https://www.example.com/chapter/599'), findsNothing);
  });

  testWidgets('ReaderTopMenu 常规宽度下显示 URL', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(),
    );

    expect(find.text('第五百九十九章 前不久，我刚杀了一个'), findsOneWidget);
    expect(find.text('笔趣阁'), findsOneWidget);
    expect(find.text('https://www.example.com/chapter/599'), findsOneWidget);
  });

  testWidgets('ReaderTopMenu 默认配色使用统一菜单色板（非写死深色）', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(),
    );

    final panel = tester.widget<Container>(
      find.byKey(const Key('reader_top_menu_panel')),
    );
    final decoration = panel.decoration as BoxDecoration;
    expect(decoration.color, ReaderOverlayTokens.panelLight);
  });

  testWidgets('ReaderTopMenu 跟随页面时使用阅读主题面板色板', (tester) async {
    final theme = AppColors.legadoClassicTheme;
    final expectedStyle = resolveReaderMenuSurfaceStyle(
      currentTheme: theme,
      readBarStyleFollowPage: true,
    );
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(
        theme: theme,
        readBarStyleFollowPage: true,
      ),
    );

    final panel = tester.widget<Container>(
      find.byKey(const Key('reader_top_menu_panel')),
    );
    final decoration = panel.decoration as BoxDecoration;
    expect(decoration.color, expectedStyle.panelBackground);
  });
}
