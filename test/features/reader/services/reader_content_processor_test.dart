import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/services/reader_content_processor.dart';

void main() {
  group('ReaderContentProcessor', () {
    group('formatContentLikeLegado', () {
      test('collapses multiple newlines', () {
        expect(
          ReaderContentProcessor.formatContentLikeLegado('A\n\n\nB'),
          'A\nB',
        );
      });

      test('replaces HTML whitespace entities', () {
        expect(
          ReaderContentProcessor.formatContentLikeLegado('Hello&nbsp;World'),
          'Hello World',
        );
      });

      test('removes zero-width chars', () {
        expect(
          ReaderContentProcessor.formatContentLikeLegado(
            'Hello\u200DWorld',
          ),
          'HelloWorld',
        );
      });

      test('trims full-width spaces from paragraphs', () {
        expect(
          ReaderContentProcessor.formatContentLikeLegado('　　段落内容　'),
          '段落内容',
        );
      });

      test('returns empty for all-whitespace content', () {
        expect(
          ReaderContentProcessor.formatContentLikeLegado('   \n\n  \n  '),
          '',
        );
      });

      test('preserves single line content', () {
        expect(
          ReaderContentProcessor.formatContentLikeLegado('Hello World'),
          'Hello World',
        );
      });
    });

    group('trimParagraph', () {
      test('trims regular spaces', () {
        expect(ReaderContentProcessor.trimParagraph('  hello  '), 'hello');
      });

      test('trims full-width spaces', () {
        expect(ReaderContentProcessor.trimParagraph('　hello　'), 'hello');
      });

      test('trims mixed whitespace', () {
        expect(
          ReaderContentProcessor.trimParagraph('　 \thello\t 　'),
          'hello',
        );
      });

      test('returns empty for empty input', () {
        expect(ReaderContentProcessor.trimParagraph(''), '');
      });

      test('returns empty for only whitespace', () {
        expect(ReaderContentProcessor.trimParagraph('　  　'), '');
      });
    });

    group('removeDuplicateTitle', () {
      test('removes matching first line', () {
        final result = ReaderContentProcessor.removeDuplicateTitle(
          '第一章 开始\n正文内容\n更多内容',
          '第一章 开始',
        );
        expect(result.removed, true);
        expect(result.content, '正文内容\n更多内容');
      });

      test('removes first line containing title', () {
        final result = ReaderContentProcessor.removeDuplicateTitle(
          '【第一章 开始】\n正文内容',
          '第一章 开始',
        );
        expect(result.removed, true);
      });

      test('does not remove when no match', () {
        final result = ReaderContentProcessor.removeDuplicateTitle(
          '正文内容\n更多内容',
          '第一章',
        );
        expect(result.removed, false);
        expect(result.content, '正文内容\n更多内容');
      });

      test('handles empty content', () {
        final result = ReaderContentProcessor.removeDuplicateTitle(
          '',
          '标题',
        );
        expect(result.removed, false);
        expect(result.content, '');
      });
    });

    group('removeRubyTags', () {
      test('removes rt tags', () {
        expect(
          ReaderContentProcessor.removeRubyTags(
            '漢<rt>かん</rt>字<rt>じ</rt>',
          ),
          '漢字',
        );
      });

      test('removes rp tags', () {
        expect(
          ReaderContentProcessor.removeRubyTags(
            '漢<rp>(</rp><rt>かん</rt><rp>)</rp>字',
          ),
          '漢字',
        );
      });

      test('returns unchanged text without ruby tags', () {
        const text = '普通文本内容';
        expect(ReaderContentProcessor.removeRubyTags(text), text);
      });
    });

    group('removeHtmlHeaderTags', () {
      test('removes h1 tags with content', () {
        expect(
          ReaderContentProcessor.removeHtmlHeaderTags(
            '<h1>标题</h1>正文',
          ),
          '正文',
        );
      });

      test('removes h2-h6 tags', () {
        expect(
          ReaderContentProcessor.removeHtmlHeaderTags(
            '<h3 class="chapter">章节</h3>内容',
          ),
          '内容',
        );
      });

      test('removes self-closing header tags', () {
        expect(
          ReaderContentProcessor.removeHtmlHeaderTags(
            'before<h2/>after',
          ),
          'beforeafter',
        );
      });

      test('returns unchanged text without headers', () {
        const text = '<p>段落内容</p>';
        expect(ReaderContentProcessor.removeHtmlHeaderTags(text), text);
      });
    });

    group('reverseContent', () {
      test('reverses ASCII text', () {
        expect(
          ReaderContentProcessor.reverseContent('Hello'),
          'olleH',
        );
      });

      test('reverses CJK text', () {
        expect(
          ReaderContentProcessor.reverseContent('你好世界'),
          '界世好你',
        );
      });

      test('handles empty string', () {
        expect(ReaderContentProcessor.reverseContent(''), '');
      });

      test('handles single character', () {
        expect(ReaderContentProcessor.reverseContent('A'), 'A');
      });
    });
  });
}
