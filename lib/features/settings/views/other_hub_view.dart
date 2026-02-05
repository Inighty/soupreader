import 'package:flutter/cupertino.dart';

import 'about_settings_view.dart';
import 'settings_placeholders.dart';

class OtherHubView extends StatelessWidget {
  const OtherHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('其它'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('其它'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('分享'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '分享暂未实现（可考虑接入 share_plus）',
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('好评支持'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '好评支持暂未实现',
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('关于我们'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const AboutSettingsView(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

