import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import 'reading_behavior_settings_hub_view.dart';
import 'reading_interface_settings_hub_view.dart';

class GlobalReadingSettingsView extends StatelessWidget {
  const GlobalReadingSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '阅读（全局默认）',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('入口与阅读页保持一致'),
            children: [
              CupertinoListTile.notched(
                title: const Text('界面（样式）'),
                additionalInfo: const Text('主题 / 字体 / 排版 / 页眉页脚'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) =>
                        const ReadingInterfaceSettingsHubView(),
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('设置（行为）'),
                additionalInfo: const Text('翻页 / 点击 / 状态栏 / 其他'),
                trailing: const CupertinoListTileChevron(),
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
}
