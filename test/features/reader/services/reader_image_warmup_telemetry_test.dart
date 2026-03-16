import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_image_warmup_telemetry.dart';

void main() {
  group('ReaderImageWarmupSourceTelemetry', () {
    late ReaderImageWarmupSourceTelemetry telemetry;

    setUp(() {
      telemetry = ReaderImageWarmupSourceTelemetry();
    });

    test('starts with zero samples', () {
      expect(telemetry.sampleCount, 0);
      expect(telemetry.successRateEma, 0.0);
    });

    test('records single success', () {
      telemetry.recordSuccess();
      expect(telemetry.sampleCount, 1);
      expect(telemetry.successRateEma, greaterThan(0));
      expect(telemetry.timeoutStreak, 0);
    });

    test('timeout streak increments on consecutive timeouts', () {
      telemetry.recordFailure(ReaderImageWarmupFailureKind.timeout);
      telemetry.recordFailure(ReaderImageWarmupFailureKind.timeout);
      telemetry.recordFailure(ReaderImageWarmupFailureKind.timeout);
      expect(telemetry.timeoutStreak, 3);
      expect(telemetry.authStreak, 0);
    });

    test('success resets all streaks', () {
      telemetry.recordFailure(ReaderImageWarmupFailureKind.timeout);
      telemetry.recordFailure(ReaderImageWarmupFailureKind.timeout);
      expect(telemetry.timeoutStreak, 2);
      telemetry.recordSuccess();
      expect(telemetry.timeoutStreak, 0);
      expect(telemetry.authStreak, 0);
      expect(telemetry.decodeStreak, 0);
    });

    test('auth failure resets timeout streak', () {
      telemetry.recordFailure(ReaderImageWarmupFailureKind.timeout);
      telemetry.recordFailure(ReaderImageWarmupFailureKind.timeout);
      telemetry.recordFailure(ReaderImageWarmupFailureKind.auth);
      expect(telemetry.timeoutStreak, 0);
      expect(telemetry.authStreak, 1);
    });

    test('sample count is clamped to 4096', () {
      for (int i = 0; i < 4100; i++) {
        telemetry.recordSuccess();
      }
      expect(telemetry.sampleCount, 4096);
    });

    test('EMA converges toward 1.0 with all successes', () {
      for (int i = 0; i < 50; i++) {
        telemetry.recordSuccess();
      }
      expect(telemetry.successRateEma, greaterThan(0.9));
      expect(telemetry.timeoutRateEma, lessThan(0.1));
    });
  });

  group('ReaderImageWarmupErrorClassifier', () {
    test('classifies timeout errors', () {
      expect(
        ReaderImageWarmupErrorClassifier.classify(
          Exception('Connection timed out'),
        ),
        ReaderImageWarmupFailureKind.timeout,
      );
    });

    test('classifies auth errors', () {
      expect(
        ReaderImageWarmupErrorClassifier.classify(
          Exception('403 Forbidden'),
        ),
        ReaderImageWarmupFailureKind.auth,
      );
    });

    test('classifies decode errors', () {
      expect(
        ReaderImageWarmupErrorClassifier.classify(
          Exception('Invalid image codec'),
        ),
        ReaderImageWarmupFailureKind.decode,
      );
    });

    test('classifies unknown errors as other', () {
      expect(
        ReaderImageWarmupErrorClassifier.classify(
          Exception('Something went wrong'),
        ),
        ReaderImageWarmupFailureKind.other,
      );
    });

    group('merge', () {
      test('returns candidate when current is null', () {
        expect(
          ReaderImageWarmupErrorClassifier.merge(
            null,
            ReaderImageWarmupFailureKind.timeout,
          ),
          ReaderImageWarmupFailureKind.timeout,
        );
      });

      test('returns same when both are equal', () {
        expect(
          ReaderImageWarmupErrorClassifier.merge(
            ReaderImageWarmupFailureKind.auth,
            ReaderImageWarmupFailureKind.auth,
          ),
          ReaderImageWarmupFailureKind.auth,
        );
      });

      test('prefers more specific error', () {
        expect(
          ReaderImageWarmupErrorClassifier.merge(
            ReaderImageWarmupFailureKind.other,
            ReaderImageWarmupFailureKind.auth,
          ),
          ReaderImageWarmupFailureKind.auth,
        );
      });
    });
  });

  group('ReaderImageWarmupBudget', () {
    test('stores probe count and durations', () {
      const budget = ReaderImageWarmupBudget(
        probeCount: 8,
        maxDuration: Duration(milliseconds: 260),
        perProbeTimeout: Duration(milliseconds: 220),
      );
      expect(budget.probeCount, 8);
      expect(budget.maxDuration.inMilliseconds, 260);
      expect(budget.perProbeTimeout.inMilliseconds, 220);
    });
  });
}
