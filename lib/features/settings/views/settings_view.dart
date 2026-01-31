import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/theme/colors.dart';

/// 设置页面
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // 设置状态
  bool _darkMode = true;
  bool _autoUpdate = true;
  bool _wifiOnly = true;
  String _cacheSize = '256 MB';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 阅读设置
          _buildSectionHeader('阅读设置'),
          _buildListTile(
            icon: Icons.text_fields,
            title: '阅读偏好',
            subtitle: '字体、行距、背景等',
            onTap: _openReadingSettings,
          ),
          _buildListTile(
            icon: Icons.brightness_6,
            title: '深色模式',
            trailing: Switch(
              value: _darkMode,
              activeColor: AppColors.accent,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
              },
            ),
          ),

          const Divider(),

          // 书源设置
          _buildSectionHeader('书源设置'),
          _buildListTile(
            icon: Icons.source,
            title: '书源管理',
            subtitle: '添加、编辑、删除书源',
            onTap: () {
              // TODO: 跳转到书源管理
            },
          ),
          _buildListTile(
            icon: Icons.update,
            title: '自动更新书源',
            trailing: Switch(
              value: _autoUpdate,
              activeColor: AppColors.accent,
              onChanged: (value) {
                setState(() {
                  _autoUpdate = value;
                });
              },
            ),
          ),

          const Divider(),

          // 缓存设置
          _buildSectionHeader('缓存与存储'),
          _buildListTile(
            icon: Icons.wifi,
            title: '仅WiFi下缓存',
            trailing: Switch(
              value: _wifiOnly,
              activeColor: AppColors.accent,
              onChanged: (value) {
                setState(() {
                  _wifiOnly = value;
                });
              },
            ),
          ),
          _buildListTile(
            icon: Icons.storage,
            title: '缓存管理',
            subtitle: '当前缓存：$_cacheSize',
            onTap: _showCacheOptions,
          ),
          _buildListTile(
            icon: Icons.folder,
            title: '下载目录',
            subtitle: '/Documents/SoupReader',
            onTap: () {
              // TODO: 选择下载目录
            },
          ),

          const Divider(),

          // 其他设置
          _buildSectionHeader('其他'),
          _buildListTile(
            icon: Icons.system_update,
            title: '检查更新',
            subtitle: '获取最新开发版',
            onTap: _checkUpdate,
          ),
          _buildListTile(
            icon: Icons.backup,
            title: '备份与恢复',
            subtitle: '导出/导入数据',
            onTap: _showBackupOptions,
          ),
          _buildListTile(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: 'SoupReader $_version',
            onTap: _showAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.accent, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _openReadingSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildReadingSettingsSheet(),
    );
  }

  Widget _buildReadingSettingsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                '阅读偏好设置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // 主题选择
              const Text('阅读主题'),
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
                      onTap: () {
                        // TODO: 应用主题
                      },
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: theme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
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
              const Text('字体大小'),
              Slider(
                value: 18,
                min: 12,
                max: 28,
                divisions: 8,
                label: '18',
                onChanged: (value) {},
              ),

              const SizedBox(height: 16),
              const Text('行距'),
              Slider(
                value: 1.8,
                min: 1.2,
                max: 2.5,
                divisions: 13,
                label: '1.8',
                onChanged: (value) {},
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCacheOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('缓存管理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前缓存：$_cacheSize'),
            const SizedBox(height: 16),
            const Text('清除缓存将删除所有已下载的章节内容，书架和阅读进度不受影响。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cacheSize = '0 MB';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('清除缓存'),
          ),
        ],
      ),
    );
  }

  void _showBackupOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('导出数据'),
              subtitle: const Text('导出书架、阅读进度、书源等'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入数据'),
              subtitle: const Text('从备份文件恢复'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('云同步'),
              subtitle: const Text('使用iCloud同步数据'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'SoupReader',
      applicationVersion: _version,
      applicationLegalese: '© 2026 SoupReader',
      children: [
        const SizedBox(height: 16),
        const Text('一款简洁优雅的阅读应用'),
        const SizedBox(height: 8),
        const Text('支持自定义书源，兼容源阅格式'),
      ],
    );
  }

  // 检查更新
  Future<void> _checkUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在检查更新...')),
    );

    try {
      final dio = Dio();
      // 获取 latest release
      final response = await dio.get(
        'https://api.github.com/repos/Inighty/soupreader/releases/latest',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final tagName = data['tag_name'];
        final body = data['body'];
        final assets = data['assets'] as List;

        // 寻找 IPA 下载链接
        String? downloadUrl;
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.ipa')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        if (!mounted) return;

        if (downloadUrl != null) {
          _showUpdateDialog(tagName, body ?? '修复了一些问题', downloadUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到安装包资产')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // 如果是 404 可能是没有 release
        if (e is DioException && e.response?.statusCode == 404) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无新版本')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('检查更新失败: ${e.toString().split('\n').first}')),
          );
        }
      }
    }
  }

  void _showUpdateDialog(String tagName, String body, String downloadUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 $tagName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('下载更新'),
          ),
        ],
      ),
    );
  }
}
