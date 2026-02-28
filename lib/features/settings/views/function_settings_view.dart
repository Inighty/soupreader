import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../bookshelf/views/reading_history_view.dart';
import 'backup_settings_view.dart';
import 'global_reading_settings_view.dart';
import 'other_settings_view.dart';
import 'settings_placeholders.dart';
import 'settings_ui_tokens.dart';

class FunctionSettingsView extends StatelessWidget {
  const FunctionSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return AppCupertinoPageScaffold(
      title: '功能 & 设置',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: _sectionHeader('核心', isDark: isDark),
            children: [
              _buildItem(
                isDark: isDark,
                leading: CupertinoIcons.arrow_2_circlepath,
                title: '备份/同步',
                description: '导入/导出',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const BackupSettingsView(),
                  ),
                ),
              ),
              _buildItem(
                isDark: isDark,
                leading: CupertinoIcons.book_circle,
                title: '阅读设置',
                description: '全局默认',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const GlobalReadingSettingsView(),
                  ),
                ),
              ),
              _buildItem(
                isDark: isDark,
                leading: CupertinoIcons.clock,
                title: '阅读记录',
                description: '历史列表',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const ReadingHistoryView(),
                  ),
                ),
              ),
              _buildItem(
                isDark: isDark,
                leading: CupertinoIcons.arrow_right_arrow_left,
                title: '隔空阅读',
                description: SettingsUiTokens.plannedLabel,
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '隔空阅读（接力/Handoff）暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: _sectionHeader('更多', isDark: isDark),
            children: [
              _buildItem(
                isDark: isDark,
                leading: CupertinoIcons.settings,
                title: '其它设置',
                description: '详细配置',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const OtherSettingsView(),
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

  Text _sectionHeader(String title, {required bool isDark}) {
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
