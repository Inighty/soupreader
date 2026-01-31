import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/theme/colors.dart';

/// 设置页面 - iOS 原生风格
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _darkMode = true;
  bool _autoUpdate = true;
  bool _wifiOnly = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    } catch (e) {
      setState(() {
        _version = '1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
        backgroundColor: Color(0xE6121212),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),

            // 阅读设置
            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.black,
              header: const Text('阅读设置'),
              children: [
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.textformat),
                  title: const Text('阅读偏好'),
                  subtitle: const Text('字体、行距、背景等'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openReadingSettings,
                ),
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.moon),
                  title: const Text('深色模式'),
                  trailing: CupertinoSwitch(
                    value: _darkMode,
                    activeTrackColor: AppColors.accent,
                    onChanged: (value) {
                      setState(() => _darkMode = value);
                    },
                  ),
                ),
              ],
            ),

            // 书源设置
            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.black,
              header: const Text('书源设置'),
              children: [
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.cloud),
                  title: const Text('书源管理'),
                  subtitle: const Text('添加、编辑、删除书源'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {},
                ),
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.arrow_2_circlepath),
                  title: const Text('自动更新书源'),
                  trailing: CupertinoSwitch(
                    value: _autoUpdate,
                    activeTrackColor: AppColors.accent,
                    onChanged: (value) {
                      setState(() => _autoUpdate = value);
                    },
                  ),
                ),
              ],
            ),

            // 缓存与存储
            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.black,
              header: const Text('缓存与存储'),
              children: [
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.wifi),
                  title: const Text('仅WiFi下缓存'),
                  trailing: CupertinoSwitch(
                    value: _wifiOnly,
                    activeTrackColor: AppColors.accent,
                    onChanged: (value) {
                      setState(() => _wifiOnly = value);
                    },
                  ),
                ),
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.folder),
                  title: const Text('缓存管理'),
                  subtitle: const Text('当前缓存：256 MB'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showCacheOptions,
                ),
              ],
            ),

            // 其他
            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.black,
              header: const Text('其他'),
              children: [
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.arrow_down_circle),
                  title: const Text('检查更新'),
                  subtitle: const Text('获取最新开发版'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _checkUpdate,
                ),
                CupertinoListTile(
                  leading:
                      _buildIcon(CupertinoIcons.arrow_up_arrow_down_circle),
                  title: const Text('备份与恢复'),
                  subtitle: const Text('导出/导入数据'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showBackupOptions,
                ),
                CupertinoListTile(
                  leading: _buildIcon(CupertinoIcons.info),
                  title: const Text('关于'),
                  subtitle: Text('SoupReader $_version'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showAbout,
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 18),
    );
  }

  void _openReadingSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // 标题
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '阅读偏好设置',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
            // 主题选择
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '阅读主题',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppColors.readingThemes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final theme = AppColors.readingThemes[index];
                        return GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 80,
                            decoration: BoxDecoration(
                              color: theme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    CupertinoColors.systemGrey.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Aa',
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '字体大小',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  CupertinoSlider(
                    value: 18,
                    min: 12,
                    max: 28,
                    divisions: 8,
                    activeColor: AppColors.accent,
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '行距',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  CupertinoSlider(
                    value: 1.8,
                    min: 1.2,
                    max: 2.5,
                    activeColor: AppColors.accent,
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCacheOptions() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('缓存管理'),
        content: const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('当前缓存：256 MB\n\n清除缓存将删除所有已下载的章节内容，书架和阅读进度不受影响。'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清除缓存'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showBackupOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('备份与恢复'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('导出数据'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导入数据'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('iCloud 同步'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showAbout() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('关于 SoupReader'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
              '版本 $_version\n\n一款简洁优雅的阅读应用\n支持自定义书源，兼容源阅格式\n\n© 2026 SoupReader'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    // 显示加载指示器
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CupertinoActivityIndicator(radius: 14),
      ),
    );

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/Inighty/soupreader/releases/latest',
      );

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载

      if (response.statusCode == 200) {
        final data = response.data;
        final tagName = data['tag_name'];
        final body = data['body'];
        final assets = data['assets'] as List;

        String? downloadUrl;
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.ipa')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        if (downloadUrl != null) {
          _showUpdateDialog(tagName, body ?? '修复了一些问题', downloadUrl);
        } else {
          _showMessage('未找到安装包');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        if (e is DioException && e.response?.statusCode == 404) {
          _showMessage('暂无新版本');
        } else {
          _showMessage('检查更新失败');
        }
      }
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(String tagName, String body, String downloadUrl) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('发现新版本 $tagName'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(body),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('下载更新'),
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}
