import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/reader/controllers/image_coordinator.dart';
import 'package:soupreader/features/reader/controllers/reader_state.dart';
import 'package:soupreader/features/reader/services/reader_image_request_parser.dart';
import 'package:soupreader/features/reader/services/reader_image_warmup_telemetry.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('ImageCoordinator', () {
    late ImageCacheState image;
    late ImageCoordinator coordinator;

    setUp(() {
      image = ImageCacheState();
      coordinator = ImageCoordinator(
        bookId: 'test-book',
        isEphemeral: false,
        image: image,
        settingsService: SettingsService(),
        ruleEngine: RuleParserEngine(),
        resolveCurrentSource: () => null,
        recentFetchDuration: () => Duration.zero,
      );
    });

    tearDown(() {
      coordinator.dispose();
    });

    group('rememberBookImageCacheKey', () {
      test('adds normalized key to bookCacheKeys', () {
        // This depends on ReaderImageMarkerCodec normalization,
        // but we can verify the set grows.
        coordinator.rememberBookImageCacheKey(
          'https://example.com/image.jpg',
        );
        // Key should be added (non-empty URL normalizes to
        // something).
        expect(image.bookCacheKeys, isNotEmpty);
      });

      test('ignores empty src', () {
        coordinator.rememberBookImageCacheKey('');
        expect(image.bookCacheKeys, isEmpty);
      });
    });

    group('lookupImageMeta', () {
      test('returns null for unknown src', () {
        final meta = coordinator.lookupImageMeta('unknown.jpg');
        expect(meta, isNull);
      });
    });

    group('recordLongImageErrorSample', () {
      test('updates EMA for long image', () {
        // A very tall image (ratio > 2.0 threshold)
        coordinator.recordLongImageErrorSample(
          src: 'https://example.com/tall.jpg',
          resolvedSize: const Size(100, 500),
        );
        expect(image.longImageErrorSamples, 1);
        expect(image.longImageErrorEma, greaterThan(0));
      });

      test('ignores non-long image', () {
        // Normal aspect ratio (< 2.0)
        coordinator.recordLongImageErrorSample(
          src: 'https://example.com/normal.jpg',
          resolvedSize: const Size(100, 150),
        );
        expect(image.longImageErrorSamples, 0);
      });

      test('ignores zero dimensions', () {
        coordinator.recordLongImageErrorSample(
          src: 'https://example.com/zero.jpg',
          resolvedSize: const Size(0, 0),
        );
        expect(image.longImageErrorSamples, 0);
      });

      test('ignores infinite dimensions', () {
        coordinator.recordLongImageErrorSample(
          src: 'https://example.com/inf.jpg',
          resolvedSize: const Size(double.infinity, 100),
        );
        expect(image.longImageErrorSamples, 0);
      });

      test('EMA converges with multiple samples', () {
        for (var i = 0; i < 5; i++) {
          coordinator.recordLongImageErrorSample(
            src: 'https://example.com/tall_$i.jpg',
            resolvedSize: const Size(100, 500),
          );
        }
        expect(image.longImageErrorSamples, 5);
        // EMA should be some positive value
        expect(image.longImageErrorEma, greaterThan(0));
        expect(image.longImageErrorEma, lessThanOrEqualTo(1.0));
      });
    });

    group('resolveWarmupBudget', () {
      test('returns base budget with no source', () {
        final budget = coordinator.resolveWarmupBudget(
          baseProbeCount: 8,
          baseDuration: const Duration(milliseconds: 260),
        );
        expect(budget.probeCount, greaterThanOrEqualTo(8));
        expect(
          budget.maxDuration.inMilliseconds,
          greaterThanOrEqualTo(260),
        );
        expect(
          budget.perProbeTimeout.inMilliseconds,
          greaterThan(0),
        );
      });

      test('boosts budget when long image errors are high', () {
        // Simulate high error rate
        image.longImageErrorSamples = 10;
        image.longImageErrorEma = 0.5;

        final budget = coordinator.resolveWarmupBudget(
          baseProbeCount: 8,
          baseDuration: const Duration(milliseconds: 260),
        );
        // Should boost probe count and duration
        expect(budget.probeCount, greaterThan(8));
        expect(
          budget.maxDuration.inMilliseconds,
          greaterThan(260),
        );
      });
    });

    group('recordProbeSuccess / recordProbeFailure', () {
      test('success/failure do not throw with null source', () {
        // Should be no-ops, not throw
        coordinator.recordProbeSuccess(null);
        coordinator.recordProbeFailure(
          ReaderImageWarmupFailureKind.timeout,
          null,
        );
      });
    });

    group('dispose', () {
      test('cancels snapshot persist timer', () {
        coordinator.schedulePersistSnapshot();
        expect(image.snapshotPersistTimer, isNotNull);
        coordinator.dispose();
        expect(image.snapshotPersistTimer, isNull);
      });
    });

    group('ensureCookieHeaderCached', () {
      test('does nothing with null source', () async {
        // resolveCurrentSource returns null
        await coordinator.ensureCookieHeaderCached(
          const ReaderImageRequest(
            raw: 'https://example.com/img.jpg',
            url: 'https://example.com/img.jpg',
          ),
        );
        expect(image.cookieHeaderByHost, isEmpty);
      });
    });
  });
}

