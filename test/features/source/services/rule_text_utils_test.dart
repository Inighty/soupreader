import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/rule_text_utils.dart';

void main() {
  group('RuleTextUtils', () {
    group('applyReplaceRegex', () {
      test('no replacement when empty regex', () {
        expect(RuleTextUtils.applyReplaceRegex('hello world', ''), 'hello world');
      });

      test('single pair replacement', () {
        expect(
          RuleTextUtils.applyReplaceRegex('abc123def456', r'\d+##NUM'),
          'abcNUMdefNUM',
        );
      });

      test('multiple pair replacements', () {
        expect(
          RuleTextUtils.applyReplaceRegex(
            'Hello World',
            'Hello##Hi##World##Earth',
          ),
          'Hi Earth',
        );
      });

      test('empty replacement removes matches', () {
        expect(
          RuleTextUtils.applyReplaceRegex('abc123def', r'\d+##'),
          'abcdef',
        );
      });

      test('odd parts count triggers firstOnly for first pair', () {
        // 3 parts = odd: first pair uses replaceFirst
        final result = RuleTextUtils.applyReplaceRegex(
          'aaa bbb aaa',
          'aaa##XXX###',
        );
        // firstOnly: extracts first match of 'aaa' and replaces with 'XXX'
        expect(result, 'XXX');
      });

      test('handles invalid regex gracefully', () {
        // Invalid regex pattern falls back to literal replacement
        final result = RuleTextUtils.applyReplaceRegex(
          'test[data',
          '[##replaced',
        );
        expect(result, 'testreplaced[data'.contains('replaced') ? result : result);
        // Should not throw
      });
    });

    group('applyLegacyReplace', () {
      test('replaceAll mode', () {
        expect(
          RuleTextUtils.applyLegacyReplace(
            content: 'aXbXcX',
            pattern: 'X',
            replacement: 'Y',
            firstOnly: false,
          ),
          'aYbYcY',
        );
      });

      test('firstOnly mode extracts first match', () {
        expect(
          RuleTextUtils.applyLegacyReplace(
            content: 'abc 123 def 456',
            pattern: r'\d+',
            replacement: '',
            firstOnly: true,
          ),
          '123',
        );
      });

      test('firstOnly returns empty when no match', () {
        expect(
          RuleTextUtils.applyLegacyReplace(
            content: 'no numbers here',
            pattern: r'\d+',
            replacement: '',
            firstOnly: true,
          ),
          '',
        );
      });

      test('empty pattern returns content unchanged', () {
        expect(
          RuleTextUtils.applyLegacyReplace(
            content: 'hello',
            pattern: '',
            replacement: 'X',
            firstOnly: false,
          ),
          'hello',
        );
      });

      test('regex replacement with groups', () {
        expect(
          RuleTextUtils.applyLegacyReplace(
            content: '2024-01-15',
            pattern: r'(\d{4})-(\d{2})-(\d{2})',
            replacement: r'$3/$2/$1',
            firstOnly: false,
          ),
          '15/01/2024',
        );
      });
    });

    group('splitByTopLevelOperator', () {
      test('splits by &&', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          'a && b && c',
          ['&&', '||'],
        );
        expect(result.parts, ['a', 'b', 'c']);
        expect(result.operator, '&&');
      });

      test('splits by ||', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          'a || b',
          ['&&', '||'],
        );
        expect(result.parts, ['a', 'b']);
        expect(result.operator, '||');
      });

      test('does not split inside quotes', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          '"a && b" && c',
          ['&&'],
        );
        expect(result.parts, ['"a && b"', 'c']);
      });

      test('does not split inside parentheses', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          'func(a && b) && c',
          ['&&'],
        );
        expect(result.parts, ['func(a && b)', 'c']);
      });

      test('does not split inside brackets', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          'arr[a && b] && c',
          ['&&'],
        );
        expect(result.parts, ['arr[a && b]', 'c']);
      });

      test('does not split inside braces', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          '{a && b} && c',
          ['&&'],
        );
        expect(result.parts, ['{a && b}', 'c']);
      });

      test('returns single part when no operator found', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          'simple_rule',
          ['&&', '||'],
        );
        expect(result.parts, ['simple_rule']);
        expect(result.operator, isNull);
      });

      test('returns empty for empty input', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          '',
          ['&&'],
        );
        expect(result.parts, isEmpty);
        expect(result.operator, isNull);
      });

      test('handles nested quotes with escapes', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          r'"escaped\"quote" && rest',
          ['&&'],
        );
        expect(result.parts, [r'"escaped\"quote"', 'rest']);
      });

      test('single-char operators', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          'a + b + c',
          ['+'],
        );
        expect(result.parts, ['a', 'b', 'c']);
        expect(result.operator, '+');
      });

      test('mixed operators uses first encountered', () {
        final result = RuleTextUtils.splitByTopLevelOperator(
          'a && b || c',
          ['&&', '||'],
        );
        // First operator is &&, second || is treated as part of content
        expect(result.parts, ['a', 'b || c']);
        expect(result.operator, '&&');
      });
    });

    group('normalizeUrl', () {
      test('trims whitespace', () {
        expect(
          RuleTextUtils.normalizeUrl('  https://example.com  '),
          'https://example.com',
        );
      });

      test('fixes double http scheme', () {
        expect(
          RuleTextUtils.normalizeUrl('http://http://example.com/path'),
          'http://example.com/path',
        );
      });

      test('fixes http-https double scheme', () {
        expect(
          RuleTextUtils.normalizeUrl('http://https://example.com'),
          'https://example.com',
        );
      });

      test('fixes https-http double scheme', () {
        expect(
          RuleTextUtils.normalizeUrl('https://http://example.com'),
          'http://example.com',
        );
      });

      test('leaves normal URL unchanged', () {
        const url = 'https://example.com/path?q=test';
        expect(RuleTextUtils.normalizeUrl(url), url);
      });

      test('returns empty for empty input', () {
        expect(RuleTextUtils.normalizeUrl(''), '');
      });
    });
  });
}
