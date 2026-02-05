import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/theme/colors.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../reader/models/reading_settings.dart';
import '../../source/views/source_list_view.dart';
import 'reading_preferences_view.dart';

/// 设置页面 - 纯 iOS 原生风格
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _version = '';
  final SettingsService _settingsService = SettingsService();
  final BackupService _backupService = BackupService();
  late final DatabaseService _db;
  late final ChapterRepository _chapterRepo;
  late ReadingSettings _readingSettings;
  late AppSettings _appSettings;

  int? _sourceCount;
  ChapterCacheInfo _cacheInfo = const ChapterCacheInfo(bytes: 0, chapters: 0);

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _chapterRepo = ChapterRepository(_db);
    _readingSettings = _settingsService.readingSettings;
    _appSettings = _settingsService.appSettings;
    _loadVersion();
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    _refreshStats();
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _appSettings = _settingsService.appSettings;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _version = '1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final followSystem = _appSettings.appearanceMode == AppAppearanceMode.followSystem;
    final effectiveIsDark = followSystem
        ? systemBrightness == Brightness.dark
        : _appSettings.appearanceMode == AppAppearanceMode.dark;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            // 阅读设置
            CupertinoListSection.insetGrouped(
              header: const Text('阅读'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.textformat, CupertinoColors.systemBlue),
                  title: const Text('阅读偏好'),
                  additionalInfo: Text(_readingPreferencesSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openReadingPreferences,
                ),
              ],
            ),

            // 外观
            CupertinoListSection.insetGrouped(
              header: const Text('外观'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.device_phone_portrait,
                    CupertinoColors.systemIndigo,
                  ),
                  title: const Text('跟随系统外观'),
                  trailing: CupertinoSwitch(
                    value: followSystem,
                    onChanged: (value) async {
                      if (value) {
                        await _settingsService.saveAppSettings(
                          _appSettings.copyWith(
                            appearanceMode: AppAppearanceMode.followSystem,
                          ),
                        );
                        return;
                      }

                      // 关闭“跟随系统”时，用当前系统外观作为默认
                      await _settingsService.saveAppSettings(
                        _appSettings.copyWith(
                          appearanceMode: systemBrightness == Brightness.dark
                              ? AppAppearanceMode.dark
                              : AppAppearanceMode.light,
                        ),
                      );
                    },
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.moon_fill,
                    CupertinoColors.systemIndigo,
                  ),
                  title: const Text('深色模式'),
                  trailing: CupertinoSwitch(
                    value: effectiveIsDark,
                    onChanged: followSystem
                        ? null
                        : (value) async {
                            await _settingsService.saveAppSettings(
                              _appSettings.copyWith(
                                appearanceMode: value
                                    ? AppAppearanceMode.dark
                                    : AppAppearanceMode.light,
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),

            // 书架
            CupertinoListSection.insetGrouped(
              header: const Text('书架'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.square_grid_2x2,
                    CupertinoColors.systemOrange,
                  ),
                  title: const Text('显示方式'),
                  additionalInfo: Text(
                    _appSettings.bookshelfViewMode == BookshelfViewMode.grid
                        ? '网格'
                        : '列表',
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickBookshelfViewMode,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.arrow_up_arrow_down,
                    CupertinoColors.systemOrange,
                  ),
                  title: const Text('排序'),
                  additionalInfo: Text(_bookshelfSortLabel),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickBookshelfSortMode,
                ),
              ],
            ),

            // 书源设置
            CupertinoListSection.insetGrouped(
              header: const Text('书源'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.cloud_fill, CupertinoColors.systemCyan),
                  title: const Text('书源管理'),
                  additionalInfo: Text(_sourceCount == null ? '—' : '${_sourceCount!} 个'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openSourceManager,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.arrow_2_circlepath,
                      CupertinoColors.systemGreen),
                  title: const Text('自动更新'),
                  trailing: CupertinoSwitch(
                    value: _appSettings.autoUpdateSources,
                    onChanged: (value) async {
                      await _settingsService.saveAppSettings(
                        _appSettings.copyWith(autoUpdateSources: value),
                      );
                    },
                  ),
                ),
              ],
            ),

            // 存储
            CupertinoListSection.insetGrouped(
              header: const Text('存储'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.wifi, CupertinoColors.systemBlue),
                  title: const Text('仅 Wi-Fi 下载'),
                  trailing: CupertinoSwitch(
                    value: _appSettings.wifiOnlyDownload,
                    onChanged: (value) async {
                      await _settingsService.saveAppSettings(
                        _appSettings.copyWith(wifiOnlyDownload: value),
                      );
                    },
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.trash_fill, CupertinoColors.systemRed),
                  title: const Text('清除缓存'),
                  additionalInfo: Text(
                    _cacheInfo.bytes == 0 ? '0 B' : FormatUtils.formatBytes(_cacheInfo.bytes),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showCacheOptions,
                ),
              ],
            ),

            // 其他
            CupertinoListSection.insetGrouped(
              header: const Text('其他'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.arrow_down_circle_fill,
                      CupertinoColors.systemGreen),
                  title: const Text('检查更新'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _checkUpdate,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.arrow_up_arrow_down,
                      CupertinoColors.systemOrange),
                  title: const Text('备份与恢复'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showBackupOptions,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.info_circle_fill,
                      CupertinoColors.systemGrey),
                  title: const Text('关于'),
                  additionalInfo: Text(_version),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showAbout,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 构建设置项图标盒子 - iOS 风格
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

  String get _readingPreferencesSummary {
    final fontSize = _readingSettings.fontSize.toInt();
    final lineHeight = _readingSettings.lineHeight.toStringAsFixed(1);
    final themeIndex = _readingSettings.themeIndex;
    final themeName = (themeIndex >= 0 && themeIndex < AppColors.readingThemes.length)
        ? AppColors.readingThemes[themeIndex].name
        : AppColors.readingThemes.first.name;
    return '$fontSize · $themeName · $lineHeight';
  }

  Future<void> _openReadingPreferences() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingPreferencesView(),
      ),
    );
    // 返回后刷新一次展示摘要（设置保存由页面内部完成）
    setState(() {
      _readingSettings = _settingsService.readingSettings;
    });
  }

  String get _bookshelfSortLabel {
    switch (_appSettings.bookshelfSortMode) {
      case BookshelfSortMode.recentRead:
        return '最近阅读';
      case BookshelfSortMode.recentAdded:
        return '最近加入';
      case BookshelfSortMode.title:
        return '书名';
      case BookshelfSortMode.author:
        return '作者';
    }
  }

  Future<void> _pickBookshelfViewMode() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('书架显示方式'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              await _settingsService.saveAppSettings(
                _appSettings.copyWith(bookshelfViewMode: BookshelfViewMode.grid),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('网格'),
                if (_appSettings.bookshelfViewMode == BookshelfViewMode.grid) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark,
                      size: 18, color: CupertinoColors.activeBlue),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              await _settingsService.saveAppSettings(
                _appSettings.copyWith(bookshelfViewMode: BookshelfViewMode.list),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('列表'),
                if (_appSettings.bookshelfViewMode == BookshelfViewMode.list) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark,
                      size: 18, color: CupertinoColors.activeBlue),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _pickBookshelfSortMode() async {
    Widget action(BookshelfSortMode mode, String label) {
      final selected = _appSettings.bookshelfSortMode == mode;
      return CupertinoActionSheetAction(
        onPressed: () async {
          await _settingsService.saveAppSettings(
            _appSettings.copyWith(bookshelfSortMode: mode),
          );
          if (mounted) Navigator.pop(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.checkmark,
                  size: 18, color: CupertinoColors.activeBlue),
            ],
          ],
        ),
      );
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('书架排序'),
        actions: [
          action(BookshelfSortMode.recentRead, '最近阅读'),
          action(BookshelfSortMode.recentAdded, '最近加入'),
          action(BookshelfSortMode.title, '书名'),
          action(BookshelfSortMode.author, '作者'),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _openSourceManager() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const SourceListView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _refreshStats() async {
    // 书源数量
    final sourceCount = _db.sourcesBox.length;

    // 缓存：保护本地导入书籍的章节内容（它们就是书本身，不应被“清除缓存”删掉）
    final localBookIds = _db.booksBox.values
        .where((b) => b.isLocal)
        .map((b) => b.id)
        .toSet();
    final cacheInfo =
        _chapterRepo.getDownloadedCacheInfo(protectBookIds: localBookIds);

    if (!mounted) return;
    setState(() {
      _sourceCount = sourceCount;
      _cacheInfo = cacheInfo;
    });
  }

  void _showCacheOptions() {
    final sizeText = FormatUtils.formatBytes(_cacheInfo.bytes);
    final chapterText = _cacheInfo.chapters == 0 ? '无' : '${_cacheInfo.chapters} 章';
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清除缓存'),
        content: Text('\n当前缓存 $sizeText（$chapterText）\n\n这将删除在线书籍的章节缓存，本地导入书籍不受影响。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清除'),
            onPressed: () async {
              Navigator.pop(context);
              await _clearCache();
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
        actions: [
          CupertinoActionSheetAction(
            child: const Text('导出备份（推荐）'),
            onPressed: () {
              Navigator.pop(context);
              _exportBackup(includeOnlineCache: false);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出（含在线缓存，体积大）'),
            onPressed: () {
              Navigator.pop(context);
              _exportBackup(includeOnlineCache: true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从文件导入（合并）'),
            onPressed: () {
              Navigator.pop(context);
              _importBackup(overwrite: false);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('从文件导入（覆盖当前数据）'),
            onPressed: () {
              Navigator.pop(context);
              _importBackup(overwrite: true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('iCloud 同步'),
            onPressed: () {
              Navigator.pop(context);
              _showMessage('暂未实现 iCloud 同步');
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

  Future<void> _clearCache() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final localBookIds = _db.booksBox.values
          .where((b) => b.isLocal)
          .map((b) => b.id)
          .toSet();
      final result =
          await _chapterRepo.clearDownloadedCache(protectBookIds: localBookIds);
      if (mounted) Navigator.pop(context);
      await _refreshStats();
      _showMessage(result.chapters == 0
          ? '没有可清理的缓存'
          : '已清理 ${FormatUtils.formatBytes(result.bytes)}（${result.chapters} 章）');
    } catch (_) {
      if (mounted) Navigator.pop(context);
      _showMessage('清理失败');
    }
  }

  Future<void> _exportBackup({required bool includeOnlineCache}) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );
    final result = await _backupService.exportToFile(
      includeOnlineCache: includeOnlineCache,
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (result.cancelled) return;
    _showMessage(result.success ? '导出成功' : (result.errorMessage ?? '导出失败'));
  }

  Future<void> _importBackup({required bool overwrite}) async {
    if (overwrite) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('确认覆盖导入？'),
          content: const Text('\n将清空当前书架、书源与缓存，再从备份恢复。此操作不可撤销。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('继续'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );
    final result = await _backupService.importFromFile(overwrite: overwrite);
    if (!mounted) return;
    Navigator.pop(context);
    if (result.cancelled) return;
    if (!result.success) {
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    await _refreshStats();
    _showMessage(
      '导入完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，章节 ${result.chaptersImported} 章',
    );
  }

  void _showAbout() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('SoupReader'),
        content: Text('\n版本 $_version\n\n一款简洁优雅的阅读应用\n支持自定义书源'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://github-action-cf.mcshr.workers.dev/latest',
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = response.data;
        final tag = data['tag'] as String?;
        final name = data['name'] as String?;
        final downloadUrl = data['downloadUrl'] as String?;
        final publishedAt = data['publishedAt'] as String?;

        if (downloadUrl == null || downloadUrl.isEmpty) {
          _showMessage('未找到安装包');
          return;
        }

        // 格式化发布信息
        String info = name ?? 'Nightly Build';
        String dateStr = '';
        if (publishedAt != null) {
          try {
            final date = DateTime.parse(publishedAt).toLocal();
            dateStr =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
            info += '\n$dateStr';
          } catch (_) {}
        }

        // 显示最新版本信息，让用户决定是否更新
        _showUpdateInfo(tag ?? 'nightly', info, downloadUrl);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        if (e is DioException && e.response?.statusCode == 404) {
          _showMessage('暂无更新');
        } else {
          _showMessage('检查失败');
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
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// 显示更新信息对话框
  void _showUpdateInfo(String tag, String info, String downloadUrl) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('最新版本'),
        content: Text('\n$tag\n$info'),
        actions: [
          CupertinoDialogAction(
            child: const Text('关闭'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('下载'),
            onPressed: () {
              Navigator.pop(dialogContext);
              launchUrl(Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}
