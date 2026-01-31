import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
            icon: Icons.backup,
            title: '备份与恢复',
            subtitle: '导出/导入数据',
            onTap: _showBackupOptions,
          ),
          _buildListTile(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: 'SoupReader v1.0.0',
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
              Text('阅读偏好设置', style: Theme.of(context).textTheme.titleLarge),
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
                              style: TextStyle(color: theme.text, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 更多设置项...
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cacheSize = '0 MB';
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
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
                // TODO: 导出数据
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入数据'),
              subtitle: const Text('从备份文件恢复'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 导入数据
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('云同步'),
              subtitle: const Text('使用iCloud同步数据'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 云同步
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
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 SoupReader',
      children: [
        const SizedBox(height: 16),
        const Text('一款简洁优雅的阅读应用'),
        const SizedBox(height: 8),
        const Text('支持自定义书源，兼容源阅格式'),
      ],
    );
  }
}
