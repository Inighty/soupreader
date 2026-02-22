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
    VoidCallback? onChangeSource,
    VoidCallback? onChangeSourceLongPress,
    VoidCallback? onRefresh,
    VoidCallback? onRefreshLongPress,
    VoidCallback? onOfflineCache,
    VoidCallback? onTocRule,
    VoidCallback? onSetCharset,
    bool showChangeSourceAction = false,
    bool showRefreshAction = false,
    bool showDownloadAction = false,
    bool showTocRuleAction = false,
    bool showSetCharsetAction = false,
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
      onChangeSource: onChangeSource,
      onChangeSourceLongPress: onChangeSourceLongPress,
      onRefresh: onRefresh,
      onRefreshLongPress: onRefreshLongPress,
      onOfflineCache: onOfflineCache,
      onTocRule: onTocRule,
      onSetCharset: onSetCharset,
      onShowSourceActions: () {},
      onShowMoreMenu: () {},
      showChangeSourceAction: showChangeSourceAction,
      showRefreshAction: showRefreshAction,
      showDownloadAction: showDownloadAction,
      showTocRuleAction: showTocRuleAction,
      showSetCharsetAction: showSetCharsetAction,
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

  testWidgets('ReaderTopMenu 换源按钮支持点击与长按回调', (tester) async {
    var tapCount = 0;
    var longPressCount = 0;
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(
        showChangeSourceAction: true,
        onChangeSource: () => tapCount += 1,
        onChangeSourceLongPress: () => longPressCount += 1,
      ),
    );

    final changeSourceButton =
        find.byKey(const Key('reader_top_menu_change_source'));
    expect(changeSourceButton, findsOneWidget);

    await tester.tap(changeSourceButton);
    await tester.pump();
    expect(tapCount, 1);

    await tester.longPress(changeSourceButton);
    await tester.pump();
    expect(longPressCount, 1);
  });

  testWidgets('ReaderTopMenu 可隐藏换源按钮', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(showChangeSourceAction: false),
    );
    expect(
        find.byKey(const Key('reader_top_menu_change_source')), findsNothing);
  });

  testWidgets('ReaderTopMenu 刷新按钮支持点击与长按回调', (tester) async {
    var tapCount = 0;
    var longPressCount = 0;
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(
        showRefreshAction: true,
        onRefresh: () => tapCount += 1,
        onRefreshLongPress: () => longPressCount += 1,
      ),
    );

    final refreshButton = find.byKey(const Key('reader_top_menu_refresh'));
    expect(refreshButton, findsOneWidget);

    await tester.tap(refreshButton);
    await tester.pump();
    expect(tapCount, 1);

    await tester.longPress(refreshButton);
    await tester.pump();
    expect(longPressCount, 1);
  });

  testWidgets('ReaderTopMenu 可隐藏刷新按钮', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(showRefreshAction: false),
    );
    expect(find.byKey(const Key('reader_top_menu_refresh')), findsNothing);
  });

  testWidgets('ReaderTopMenu 离线缓存按钮支持点击回调', (tester) async {
    var tapCount = 0;
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(
        showDownloadAction: true,
        onOfflineCache: () => tapCount += 1,
      ),
    );

    final downloadButton =
        find.byKey(const Key('reader_top_menu_offline_cache'));
    expect(downloadButton, findsOneWidget);

    await tester.tap(downloadButton);
    await tester.pump();
    expect(tapCount, 1);
  });

  testWidgets('ReaderTopMenu 可隐藏离线缓存按钮', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(showDownloadAction: false),
    );
    expect(
      find.byKey(const Key('reader_top_menu_offline_cache')),
      findsNothing,
    );
  });

  testWidgets('ReaderTopMenu TXT 目录规则按钮支持点击回调', (tester) async {
    var tapCount = 0;
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(
        showTocRuleAction: true,
        onTocRule: () => tapCount += 1,
      ),
    );

    final tocRuleButton = find.byKey(const Key('reader_top_menu_toc_rule'));
    expect(tocRuleButton, findsOneWidget);

    await tester.tap(tocRuleButton);
    await tester.pump();
    expect(tapCount, 1);
  });

  testWidgets('ReaderTopMenu 可隐藏 TXT 目录规则按钮', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(showTocRuleAction: false),
    );
    expect(
      find.byKey(const Key('reader_top_menu_toc_rule')),
      findsNothing,
    );
  });

  testWidgets('ReaderTopMenu 设置编码按钮支持点击回调', (tester) async {
    var tapCount = 0;
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(
        showSetCharsetAction: true,
        onSetCharset: () => tapCount += 1,
      ),
    );

    final setCharsetButton =
        find.byKey(const Key('reader_top_menu_set_charset'));
    expect(setCharsetButton, findsOneWidget);

    await tester.tap(setCharsetButton);
    await tester.pump();
    expect(tapCount, 1);
  });

  testWidgets('ReaderTopMenu 可隐藏设置编码按钮', (tester) async {
    await pumpTopMenu(
      tester,
      logicalWidth: 430,
      menu: buildMenu(showSetCharsetAction: false),
    );
    expect(
      find.byKey(const Key('reader_top_menu_set_charset')),
      findsNothing,
    );
  });
}
