import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/controllers/actions_coordinator.dart';
import 'package:soupreader/features/reader/controllers/reader_state.dart';

void main() {
  group('ActionsCoordinator', () {
    group('WebDavSyncResult', () {
      test('success factory', () {
        const result = WebDavSyncResult(success: true);
        expect(result.success, isTrue);
        expect(result.skipped, isFalse);
        expect(result.errorMessage, isNull);
      });

      test('skipped factory', () {
        const result = WebDavSyncResult(
          success: false,
          skipped: true,
        );
        expect(result.success, isFalse);
        expect(result.skipped, isTrue);
      });

      test('error factory', () {
        const result = WebDavSyncResult(
          success: false,
          errorMessage: 'network error',
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, 'network error');
      });
    });

    group('WebDavPullResult', () {
      test('no data result', () {
        const result = WebDavPullResult(hasData: false);
        expect(result.hasData, isFalse);
        expect(result.targetChapterIndex, 0);
        expect(result.targetChapterProgress, 0.0);
        expect(result.needsConfirmation, isFalse);
      });

      test('data result with confirmation', () {
        const result = WebDavPullResult(
          hasData: true,
          targetChapterIndex: 5,
          targetChapterProgress: 0.75,
          needsConfirmation: true,
          remoteChapterTitle: '第六章',
        );
        expect(result.hasData, isTrue);
        expect(result.targetChapterIndex, 5);
        expect(result.targetChapterProgress, 0.75);
        expect(result.needsConfirmation, isTrue);
        expect(result.remoteChapterTitle, '第六章');
      });
    });

    group('legacyImageStyles', () {
      test('contains expected styles', () {
        expect(
          ActionsCoordinator.legacyImageStyles,
          ['DEFAULT', 'FULL', 'TEXT', 'SINGLE'],
        );
      });
    });

    group('SettingsState toggle tracking', () {
      late SettingsState settings;

      setUp(() {
        settings = SettingsState();
      });

      test('reSegment initial value is false', () {
        expect(settings.reSegment, isFalse);
      });

      test('delRubyTag initial value is false', () {
        expect(settings.delRubyTag, isFalse);
      });

      test('delHTag initial value is false', () {
        expect(settings.delHTag, isFalse);
      });

      test('useReplaceRule initial value is true', () {
        expect(settings.useReplaceRule, isTrue);
      });
    });

    group('ChapterState cache operations', () {
      late ChapterState chapter;

      setUp(() {
        chapter = ChapterState();
      });

      test('replaceStageCache starts empty', () {
        expect(chapter.replaceStageCache, isEmpty);
      });

      test('catalogDisplayTitleCache starts empty', () {
        expect(chapter.catalogDisplayTitleCache, isEmpty);
      });

      test('contentInFlight starts empty', () {
        expect(chapter.contentInFlight, isEmpty);
      });

      test('sameTitleRemovedById starts empty', () {
        expect(chapter.sameTitleRemovedById, isEmpty);
      });

      test('clearing caches works', () {
        chapter.replaceStageCache['a'] = null as dynamic;
        chapter.catalogDisplayTitleCache['b'] = 'title';
        chapter.contentInFlight['c'] = Future.value('');

        chapter.replaceStageCache.clear();
        chapter.catalogDisplayTitleCache.clear();
        chapter.contentInFlight.clear();

        expect(chapter.replaceStageCache, isEmpty);
        expect(chapter.catalogDisplayTitleCache, isEmpty);
        expect(chapter.contentInFlight, isEmpty);
      });
    });

    group('ImageCacheState', () {
      late ImageCacheState image;

      setUp(() {
        image = ImageCacheState();
      });

      test('initial sourceUrl is null', () {
        expect(image.sourceUrl, isNull);
      });

      test('initial bookAuthor is empty', () {
        expect(image.bookAuthor, isEmpty);
      });

      test('longImageErrorEma starts at 0', () {
        expect(image.longImageErrorEma, 0.0);
      });

      test('longImageErrorSamples starts at 0', () {
        expect(image.longImageErrorSamples, 0);
      });

      test('cookie header cache starts empty', () {
        expect(image.cookieHeaderByHost, isEmpty);
      });

      test('warmup in-flight set starts empty', () {
        expect(image.warmupInFlight, isEmpty);
      });

      test('book cache keys starts empty', () {
        expect(image.bookCacheKeys, isEmpty);
      });
    });
  });
}
