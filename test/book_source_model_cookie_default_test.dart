import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';

void main() {
  group('BookSource enabledCookieJar legacy defaults', () {
    test('constructor default should be false', () {
      const source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: '示例源',
      );

      expect(source.enabledCookieJar, isFalse);
    });

    test('fromJson missing enabledCookieJar should fallback to false', () {
      final source = BookSource.fromJson(const <String, dynamic>{
        'bookSourceUrl': 'https://example.com',
        'bookSourceName': '示例源',
      });

      expect(source.enabledCookieJar, isFalse);
    });

    test('fromJson explicit enabledCookieJar keeps true', () {
      final source = BookSource.fromJson(const <String, dynamic>{
        'bookSourceUrl': 'https://example.com',
        'bookSourceName': '示例源',
        'enabledCookieJar': true,
      });

      expect(source.enabledCookieJar, isTrue);
    });
  });
}
