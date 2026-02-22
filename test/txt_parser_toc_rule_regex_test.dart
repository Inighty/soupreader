import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/import/txt_parser.dart';

void main() {
  group('TxtParser tocRuleRegex', () {
    test('指定规则时按规则解析章节标题', () {
      final result = TxtParser.importFromBytes(
        utf8.encode(
          '@@ 序章\n这里是足够长度的正文内容A用于章节解析验证。\n\n'
          '@@ 第一节\n这里是足够长度的正文内容B用于章节解析验证。\n\n'
          '@@ 第二节\n这里是足够长度的正文内容C用于章节解析验证。',
        ),
        'custom_rule.txt',
        tocRuleRegex: r'^\s*@@\s*.+$',
      );

      expect(result.chapters.length, 3);
      expect(result.chapters[0].title, '@@ 序章');
      expect(result.chapters[1].title, '@@ 第一节');
      expect(result.chapters[2].title, '@@ 第二节');
    });

    test('指定规则无匹配时不回退默认自动分章', () {
      final result = TxtParser.importFromBytes(
        utf8.encode(
          '第一章 开始\n正文A\n\n第二章 继续\n正文B',
        ),
        'no_match_rule.txt',
        tocRuleRegex: r'^\s*@@\s*.+$',
      );

      expect(result.chapters, isEmpty);
    });
  });
}
