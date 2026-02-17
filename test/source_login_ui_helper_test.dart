import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/source/services/source_login_ui_helper.dart';

void main() {
  test('parseRows parses text/password/button rows', () {
    final rows = SourceLoginUiHelper.parseRows(
      '[{"name":"账号","type":"text"},{"name":"密码","type":"password"},{"name":"注册","type":"button","action":"https://a.com"}]',
    );

    expect(rows.length, 3);
    expect(rows[0].name, '账号');
    expect(rows[0].type, 'text');
    expect(rows[1].isPassword, isTrue);
    expect(rows[2].isButton, isTrue);
    expect(rows[2].action, 'https://a.com');
  });

  test('parseRows skips invalid rows and normalizes unknown type to text', () {
    final rows = SourceLoginUiHelper.parseRows(
      '[{"name":"  ","type":"button"},{"name":"token","type":"unknown"}]',
    );

    expect(rows.length, 1);
    expect(rows.first.name, 'token');
    expect(rows.first.type, 'text');
  });

  test('hasLoginUi only returns true when rows are parsed', () {
    expect(SourceLoginUiHelper.hasLoginUi(null), isFalse);
    expect(SourceLoginUiHelper.hasLoginUi('[]'), isFalse);
    expect(
      SourceLoginUiHelper.hasLoginUi('[{"name":"账号","type":"text"}]'),
      isTrue,
    );
  });

  test('isAbsUrl only accepts http and https', () {
    expect(SourceLoginUiHelper.isAbsUrl('https://a.com'), isTrue);
    expect(SourceLoginUiHelper.isAbsUrl('http://a.com'), isTrue);
    expect(SourceLoginUiHelper.isAbsUrl('/login'), isFalse);
    expect(SourceLoginUiHelper.isAbsUrl('javascript:alert(1)'), isFalse);
  });
}
