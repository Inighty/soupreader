import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/core/services/settings_service.dart';

void main() {
  test('AppSettings JSON roundtrip', () {
    const settings = AppSettings(
      appearanceMode: AppAppearanceMode.dark,
      wifiOnlyDownload: false,
      autoUpdateSources: false,
      bookshelfViewMode: BookshelfViewMode.list,
      bookshelfSortMode: BookshelfSortMode.title,
    );

    final decoded = AppSettings.fromJson(settings.toJson());
    expect(decoded.appearanceMode, AppAppearanceMode.dark);
    expect(decoded.wifiOnlyDownload, false);
    expect(decoded.autoUpdateSources, false);
    expect(decoded.bookshelfViewMode, BookshelfViewMode.list);
    expect(decoded.bookshelfSortMode, BookshelfSortMode.title);
  });

  test('SettingsService persists app settings', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SettingsService();
    await service.init();

    expect(service.appSettings.appearanceMode, AppAppearanceMode.followSystem);

    await service.saveAppSettings(
      service.appSettings.copyWith(
        appearanceMode: AppAppearanceMode.light,
        wifiOnlyDownload: false,
      ),
    );

    // 重新 init，模拟冷启动读取
    await service.init();
    expect(service.appSettings.appearanceMode, AppAppearanceMode.light);
    expect(service.appSettings.wifiOnlyDownload, false);
  });
}

