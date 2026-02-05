import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/utils/html_text_formatter.dart';

void main() {
  group('HtmlTextFormatter.formatToPlainText', () {
    test('converts common block tags to newlines', () {
      final input = '<div>第一段</div><div>第二段</div>';
      expect(HtmlTextFormatter.formatToPlainText(input), '第一段\n第二段');
    });

    test('handles br/p and normalizes whitespace around newlines', () {
      final input = '<p> A </p><p>&nbsp;B&nbsp;</p><br/>  C';
      expect(HtmlTextFormatter.formatToPlainText(input), 'A\nB\nC');
    });

    test('removes HTML comments', () {
      final input = 'Hello<!-- should be removed -->World';
      expect(HtmlTextFormatter.formatToPlainText(input), 'HelloWorld');
    });

    test('removes common invisible characters and entities', () {
      final input = 'A&thinsp;B\u200C\u200D';
      expect(HtmlTextFormatter.formatToPlainText(input), 'AB');
    });

    test('strips remaining tags but keeps text', () {
      final input = '<span>Text</span><b>Bold</b>';
      expect(HtmlTextFormatter.formatToPlainText(input), 'TextBold');
    });
  });
}

