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
      equals(<String>['', 'serif', 'sans-serif', 'monospace']),
    );
  });

  test('ReadingFontFamily keeps stable index lookup and default fallback', () {
    expect(ReadingFontFamily.getFontFamily(0), '');
    expect(ReadingFontFamily.getFontFamily(1), 'serif');
    expect(ReadingFontFamily.getFontFamily(2), 'sans-serif');
    expect(ReadingFontFamily.getFontFamily(3), 'monospace');

    expect(ReadingFontFamily.getFontFamily(-1), '');
    expect(ReadingFontFamily.getFontFamily(999), '');
    expect(ReadingFontFamily.getFontName(999), '系统默认');
  });
}
