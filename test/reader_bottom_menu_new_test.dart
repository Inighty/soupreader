import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/colors.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/widgets/reader_bottom_menu.dart';
import 'package:soupreader/features/reader/widgets/reader_menu_surface_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMenu(
    WidgetTester tester, {
    required ReaderBottomMenuNew menu,
    EdgeInsets? mediaPadding,
    EdgeInsets? mediaViewPadding,
  }) async {
    final shadTheme = AppShadcnTheme.light();
    await tester.pumpWidget(
      ShadApp.custom(
        theme: shadTheme,
        darkTheme: shadTheme,
        appBuilder: (context) => CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) {
                final base = MediaQuery.of(context);
                return MediaQuery(
                  data: base.copyWith(
                    padding: mediaPadding ?? base.padding,
                    viewPadding: mediaViewPadding ?? base.viewPadding,
                  ),
                  child: SizedBox.expand(
                    child: Stack(children: [menu]),
                  ),
                );
              },
            ),
          ),
          builder: (context, child) => ShadAppBuilder(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ReaderBottomMenuNew 底部按钮顺序与回调映射同义', (tester) async {
    final events = <String>[];

    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () => events.add('catalog'),
        onShowReadAloud: () => events.add('readAloud'),
        onShowInterfaceSettings: () => events.add('interface'),
        onShowBehaviorSettings: () => events.add('settings'),
      ),
    );

    const labels = ['目录', '朗读', '界面', '设置'];
    double lastDx = -1;
    for (final label in labels) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final dx = tester.getCenter(finder).dx;
      expect(dx, greaterThan(lastDx));
      lastDx = dx;
    }

    await tester.tap(find.text('目录'));
    await tester.pump();
    expect(events.removeLast(), 'catalog');

    await tester.tap(find.text('朗读'));
    await tester.pump();
    expect(events.removeLast(), 'readAloud');

    await tester.tap(find.text('界面'));
    await tester.pump();
    expect(events.removeLast(), 'interface');

    await tester.tap(find.text('设置'));
    await tester.pump();
    expect(events.removeLast(), 'settings');
  });

  testWidgets('ReaderBottomMenuNew 章节按钮可点击条件与边界同义', (tester) async {
    final chapterChanges = <int>[];

    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 0,
        totalChapters: 3,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: chapterChanges.add,
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    await tester.tap(find.text('上一章'));
    await tester.pump();
    expect(chapterChanges, isEmpty);

    await tester.tap(find.text('下一章'));
    await tester.pump();
    expect(chapterChanges, [1]);
  });

  testWidgets('ReaderBottomMenuNew 使用统一菜单色板', (tester) async {
    const theme = ReadingThemeColors(
      background: Color(0xFFF7F4EE),
      text: Color(0xFF1F2328),
      name: '日间',
    );
    final expected = resolveReaderMenuSurfaceStyle(
      currentTheme: theme,
      readBarStyleFollowPage: false,
    );

    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: theme,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    final panel = tester.widget<Container>(
      find.byKey(const Key('reader_bottom_menu_panel')),
    );
    final decoration = panel.decoration as BoxDecoration;
    expect(decoration.color, expected.panelBackground);
  });

  testWidgets('ReaderBottomMenuNew 四入口热区宽度对齐 legacy 60dp', (tester) async {
    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    const labels = ['目录', '朗读', '界面', '设置'];
    for (final label in labels) {
      final hotArea = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 60,
        ),
      );
      expect(hotArea, findsOneWidget);
    }
  });

  testWidgets('ReaderBottomMenuNew 四入口图标与字号对齐 legacy 节奏', (tester) async {
    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    const labels = ['目录', '朗读', '界面', '设置'];
    for (final label in labels) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontSize, 12);
    }

    expect(
        tester.widget<Icon>(find.byIcon(CupertinoIcons.list_bullet)).size, 20);
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.speaker_2_fill)).size,
      20,
    );
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.circle_grid_3x3)).size,
      20,
    );
    expect(tester.widget<Icon>(find.byIcon(CupertinoIcons.gear)).size, 20);
  });

  testWidgets('ReaderBottomMenuNew 亮度侧栏默认在左侧且支持位置切换', (tester) async {
    ReadingSettings? latest;

    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (settings) => latest = settings,
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    final panel = find.byKey(const Key('reader_brightness_panel'));
    expect(panel, findsOneWidget);
    final panelDx = tester.getCenter(panel).dx;
    expect(panelDx, lessThan(150));

    await tester.tap(find.byKey(const Key('reader_brightness_pos')));
    await tester.pump();
    expect(latest, isNotNull);
    expect(latest!.brightnessViewOnRight, isTrue);
  });

  testWidgets('ReaderBottomMenuNew 标题附加信息开启时亮度栏下移', (tester) async {
    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(showReadTitleAddition: false),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );
    final panel = find.byKey(const Key('reader_brightness_panel'));
    expect(panel, findsOneWidget);
    final topWithoutAddition = tester.getTopLeft(panel).dy;

    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(showReadTitleAddition: true),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );
    final topWithAddition = tester.getTopLeft(panel).dy;
    expect(topWithAddition, greaterThan(topWithoutAddition + 10));
  });

  testWidgets('ReaderBottomMenuNew 支持亮度侧栏右侧布局', (tester) async {
    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(brightnessViewOnRight: true),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    final panel = find.byKey(const Key('reader_brightness_panel'));
    expect(panel, findsOneWidget);
    final panelDx = tester.getCenter(panel).dx;
    expect(panelDx, greaterThan(220));
  });

  testWidgets('ReaderBottomMenuNew 亮度侧栏在长屏下高度受限', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1080, 3600);
    view.devicePixelRatio = 3.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    final panel = find.byKey(const Key('reader_brightness_panel'));
    expect(panel, findsOneWidget);
    final panelHeight = tester.getSize(panel).height;
    expect(panelHeight, lessThanOrEqualTo(400));
    expect(panelHeight, greaterThanOrEqualTo(180));
  });

  testWidgets('ReaderBottomMenuNew 底栏背景覆盖到底部安全区', (tester) async {
    await pumpMenu(
      tester,
      mediaPadding: const EdgeInsets.only(bottom: 24),
      mediaViewPadding: const EdgeInsets.only(bottom: 24),
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
      ),
    );

    final panel = find.byKey(const Key('reader_bottom_menu_panel'));
    expect(panel, findsOneWidget);
    final panelRect = tester.getRect(panel);
    final pageRect = tester.getRect(find.byType(CupertinoPageScaffold));
    expect((pageRect.bottom - panelRect.bottom).abs(), lessThan(0.1));
  });

  testWidgets('ReaderBottomMenuNew 朗读入口支持长按与暂停态图标', (tester) async {
    var longPressed = false;

    await pumpMenu(
      tester,
      menu: ReaderBottomMenuNew(
        currentChapterIndex: 1,
        totalChapters: 5,
        currentPageIndex: 0,
        totalPages: 10,
        settings: const ReadingSettings(),
        currentTheme: AppColors.readingThemes.first,
        onChapterChanged: (_) {},
        onPageChanged: (_) {},
        onSeekChapterProgress: (_) {},
        onSettingsChanged: (_) {},
        onShowChapterList: () {},
        onShowReadAloud: () {},
        onReadAloudLongPress: () => longPressed = true,
        onShowInterfaceSettings: () {},
        onShowBehaviorSettings: () {},
        readAloudRunning: true,
        readAloudPaused: true,
      ),
    );

    expect(find.byIcon(CupertinoIcons.pause_circle), findsOneWidget);
    await tester.longPress(find.text('朗读'));
    await tester.pump();
    expect(longPressed, isTrue);
  });
}
