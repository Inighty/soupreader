import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/features/reader/services/reader_charset_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_reader_charset_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
  });

  tearDownAll(() async {
    try {
      await DatabaseService().close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseService().clearAll();
  });

  test('normalizeCharset 对 legacy 常见别名归一化', () {
    expect(ReaderCharsetService.normalizeCharset('utf8'), 'UTF-8');
    expect(ReaderCharsetService.normalizeCharset(' utf-16le '), 'UTF-16LE');
    expect(ReaderCharsetService.normalizeCharset('unicode'), 'Unicode');
    expect(ReaderCharsetService.normalizeCharset('GB18030'), 'GB18030');
    expect(ReaderCharsetService.normalizeCharset(''), isNull);
  });

  test('set/get/clear 以书籍维度持久化编码', () async {
    final service = ReaderCharsetService(database: DatabaseService());

    expect(service.getBookCharset('book-1'), isNull);

    await service.setBookCharset('book-1', 'gbk');
    expect(service.getBookCharset('book-1'), 'GBK');

    await service.setBookCharset('book-2', 'UTF-16');
    expect(service.getBookCharset('book-1'), 'GBK');
    expect(service.getBookCharset('book-2'), 'UTF-16');

    await service.clearBookCharset('book-1');
    expect(service.getBookCharset('book-1'), isNull);
    expect(service.getBookCharset('book-2'), 'UTF-16');
  });
}
