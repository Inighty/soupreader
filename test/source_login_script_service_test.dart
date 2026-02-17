import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';
import 'package:soupreader/features/source/services/source_login_script_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveLoginScript', () {
    test('handles @js prefix', () {
      final js = SourceLoginScriptService.resolveLoginScript(
          '@js: function login(){}');
      expect(js, 'function login(){}');
    });

    test('handles <js> wrapper', () {
      final js = SourceLoginScriptService.resolveLoginScript(
        '<js>\nfunction login(){ return 1; }\n</js>',
      );
      expect(js, 'function login(){ return 1; }');
    });

    test('keeps plain value', () {
      const raw = 'https://example.com/login';
      expect(SourceLoginScriptService.resolveLoginScript(raw), raw);
    });

    test('returns empty on blank input', () {
      expect(SourceLoginScriptService.resolveLoginScript('   '), isEmpty);
      expect(SourceLoginScriptService.resolveLoginScript(null), isEmpty);
    });
  });

  group('java net bridge helpers', () {
    BookSource buildSource(String loginUrl) {
      return BookSource(
        bookSourceUrl: 'https://example.com/source.json',
        bookSourceName: '测试源',
        loginUrl: loginUrl,
        enabledCookieJar: false,
        respondTime: 4000,
      );
    }

    test('prepare script rewrites java.ajax/java.connect with await', () {
      const script = '''
function login() {
  var body = java.ajax("https://api.test/a");
  var res = java.connect("https://api.test/b");
  source.log(body + res.body());
}
''';
      final service = SourceLoginScriptService();
      final prepared = service.debugPrepareScriptForTest(script);

      expect(prepared, contains('async function login('));
      expect(prepared, contains('(await java.ajax("https://api.test/a"))'));
      expect(prepared, contains('(await java.connect("https://api.test/b"))'));
    });

    test('request bridge passes parsed header override', () async {
      Map<String, String>? capturedHeaderOverride;
      final service = SourceLoginScriptService(
        requestExecutor: ({
          required source,
          required requestUrl,
          headerOverride,
        }) async {
          expect(
            requestUrl,
            'https://api.test/login,{"method":"POST","body":{"k":"v"}}',
          );
          capturedHeaderOverride = headerOverride;
          return const ScriptHttpResponse(
            requestUrl: 'https://api.test/login',
            finalUrl: 'https://api.test/login',
            statusCode: 200,
            statusMessage: 'OK',
            headers: <String, String>{},
            body: '{"ok":1}',
          );
        },
      );
      final result = await service.debugRequestForTest(
        source: buildSource(''),
        requestUrl: 'https://api.test/login,{"method":"POST","body":{"k":"v"}}',
        headerRaw: '{"Authorization":"Bearer 1"}',
      );

      expect(result.body, '{"ok":1}');
      expect(capturedHeaderOverride, isNotNull);
      expect(capturedHeaderOverride?['Authorization'], 'Bearer 1');
    });

    test('request bridge falls back to source headers on invalid override',
        () async {
      Map<String, String>? capturedHeaderOverride;
      final service = SourceLoginScriptService(
        requestExecutor: ({
          required source,
          required requestUrl,
          headerOverride,
        }) async {
          capturedHeaderOverride = headerOverride;
          return const ScriptHttpResponse(
            requestUrl: 'https://api.test/connect',
            finalUrl: 'https://api.test/connect?ok=1',
            statusCode: 201,
            statusMessage: 'Created',
            headers: <String, String>{'X-Token': 'abc'},
            body: 'done',
          );
        },
      );
      final result = await service.debugRequestForTest(
        source: buildSource(''),
        requestUrl: 'https://api.test/connect',
        headerRaw: 'not-json',
      );

      expect(result.statusCode, 201);
      expect(result.body, 'done');
      expect(capturedHeaderOverride, isNull);
    });

    test('request bridge returns response fields from executor', () async {
      final service = SourceLoginScriptService(
        requestExecutor: ({
          required source,
          required requestUrl,
          headerOverride,
        }) async {
          return const ScriptHttpResponse(
            requestUrl: 'https://api.test/connect',
            finalUrl: 'https://api.test/connect?ok=1',
            statusCode: 201,
            statusMessage: 'Created',
            headers: <String, String>{'X-Token': 'abc'},
            body: 'done',
          );
        },
      );

      final result = await service.debugRequestForTest(
        source: buildSource(''),
        requestUrl: 'https://api.test/connect',
      );

      expect(result.requestUrl, 'https://api.test/connect');
      expect(result.finalUrl, 'https://api.test/connect?ok=1');
      expect(result.statusCode, 201);
      expect(result.statusMessage, 'Created');
      expect(result.headers['X-Token'], 'abc');
      expect(result.body, 'done');
    });
  });
}
