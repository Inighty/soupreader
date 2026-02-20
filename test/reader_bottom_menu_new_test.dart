import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/colors.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/widgets/reader_bottom_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpMenu(
    WidgetTester tester, {
    required ReaderBottomMenuNew menu,
  }) async {
    final shadTheme = AppShadcnTheme.light();
    await tester.pumpWidget(
      ShadApp.custom(
        theme: shadTheme,
        darkTheme: shadTheme,
        appBuilder: (context) => CupertinoApp(
          home: CupertinoPageScaffold(
            child: SizedBox.expand(
              child: Stack(children: [menu]),
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
