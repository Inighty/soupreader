import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_image_dimension_utils.dart';

void main() {
  group('ReaderImageDimensionUtils', () {
    group('extractFromTag', () {
      test('returns null for empty tag', () {
        expect(ReaderImageDimensionUtils.extractFromTag(''), isNull);
      });

      test('extracts width and height from attributes', () {
        const tag = '<img src="a.jpg" width="300" height="200">';
        final size = ReaderImageDimensionUtils.extractFromTag(tag);
        expect(size, equals(const Size(300, 200)));
      });

      test('extracts width and height with px suffix', () {
        const tag = '<img src="a.jpg" width="300px" height="200px">';
        final size = ReaderImageDimensionUtils.extractFromTag(tag);
        expect(size, equals(const Size(300, 200)));
      });

      test('extracts from inline style', () {
        const tag =
            '<img src="a.jpg" style="width: 150px; height: 100px;">';
        final size = ReaderImageDimensionUtils.extractFromTag(tag);
        expect(size, equals(const Size(150, 100)));
      });

      test('uses aspect-ratio to derive missing height', () {
        const tag = '<img src="a.jpg" width="400" style="aspect-ratio: 2/1">';
        final size = ReaderImageDimensionUtils.extractFromTag(tag);
        expect(size, isNotNull);
        expect(size!.width, 400.0);
        expect(size.height, 200.0);
      });

      test('uses aspect-ratio to derive missing width', () {
        const tag =
            '<img src="a.jpg" height="200" style="aspect-ratio: 2/1">';
        final size = ReaderImageDimensionUtils.extractFromTag(tag);
        expect(size, isNotNull);
        expect(size!.width, 400.0);
        expect(size.height, 200.0);
      });

      test('returns null when only width is known and no aspect-ratio', () {
        const tag = '<img src="a.jpg" width="300">';
        expect(ReaderImageDimensionUtils.extractFromTag(tag), isNull);
      });

      test('ignores percentage values', () {
        const tag = '<img src="a.jpg" width="100%" height="50%">';
        expect(ReaderImageDimensionUtils.extractFromTag(tag), isNull);
      });
    });

    group('extractFromSrcUrl', () {
      test('extracts from query parameters', () {
        final size = ReaderImageDimensionUtils.extractFromSrcUrl(
          'https://img.example.com/pic.jpg?w=640&h=480',
        );
        expect(size, equals(const Size(640, 480)));
      });

      test('returns null for URL without dimensions', () {
        final size = ReaderImageDimensionUtils.extractFromSrcUrl(
          'https://img.example.com/pic.jpg',
        );
        expect(size, isNull);
      });

      test('returns null for empty string', () {
        expect(
          ReaderImageDimensionUtils.extractFromSrcUrl(''),
          isNull,
        );
      });
    });

    group('parseCssPixelValue', () {
      test('parses integer value', () {
        expect(ReaderImageDimensionUtils.parseCssPixelValue('300'), 300.0);
      });

      test('parses value with px suffix', () {
        expect(ReaderImageDimensionUtils.parseCssPixelValue('300px'), 300.0);
      });

      test('parses decimal value', () {
        expect(
          ReaderImageDimensionUtils.parseCssPixelValue('12.5'),
          12.5,
        );
      });

      test('returns null for percentage', () {
        expect(ReaderImageDimensionUtils.parseCssPixelValue('100%'), isNull);
      });

      test('returns null for empty string', () {
        expect(ReaderImageDimensionUtils.parseCssPixelValue(''), isNull);
      });

      test('returns null for zero', () {
        expect(ReaderImageDimensionUtils.parseCssPixelValue('0'), isNull);
      });

      test('returns null for negative', () {
        expect(ReaderImageDimensionUtils.parseCssPixelValue('-5'), isNull);
      });
    });

    group('parsePositiveDimension', () {
      test('parses from mixed text', () {
        expect(
          ReaderImageDimensionUtils.parsePositiveDimension('abc123def'),
          123.0,
        );
      });

      test('returns null for null', () {
        expect(ReaderImageDimensionUtils.parsePositiveDimension(null), isNull);
      });

      test('returns null for non-numeric text', () {
        expect(
          ReaderImageDimensionUtils.parsePositiveDimension('abc'),
          isNull,
        );
      });
    });
  });
}
