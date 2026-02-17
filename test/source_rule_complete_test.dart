import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/source_rule_complete.dart';

void main() {
  group('SourceRuleComplete', () {
    test('文字规则自动补全为 @text', () {
      final rule = SourceRuleComplete.autoComplete('div.title&&span');
      expect(rule, 'div.title@text&&span@text');
    });

    test('链接规则自动补全为 @href', () {
      final rule = SourceRuleComplete.autoComplete(
        'a.item',
        type: 2,
      );
      expect(rule, 'a.item@href');
    });

    test('图片规则自动补全为 @src', () {
      final rule = SourceRuleComplete.autoComplete(
        'img.cover',
        type: 3,
      );
      expect(rule, 'img.cover@src');
    });

    test('xpath 规则使用 //text()', () {
      final rule = SourceRuleComplete.autoComplete('//div/a', type: 1);
      expect(rule, '//div/a//text()');
    });

    test('复杂规则（@js）不补全', () {
      final rule = SourceRuleComplete.autoComplete('@js:result.name');
      expect(rule, '@js:result.name');
    });

    test('preRule 为复杂规则时不补全', () {
      final rule = SourceRuleComplete.autoComplete(
        'a',
        preRule: '@js:list',
      );
      expect(rule, 'a');
    });
  });
}
