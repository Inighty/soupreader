import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/reader/models/reading_settings.dart';

void main() {
  test('SettingsService book reading settings override and export', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = SettingsService();
    await service.init();

    const global = ReadingSettings(fontSize: 18.0, lineHeight: 1.5);
    await service.saveReadingSettings(global);

    expect(service.hasBookReadingSettings('b1'), false);
    expect(service.getEffectiveReadingSettingsForBook('b1').fontSize, 18.0);

    const book = ReadingSettings(fontSize: 22.0, lineHeight: 1.8);
    await service.saveBookReadingSettings('b1', book);

    expect(service.hasBookReadingSettings('b1'), true);
    expect(service.getEffectiveReadingSettingsForBook('b1').fontSize, 22.0);
    expect(service.getEffectiveReadingSettingsForBook('b2').fontSize, 18.0);

    final exported = service.exportAllBookReadingSettings();
    expect(exported.keys, contains('b1'));
    expect(exported['b1']!.fontSize, 22.0);

    await service.clearBookReadingSettings('b1');
    expect(service.hasBookReadingSettings('b1'), false);
    expect(service.getEffectiveReadingSettingsForBook('b1').fontSize, 18.0);
  });
}

