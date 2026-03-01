import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import 'reading_other_settings_view.dart';
import 'reading_page_settings_view.dart';
import 'reading_status_action_settings_view.dart';

class ReadingBehaviorSettingsHubView extends StatelessWidget {
  const ReadingBehaviorSettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return AppCupertinoPageScaffold(
      title: '设置（行为）',
      child: AppListView(
        children: [
          AppListSection(
            header: Text(
              '阅读行为与操作',
              style: TextStyle(
                color: ReaderSettingsTokens.titleColor(isDark: isDark),
                fontSize: ReaderSettingsTokens.sectionTitleSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              _buildItem(
                context: context,
                leading: CupertinoIcons.arrow_left_right_square,
                title: '翻页与按键',
                description: '阈值/音量键/滚轮/长按',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const ReadingPageSettingsView(),
                  ),
                ),
              ),
              _buildItem(
                context: context,
                leading: CupertinoIcons.brightness,
                title: '状态栏与操作',
                description: '状态栏/导航栏/亮度条/点击',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) =>
                        const ReadingStatusActionSettingsView(),
                  ),
                ),
              ),
              _buildItem(
                context: context,
                leading: CupertinoIcons.gear,
                title: '其他阅读行为',
                description: '方向/返回键/常亮/繁简/净化',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const ReadingOtherSettingsView(),
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

  Widget _buildItem({
    required BuildContext context,
    required IconData leading,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return AppListTile(
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
        description.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ReaderSettingsTokens.rowMetaSize,
          color: ReaderSettingsTokens.rowMetaColor(isDark: isDark),
        ),
      ),
      onTap: onTap,
    );
  }
}
