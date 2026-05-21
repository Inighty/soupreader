import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_sheet_header.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../models/reading_settings.dart';
import 'reader_quick_settings/reader_quick_settings_shared.dart';

/// 阅读器「信息栏」快捷设置面板。
///
/// 对应阅读器底部菜单「界面 → 信息栏」chip，承载页眉/页脚显示开关与
/// 状态栏元素（时间/进度/电量）的快速切换。
class ReaderInfoBarQuickSheet extends StatefulWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const ReaderInfoBarQuickSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<ReaderInfoBarQuickSheet> createState() =>
      _ReaderInfoBarQuickSheetState();
}

class _ReaderInfoBarQuickSheetState extends State<ReaderInfoBarQuickSheet> {
  late ReadingSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
  }

  void _apply(ReadingSettings next) {
    setState(() => _draft = next);
    widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetPanel(
      contentPadding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHeader(title: '信息栏'),
            ReaderQuickSettingsSection(
              title: '页眉页脚',
              child: ReaderQuickSettingsSwitchGroup(
                rows: [
                  ReaderQuickSettingsSwitchRowData(
                    label: '隐藏页眉',
                    value: _draft.hideHeader,
                    onChanged: (v) =>
                        _apply(_draft.copyWith(hideHeader: v)),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '隐藏页脚',
                    value: _draft.hideFooter,
                    onChanged: (v) =>
                        _apply(_draft.copyWith(hideFooter: v)),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '页眉分割线',
                    value: _draft.showHeaderLine,
                    onChanged: (v) =>
                        _apply(_draft.copyWith(showHeaderLine: v)),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '页脚分割线',
                    value: _draft.showFooterLine,
                    onChanged: (v) =>
                        _apply(_draft.copyWith(showFooterLine: v)),
                  ),
                ],
              ),
            ),
            ReaderQuickSettingsSection(
              title: '状态栏',
              child: ReaderQuickSettingsSwitchGroup(
                rows: [
                  ReaderQuickSettingsSwitchRowData(
                    label: '显示状态栏',
                    value: _draft.showStatusBar,
                    onChanged: (v) =>
                        _apply(_draft.copyWith(showStatusBar: v)),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '显示时间',
                    value: _draft.showTime,
                    onChanged: (v) => _apply(_draft.copyWith(showTime: v)),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '显示进度',
                    value: _draft.showProgress,
                    onChanged: (v) =>
                        _apply(_draft.copyWith(showProgress: v)),
                  ),
                  ReaderQuickSettingsSwitchRowData(
                    label: '显示电量',
                    value: _draft.showBattery,
                    onChanged: (v) =>
                        _apply(_draft.copyWith(showBattery: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
