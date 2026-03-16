import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, listEquals;
import 'package:flutter/services.dart';

import '../../../core/config/migration_exclusions.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../models/reading_settings.dart';
import '../services/reader_system_ui_helper.dart';
import '../services/reader_theme_mode_helper.dart';
import '../services/reader_theme_resolver.dart';

/// Manages reading settings updates, brightness sync, and orientation.
///
/// Extracted from `_SimpleReaderViewState` to separate settings logic
/// from the view. Methods that used `setState` now call [onSettingsChanged]
/// so the view can rebuild.
class ReaderSettingsController {
  ReaderSettingsController({
    required this.settingsService,
    required this.brightnessService,
    required this.keepScreenOnService,
    required this.onSettingsChanged,
    required this.isMounted,
  });

  final SettingsService settingsService;
  final ScreenBrightnessService brightnessService;
  final KeepScreenOnService keepScreenOnService;

  /// Called when settings have been updated. The view should
  /// `setState(() { _settings = newSettings; })`.
  final void Function(ReadingSettings newSettings) onSettingsChanged;

  /// Check if the hosting widget is still mounted.
  final bool Function() isMounted;

  Timer? _keepLightTimer;
  List<DeviceOrientation>? _appliedPreferredOrientations;
  ReaderSystemUiConfig? _appliedSystemUiConfig;

  // ── Settings normalization ──

  /// Apply platform-specific exclusions to raw settings.
  ReadingSettings readSettingsWithExclusions(ReadingSettings raw) {
    final normalized = raw.copyWith(
      showBrightnessView: _normalizeBrightnessViewVisibility(
        raw.showBrightnessView,
      ),
    );
    if (!MigrationExclusions.excludeTts) {
      return normalized.sanitize();
    }
    return normalized
        .copyWith(
          clickActions: ClickAction.normalizeConfigForExclusions(
            normalized.clickActions,
            excludeTts: true,
          ),
          volumeKeyPageOnPlay: false,
        )
        .sanitize();
  }

  bool _normalizeBrightnessViewVisibility(bool value) {
    if (kIsWeb) return false;
    return value;
  }

  /// Apply book-specific page animation override.
  ReadingSettings effectiveSettingsWithBookPageAnim({
    required ReadingSettings base,
    required int? bookPageAnimOverride,
  }) {
    if (bookPageAnimOverride == null || bookPageAnimOverride == -1) {
      return base;
    }
    final mode = PageTurnMode.values.firstWhere(
      (m) => m.index == bookPageAnimOverride,
      orElse: () => base.pageTurnMode,
    );
    return base.copyWith(pageTurnMode: mode);
  }

  /// Check if two settings are semantically equivalent.
  bool isSameReadingSettings(ReadingSettings a, ReadingSettings b) {
    return a.toJson().toString() == b.toJson().toString();
  }

  // ── Brightness ──

  /// Sync native brightness to match reading settings.
  Future<void> syncBrightness(
    ReadingSettings oldSettings,
    ReadingSettings newSettings,
  ) async {
    if (oldSettings.useSystemBrightness != newSettings.useSystemBrightness ||
        oldSettings.brightness != newSettings.brightness) {
      if (newSettings.useSystemBrightness) {
        await brightnessService.resetToSystem();
      } else {
        await brightnessService.setBrightness(
          _safeBrightness(newSettings.brightness),
        );
      }
    }
  }

  double safeBrightness(double value, {double fallback = 1.0}) {
    if (value.isNaN || value.isInfinite) return fallback;
    return value.clamp(0.0, 1.0);
  }

  // ── Keep screen on ──

  /// Resolve effective keep-light seconds from settings.
  int effectiveKeepLightSeconds(ReadingSettings settings) {
    if (settings.keepScreenOn) return -1;
    final seconds = settings.keepLightSeconds;
    if (seconds < 0) return -1;
    if (seconds == 0) return 0;
    return seconds;
  }

  /// Sync native keep-screen-on state.
  Future<void> syncKeepScreenOn(ReadingSettings settings) async {
    final keepLightSeconds = effectiveKeepLightSeconds(settings);
    _keepLightTimer?.cancel();
    _keepLightTimer = null;

    if (keepLightSeconds < 0) {
      await keepScreenOnService.enable();
      return;
    }
    if (keepLightSeconds == 0) {
      await keepScreenOnService.disable();
      return;
    }
    await keepScreenOnService.enable();
    _keepLightTimer = Timer(
      Duration(seconds: keepLightSeconds),
      () async {
        _keepLightTimer = null;
        await keepScreenOnService.disable();
      },
    );
  }

  /// Restart keep-screen-on timer.
  void screenOffTimerStart(ReadingSettings settings, {bool force = false}) {
    if (!force && _keepLightTimer != null) return;
    unawaited(syncKeepScreenOn(settings));
  }

  // ── Orientation ──

  /// Apply preferred orientations based on settings.
  Future<void> applyPreferredOrientations(
    ReadingSettings settings, {
    bool force = false,
  }) async {
    final next = ReaderSystemUiHelper.resolvePreferredOrientations(
      settings.screenOrientation,
    );
    if (!force && listEquals(_appliedPreferredOrientations, next)) return;
    _appliedPreferredOrientations = next;
    await SystemChrome.setPreferredOrientations(next);
  }

  /// Restore system UI and orientation to defaults.
  Future<void> restoreSystemUiAndOrientation() async {
    _appliedSystemUiConfig = null;
    _appliedPreferredOrientations = null;
    await SystemChrome.setPreferredOrientations([]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  /// Sync system UI style for menu overlay visibility.
  void syncSystemUiForOverlay({
    required bool showMenu,
    required ReadingSettings settings,
    required Brightness effectiveBrightness,
  }) {
    final config = ReaderSystemUiHelper.resolveSystemUiConfig(
      showMenu: showMenu,
      showStatusBar: settings.showStatusBar,
      hideNavigationBar: settings.hideNavigationBar,
      effectiveBrightness: effectiveBrightness,
    );
    if (config == _appliedSystemUiConfig) return;
    _appliedSystemUiConfig = config;
    ReaderSystemUiHelper.applySystemUiConfig(config);
  }

  // ── Theme normalization ──

  /// Normalize follow-system theme indices for styles that don't have a
  /// matching light/dark pair.
  ReadingSettings? maybeNormalizeFollowSystemReaderThemes({
    required ReadingSettings settings,
    required SettingsService settingsService,
    required List<ReadStyleConfig> activeReadStyleConfigs,
  }) {
    final appSettings = settingsService.appSettings;
    if (appSettings.appearanceMode != AppAppearanceMode.followSystem) {
      return null;
    }
    final styles = activeReadStyleConfigs;
    if (styles.isEmpty) return null;

    int clampIndex(int index) =>
        index.clamp(0, styles.length - 1);

    bool isDarkIndex(int index) =>
        Color(styles[clampIndex(index)].backgroundColor)
            .computeLuminance() < 0.5;

    int? firstLightIndex;
    int? firstDarkIndex;
    for (int i = 0; i < styles.length; i++) {
      if (isDarkIndex(i)) {
        firstDarkIndex ??= i;
      } else {
        firstLightIndex ??= i;
      }
      if (firstLightIndex != null && firstDarkIndex != null) break;
    }

    var modified = false;
    var current = settings;

    final dayIdx = current.themeIndex;
    if (firstLightIndex != null && isDarkIndex(dayIdx)) {
      current = current.copyWith(themeIndex: firstLightIndex);
      modified = true;
    }

    final nightIdx = current.nightThemeIndex;
    if (firstDarkIndex != null && !isDarkIndex(nightIdx)) {
      current = current.copyWith(nightThemeIndex: firstDarkIndex);
      modified = true;
    }

    return modified ? current : null;
  }

  // ── Dispose ──

  void dispose() {
    _keepLightTimer?.cancel();
    _keepLightTimer = null;
  }
}
