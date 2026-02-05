import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/colors.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../reader/models/reading_settings.dart';
import 'function_settings_view.dart';
import 'other_hub_view.dart';
import 'other_settings_view.dart';
import 'source_management_view.dart';
import 'theme_settings_view.dart';

/// 设置首页
///
/// 信息架构对标你的示例：
/// 1) 源管理 2) 主题 3) 功能&设置 4) 其它设置 5) 其它
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _readingSettings;

  String _version = '';
  int? _sourceCount;
  ChapterCacheInfo _cacheInfo = const ChapterCacheInfo(bytes: 0, chapters: 0);

  @override
  void initState() {
    super.initState();
    _readingSettings = _settingsService.readingSettings;
    _loadVersion();
    _refreshStats();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '—');
    }
  }

  Future<void> _refreshStats() async {
    final db = DatabaseService();
    final chapterRepo = ChapterRepository(db);

    final sourceCount = db.sourcesBox.length;
    final localBookIds = db.booksBox.values
        .where((b) => b.isLocal)
        .map((b) => b.id)
        .toSet();
    final cacheInfo =
        chapterRepo.getDownloadedCacheInfo(protectBookIds: localBookIds);

    if (!mounted) return;
    setState(() {
      _sourceCount = sourceCount;
      _cacheInfo = cacheInfo;
      _readingSettings = _settingsService.readingSettings;
    });
  }

  String get _appearanceSummary {
    final app = _settingsService.appSettings;
    switch (app.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return '跟随系统';
      case AppAppearanceMode.light:
        return '浅色';
      case AppAppearanceMode.dark:
        return '深色';
    }
  }

  String get _themeSummary {
    final themeIndex = _readingSettings.themeIndex;
    final themeName = (themeIndex >= 0 &&
            themeIndex < AppColors.readingThemes.length)
        ? AppColors.readingThemes[themeIndex].name
        : AppColors.readingThemes.first.name;
    return '$_appearanceSummary · $themeName';
  }

  String get _readingSummary {
    final fontSize = _readingSettings.fontSize.toInt();
    final lineHeight = _readingSettings.lineHeight.toStringAsFixed(1);
    final themeIndex = _readingSettings.themeIndex;
    final themeName = (themeIndex >= 0 &&
            themeIndex < AppColors.readingThemes.length)
        ? AppColors.readingThemes[themeIndex].name
        : AppColors.readingThemes.first.name;
    return '$fontSize · $themeName · $lineHeight';
  }

  String get _sourceSummary {
    final count = _sourceCount;
    final auto = _settingsService.appSettings.autoUpdateSources ? '自动更新开' : '自动更新关';
    if (count == null) return auto;
    return '$count 个 · $auto';
  }

  String get _otherSettingsSummary {
    final wifi = _settingsService.appSettings.wifiOnlyDownload ? '仅 Wi‑Fi' : '不限网络';
    final cache = FormatUtils.formatBytes(_cacheInfo.bytes);
    return '$wifi · 缓存 $cache';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('分类'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.cloud_fill,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('源管理'),
                  additionalInfo: Text(_sourceSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openSourceManagement,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.paintbrush_fill,
                    CupertinoColors.systemIndigo,
                  ),
                  title: const Text('主题'),
                  additionalInfo: Text(_themeSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openTheme,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.slider_horizontal_3,
                    CupertinoColors.systemBlue,
                  ),
                  title: const Text('功能 & 设置'),
                  additionalInfo: Text(_readingSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openFunctionSettings,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.gear_solid,
                    CupertinoColors.systemOrange,
                  ),
                  title: const Text('其它设置'),
                  additionalInfo: Text(_otherSettingsSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openOtherSettings,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.ellipsis_circle_fill,
                    CupertinoColors.systemGrey,
                  ),
                  title: const Text('其它'),
                  additionalInfo: Text(_version.isEmpty ? '—' : _version),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openOtherHub,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 17),
    );
  }

  Future<void> _openSourceManagement() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const SourceManagementView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openTheme() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ThemeSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openFunctionSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const FunctionSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openOtherSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const OtherSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openOtherHub() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const OtherHubView(),
      ),
    );
    await _refreshStats();
  }
}
