import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/source/services/source_login_url_resolver.dart';

void main() {
  test('returns empty when loginUrl is blank', () {
    final url = SourceLoginUrlResolver.resolve(
      baseUrl: 'https://www.example.com/book',
      loginUrl: '   ',
    );

    expect(url, isEmpty);
  });

  test('keeps absolute loginUrl', () {
    final url = SourceLoginUrlResolver.resolve(
      baseUrl: 'https://www.example.com/book',
      loginUrl: 'https://auth.example.com/login',
    );

    expect(url, 'https://auth.example.com/login');
  });

  test('resolves root relative loginUrl with source host', () {
    final url = SourceLoginUrlResolver.resolve(
      baseUrl: 'https://www.example.com/path/book.json',
      loginUrl: '/login',
    );

    expect(url, 'https://www.example.com/login');
  });

  test('resolves protocol-relative loginUrl by source scheme', () {
    final url = SourceLoginUrlResolver.resolve(
      baseUrl: 'https://www.example.com/path/book.json',
      loginUrl: '//auth.example.com/login',
    );

    expect(url, 'https://auth.example.com/login');
  });

  test('supports source key with extra suffix after comma', () {
    final url = SourceLoginUrlResolver.resolve(
      baseUrl: 'https://www.example.com/path/book.json,tag',
      loginUrl: '/login',
    );

    expect(url, 'https://www.example.com/login');
  });

  test('returns empty when loginUrl is javascript expression', () {
    final url = SourceLoginUrlResolver.resolve(
      baseUrl: 'https://www.example.com/path/book.json',
      loginUrl: 'javascript:alert(1)',
    );

    expect(url, isEmpty);
  });
}
