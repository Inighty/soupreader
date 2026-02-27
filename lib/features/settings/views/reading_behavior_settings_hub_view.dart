import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import 'reading_other_settings_view.dart';
import 'reading_page_settings_view.dart';
import 'reading_status_action_settings_view.dart';

class ReadingBehaviorSettingsHubView extends StatelessWidget {
  const ReadingBehaviorSettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '设置（行为）',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('阅读行为与操作'),
            children: [
              _buildItem(
                title: '翻页与按键',
                description: '阈值 / 音量键 / 鼠标滚轮 / 长按按键',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const ReadingPageSettingsView(),
                  ),
                ),
              ),
              _buildItem(
                title: '状态栏与操作',
                description: '状态栏/导航栏 / 亮度条 / 点击动作',
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) =>
                        const ReadingStatusActionSettingsView(),
                  ),
                ),
              ),
              _buildItem(
                title: '其他阅读行为',
                description: '方向 / 返回键 / 常亮 / 繁简 / 净化标题',
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
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile.notched(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        description.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel,
        ),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}
