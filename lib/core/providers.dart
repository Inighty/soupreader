import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reader/models/reading_settings.dart';
import 'database/database_service.dart';
import 'models/app_settings.dart';
import 'services/backup_restore_ignore_service.dart';
import 'services/backup_service.dart';
import 'services/exception_log_service.dart';
import 'services/keep_screen_on_service.dart';
import 'services/screen_brightness_service.dart';
import 'services/settings_service.dart';
import 'services/webdav_service.dart';
import 'utils/chinese_script_converter.dart';

/// Centralized Riverpod provider definitions for core services.
///
/// These providers wrap the existing singleton instances so that:
/// 1. All feature code can obtain dependencies through a single mechanism.
/// 2. In tests, providers can be overridden with fakes / mocks via
///    [ProviderScope.overrides].
/// 3. The dependency graph is explicit and traceable.
///
/// **Migration note**: The underlying services still use the static-singleton
/// pattern internally. These providers simply expose the existing instances
/// through Riverpod. A future iteration can remove the static singletons
/// once all consumers have been migrated.

// ─── Database ───────────────────────────────────────────────────────────────

/// Provides the global [DatabaseService] instance.
final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

// ─── Settings ───────────────────────────────────────────────────────────────

/// Provides the global [SettingsService] instance.
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(),
);

/// Exposes [ReadingSettings] as a reactive stream.
///
/// Widgets that only care about reading settings can `ref.watch` this
/// provider instead of the full [SettingsService], enabling fine-grained
/// rebuilds. The underlying [ValueNotifier] is bridged via a
/// manual listener that invalidates the provider.
final readingSettingsProvider = Provider<ReadingSettings>((ref) {
  final service = ref.watch(settingsServiceProvider);
  final notifier = service.readingSettingsNotifierState;
  // Invalidate (re-read) whenever the notifier fires.
  void onChange() => ref.invalidateSelf();
  notifier.addListener(onChange);
  ref.onDispose(() => notifier.removeListener(onChange));
  return notifier.value;
});

/// Exposes [AppSettings] as a reactive stream.
final appSettingsProvider = Provider<AppSettings>((ref) {
  final service = ref.watch(settingsServiceProvider);
  final notifier = service.appSettingsNotifierState;
  void onChange() => ref.invalidateSelf();
  notifier.addListener(onChange);
  ref.onDispose(() => notifier.removeListener(onChange));
  return notifier.value;
});

// ─── Exception logging ──────────────────────────────────────────────────────

/// Provides the global [ExceptionLogService] instance.
final exceptionLogServiceProvider = Provider<ExceptionLogService>(
  (ref) => ExceptionLogService(),
);

// ─── Screen / Brightness ────────────────────────────────────────────────────

/// Provides the global [ScreenBrightnessService] instance.
final screenBrightnessServiceProvider = Provider<ScreenBrightnessService>(
  (ref) => ScreenBrightnessService.instance,
);

/// Provides the global [KeepScreenOnService] instance.
final keepScreenOnServiceProvider = Provider<KeepScreenOnService>(
  (ref) => KeepScreenOnService.instance,
);

// ─── Backup / WebDAV ────────────────────────────────────────────────────────

/// Provides the global [BackupService] instance.
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(),
);

/// Provides the global [BackupRestoreIgnoreService] instance.
final backupRestoreIgnoreServiceProvider =
    Provider<BackupRestoreIgnoreService>(
  (ref) => BackupRestoreIgnoreService(),
);

/// Provides the global [WebDavService] instance.
final webDavServiceProvider = Provider<WebDavService>(
  (ref) => WebDavService(),
);

// ─── Utils ──────────────────────────────────────────────────────────────────

/// Provides the global [ChineseScriptConverter] instance.
final chineseScriptConverterProvider = Provider<ChineseScriptConverter>(
  (ref) => ChineseScriptConverter.instance,
);
