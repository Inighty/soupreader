import 'package:fake_async/fake_async.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/widgets/auto_pager.dart';

void main() {
  test('AutoPager page mode should trigger next-page callback periodically',
      () {
    fakeAsync((async) {
      final pager = AutoPager();
      var triggerCount = 0;
      pager.setMode(AutoPagerMode.page);
      pager.setSpeed(1); // 1s/次
      pager.setOnNextPage(() {
        triggerCount += 1;
      });

      pager.start();
      async.elapse(const Duration(milliseconds: 999));
      expect(triggerCount, 0);

      async.elapse(const Duration(milliseconds: 2));
      expect(triggerCount, 1);

      async.elapse(const Duration(seconds: 2));
      expect(triggerCount, 3);

      pager.stop();
      async.elapse(const Duration(seconds: 3));
      expect(triggerCount, 3);
    });
  });

  test('AutoPager toggle should pause and resume callbacks', () {
    fakeAsync((async) {
      final pager = AutoPager();
      var triggerCount = 0;
      pager.setMode(AutoPagerMode.page);
      pager.setSpeed(1);
      pager.setOnNextPage(() {
        triggerCount += 1;
      });

      pager.toggle(); // start
      async.elapse(const Duration(seconds: 1));
      expect(triggerCount, 1);
      expect(pager.isRunning, isTrue);

      pager.toggle(); // pause
      expect(pager.isRunning, isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(triggerCount, 1);

      pager.toggle(); // resume
      async.elapse(const Duration(seconds: 1));
      expect(triggerCount, 2);
      expect(pager.isRunning, isTrue);
    });
  });

  testWidgets('AutoReadPanel 速度在拖动结束后才提交', (tester) async {
    final pager = AutoPager()..setSpeed(10);
    final committedSpeeds = <int>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AutoReadPanel(
              autoPager: pager,
              onSpeedChanged: committedSpeeds.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('10s'), findsOneWidget);
    final sliderFinder = find.byType(CupertinoSlider);
    final slider = tester.widget<CupertinoSlider>(sliderFinder);
    slider.onChanged?.call(28);
    await tester.pump();

    expect(find.text('28s'), findsOneWidget);
    expect(pager.speed, 10);
    expect(committedSpeeds, isEmpty);

    final sliderAfterChange = tester.widget<CupertinoSlider>(sliderFinder);
    sliderAfterChange.onChangeEnd?.call(28);
    await tester.pump();

    expect(pager.speed, 28);
    expect(committedSpeeds, <int>[28]);
    expect(find.text('28s'), findsOneWidget);
  });

  testWidgets('AutoReadPanel 设置按钮触发翻页动画设置回调', (tester) async {
    final pager = AutoPager();
    var opened = false;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AutoReadPanel(
              autoPager: pager,
              onOpenPageAnimSettings: () {
                opened = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('设置'));
    await tester.pump();

    expect(opened, isTrue);
  });
}
