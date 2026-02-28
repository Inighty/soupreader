import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import 'reading_behavior_settings_hub_view.dart';
import 'reading_interface_settings_hub_view.dart';

class GlobalReadingSettingsView extends StatelessWidget {
  const GlobalReadingSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return AppCupertinoPageScaffold(
      title: '阅读器配置',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: _sectionHeader(
              title: '入口与阅读页保持一致',
              isDark: isDark,
            ),
            children: [
              _buildItem(
                isDark: isDark,
                leading: CupertinoIcons.paintbrush,
                title: '界面（样式）',
                description: '主题/字体/排版/页眉页脚',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) =>
                        const ReadingInterfaceSettingsHubView(),
                  ),
                ),
              ),
              _buildItem(
                isDark: isDark,
                leading: CupertinoIcons.slider_horizontal_3,
                title: '设置（行为）',
                description: '翻页/点击/状态栏/其他',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) =>
                        const ReadingBehaviorSettingsHubView(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Text _sectionHeader({
    required String title,
    required bool isDark,
  }) {
    return Text(
      title,
      style: TextStyle(
        color: ReaderSettingsTokens.titleColor(isDark: isDark),
        fontSize: ReaderSettingsTokens.sectionTitleSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildItem({
    required bool isDark,
    required IconData leading,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile.notched(
      leading: Icon(
        leading,
        size: 20,
        color: ReaderSettingsTokens.rowMetaColor(isDark: isDark),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
          fontSize: ReaderSettingsTokens.rowTitleSize,
        ),
      ),
      additionalInfo: Text(
        description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ReaderSettingsTokens.rowMetaColor(isDark: isDark),
          fontSize: ReaderSettingsTokens.rowMetaSize,
        ),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}
