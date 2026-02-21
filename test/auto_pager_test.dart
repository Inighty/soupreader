import 'package:fake_async/fake_async.dart';
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
}
