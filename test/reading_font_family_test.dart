import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/app/theme/typography.dart';

void main() {
  test('ReadingFontFamily aligns with legado-like system typeface semantics',
      () {
    expect(
      ReadingFontFamily.presets.map((preset) => preset.name).toList(),
      equals(<String>['系统默认', '衬线字体', '无衬线字体', '等宽字体']),
    );
    expect(
      ReadingFontFamily.presets.map((preset) => preset.fontFamily).toList(),
      equals(<String>[
        '',
        'Noto Serif CJK SC',
        'Noto Sans CJK SC',
        'Roboto Mono',
      ]),
    );
    expect(
      ReadingFontFamily.getFontFamilyFallback(1),
      contains('serif'),
    );
    expect(
      ReadingFontFamily.getFontFamilyFallback(2),
      contains('sans-serif'),
    );
    expect(
      ReadingFontFamily.getFontFamilyFallback(3),
      contains('monospace'),
    );
  });

  test('ReadingFontFamily keeps stable index lookup and default fallback', () {
    expect(ReadingFontFamily.getFontFamily(0), '');
    expect(ReadingFontFamily.getFontFamily(1), 'Noto Serif CJK SC');
    expect(ReadingFontFamily.getFontFamily(2), 'Noto Sans CJK SC');
    expect(ReadingFontFamily.getFontFamily(3), 'Roboto Mono');

    expect(ReadingFontFamily.getFontFamily(-1), '');
    expect(ReadingFontFamily.getFontFamily(999), '');
    expect(ReadingFontFamily.getFontName(999), '系统默认');
  });
}
