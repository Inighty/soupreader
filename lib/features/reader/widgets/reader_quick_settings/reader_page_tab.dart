import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../../models/reading_settings.dart';
import 'reader_quick_settings_shared.dart';

bool get _supportsVolumeKeyPaging =>
    defaultTargetPlatform != TargetPlatform.iOS;

class ReaderPageTab extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const ReaderPageTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modes = PageTurnModeUi.values(current: settings.pageTurnMode);
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        ReaderQuickSettingsSection(
          title: '翻页模式',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final mode in modes)
                ReaderQuickSettingsModeChip(
                  label: mode.name,
                  selected: settings.pageTurnMode == mode,
                  disabled: PageTurnModeUi.isHidden(mode),
                  onTap: () {
                    if (PageTurnModeUi.isHidden(mode)) return;
                    onSettingsChanged(settings.copyWith(pageTurnMode: mode));
                  },
                ),
            ],
          ),
        ),
        if (_supportsVolumeKeyPaging)
          ReaderQuickSettingsSection(
            title: '按键',
            child: ReaderQuickSettingsSwitchGroup(
              rows: [
                ReaderQuickSettingsSwitchRowData(
                  label: '音量键翻页',
                  value: settings.volumeKeyPage,
                  onChanged: (v) => onSettingsChanged(
                    settings.copyWith(volumeKeyPage: v),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
      ],
    );
  }
}
