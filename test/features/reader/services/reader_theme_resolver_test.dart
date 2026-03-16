import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/services/reader_theme_mode_helper.dart';
import 'package:soupreader/features/reader/services/reader_theme_resolver.dart';

void main() {
  group('ReaderThemeResolver', () {
    late ReaderThemeResolver resolver;

    setUp(() {
      resolver = ReaderThemeResolver(
        settings: const ReadingSettings(),
        themeMode: ReaderThemeMode.day,
        readStyleConfigs: const [
          ReadStyleConfig(
            name: 'Light',
            backgroundColor: 0xFFFEFEFE,
            textColor: 0xFF212121,
          ),
          ReadStyleConfig(
            name: 'Dark',
            backgroundColor: 0xFF1A1A1A,
            textColor: 0xFFE0E0E0,
          ),
        ],
      );
    });

    group('activeConfigs', () {
      test('returns provided configs when non-empty', () {
        expect(resolver.activeConfigs.length, 2);
        expect(resolver.activeConfigs[0].name, 'Light');
      });

      test('returns defaults when configs are empty', () {
        final empty = ReaderThemeResolver(
          settings: const ReadingSettings(),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: const [],
        );
        expect(empty.activeConfigs.isNotEmpty, true);
      });
    });

    group('activeStyles', () {
      test('converts configs to ReadingThemeColors', () {
        final styles = resolver.activeStyles;
        expect(styles.length, 2);
        expect(styles[0].background, const Color(0xFFFEFEFE));
        expect(styles[0].text, const Color(0xFF212121));
      });
    });

    group('currentTheme', () {
      test('returns first theme for day mode', () {
        final theme = resolver.currentTheme;
        expect(theme.background, const Color(0xFFFEFEFE));
      });
    });

    group('isDark', () {
      test('light theme is not dark', () {
        expect(resolver.isDark, false);
      });

      test('dark theme is dark', () {
        final dark = ReaderThemeResolver(
          settings: const ReadingSettings(),
          themeMode: ReaderThemeMode.night,
          readStyleConfigs: const [
            ReadStyleConfig(
              name: 'Dark',
              backgroundColor: 0xFF1A1A1A,
              textColor: 0xFFE0E0E0,
            ),
          ],
        );
        expect(dark.isDark, true);
      });
    });

    group('font properties', () {
      test('default font weight is w400', () {
        expect(resolver.fontWeight, FontWeight.w400);
      });

      test('bold setting gives w600', () {
        final bold = ReaderThemeResolver(
          settings: const ReadingSettings(textBold: 1),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: resolver.activeConfigs,
        );
        expect(bold.fontWeight, FontWeight.w600);
      });

      test('thin setting gives w300', () {
        final thin = ReaderThemeResolver(
          settings: const ReadingSettings(textBold: 2),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: resolver.activeConfigs,
        );
        expect(thin.fontWeight, FontWeight.w300);
      });

      test('underline decoration when enabled', () {
        final underline = ReaderThemeResolver(
          settings: const ReadingSettings(underline: true),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: resolver.activeConfigs,
        );
        expect(underline.textDecoration, TextDecoration.underline);
      });

      test('no decoration by default', () {
        expect(resolver.textDecoration, TextDecoration.none);
      });
    });

    group('text alignment', () {
      test('body text justify by default', () {
        expect(resolver.bodyTextAlign, TextAlign.justify);
      });

      test('body text left when justify disabled', () {
        final left = ReaderThemeResolver(
          settings: const ReadingSettings(textFullJustify: false),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: resolver.activeConfigs,
        );
        expect(left.bodyTextAlign, TextAlign.left);
      });

      test('title center when titleMode is 1', () {
        final center = ReaderThemeResolver(
          settings: const ReadingSettings(titleMode: 1),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: resolver.activeConfigs,
        );
        expect(center.titleTextAlign, TextAlign.center);
      });

      test('title left by default', () {
        expect(resolver.titleTextAlign, TextAlign.left);
      });
    });

    group('contentPadding', () {
      test('returns correct EdgeInsets', () {
        final padded = ReaderThemeResolver(
          settings: const ReadingSettings(
            paddingLeft: 10,
            paddingRight: 12,
            paddingTop: 8,
            paddingBottom: 6,
          ),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: resolver.activeConfigs,
        );
        expect(padded.contentPadding.left, 10);
        expect(padded.contentPadding.right, 12);
        expect(padded.contentPadding.top, 8);
        expect(padded.contentPadding.bottom, 6);
      });
    });

    group('custom font', () {
      test('uses custom font family when provided', () {
        final custom = ReaderThemeResolver(
          settings: const ReadingSettings(),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: resolver.activeConfigs,
          customFontFamily: 'MyCustomFont',
        );
        expect(custom.fontFamily, 'MyCustomFont');
        expect(custom.fontFamilyFallback, isNull);
      });

      test('uses font family index when no custom font', () {
        // Default index 0 should give a family or null
        expect(resolver.customFontFamily, isNull);
        // fontFamily depends on ReadingFontFamily implementation
      });
    });

    group('usesImageBackground', () {
      test('color bg is not image background', () {
        expect(resolver.usesImageBackground, false);
      });

      test('asset bg is image background', () {
        final asset = ReaderThemeResolver(
          settings: const ReadingSettings(),
          themeMode: ReaderThemeMode.day,
          readStyleConfigs: const [
            ReadStyleConfig(
              backgroundColor: 0xFFFFFFFF,
              textColor: 0xFF000000,
              bgType: ReadStyleConfig.bgTypeAsset,
              bgStr: 'assets/bg/paper.jpg',
            ),
          ],
        );
        expect(asset.usesImageBackground, true);
      });
    });
  });
}
