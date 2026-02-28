import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/views/reading_history_view.dart';
import '../../reader/views/all_bookmark_view.dart';
import '../../reader/views/dict_rule_manage_view.dart';
import '../../reader/views/txt_toc_rule_manage_view.dart';
import '../../replace/views/replace_rule_list_view.dart';
import '../../source/views/source_list_view.dart';
import 'about_settings_view.dart';
import 'app_help_dialog.dart';
import 'backup_settings_view.dart';
import 'file_manage_view.dart';
import 'other_settings_view.dart';
import 'settings_placeholders.dart';
import 'theme_settings_view.dart';

/// 我的页菜单（按 legado `pref_main.xml` 入口顺序迁移）
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    this.reselectSignal,
  });

  final ValueListenable<int>? reselectSignal;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsService _settingsService = SettingsService();
  final ScrollController _sliverScrollController = ScrollController();
  bool _loadingMyHelp = false;
  int? _lastReselectVersion;

  @override
  void initState() {
    super.initState();
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    _bindReselectSignal(widget.reselectSignal);
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal == widget.reselectSignal) return;
    _unbindReselectSignal(oldWidget.reselectSignal);
    _bindReselectSignal(widget.reselectSignal);
  }

  @override
  void dispose() {
    _unbindReselectSignal(widget.reselectSignal);
    _settingsService.appSettingsListenable
        .removeListener(_onAppSettingsChanged);
    _sliverScrollController.dispose();
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _bindReselectSignal(ValueListenable<int>? signal) {
    _lastReselectVersion = signal?.value;
    signal?.addListener(_onReselectSignalChanged);
  }

  void _unbindReselectSignal(ValueListenable<int>? signal) {
    signal?.removeListener(_onReselectSignalChanged);
  }

  void _onReselectSignalChanged() {
    final signal = widget.reselectSignal;
    if (signal == null) return;
    final version = signal.value;
    if (_lastReselectVersion == version) return;
    _lastReselectVersion = version;
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_sliverScrollController.hasClients) return;
    _sliverScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String get _themeModeSummary {
    final app = _settingsService.appSettings;
    switch (app.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return '跟随系统';
      case AppAppearanceMode.light:
        return '浅色';
      case AppAppearanceMode.dark:
        return '深色';
      case AppAppearanceMode.eInk:
        return 'E-Ink';
    }
  }

  Future<void> _pickThemeMode() async {
    final current = _settingsService.appSettings.appearanceMode;
    final selected = await showOptionPickerSheet<AppAppearanceMode>(
      context: context,
      title: '主题模式',
      currentValue: current,
      accentColor: AppDesignTokens.brandPrimary,
      items: const [
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.followSystem,
          label: '跟随系统',
        ),
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.light,
          label: '浅色',
        ),
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.dark,
          label: '深色',
        ),
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.eInk,
          label: 'E-Ink',
        ),
      ],
    );
    if (selected == null || selected == current) return;
    await _settingsService.saveAppSettings(
      _settingsService.appSettings.copyWith(appearanceMode: selected),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openMyHelp() async {
    if (_loadingMyHelp) return;
    setState(() => _loadingMyHelp = true);
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/appHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(
        context,
        markdownText: markdownText,
      );
    } catch (error) {
      if (!mounted) return;
      await showCupertinoBottomDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingMyHelp = false);
    }
  }

  Widget _buildHelpAction() {
    if (_loadingMyHelp) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: CupertinoActivityIndicator(radius: 9),
      );
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _openMyHelp,
      minimumSize: const Size(30, 30),
      child: const Icon(CupertinoIcons.question_circle, size: 22),
    );
  }

  void _showWebServiceNotImplemented() {
    SettingsPlaceholders.showNotImplemented(
      context,
      title: 'Web服务不在本轮迁移范围',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '我的',
      useSliverNavigationBar: true,
      sliverScrollController: _sliverScrollController,
      trailing: _buildHelpAction(),
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => _buildBodySliver(context),
    );
  }

  Widget _buildBodySliver(BuildContext context) {
    return SliverSafeArea(
      top: false,
      bottom: true,
      sliver: SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoListSection.insetGrouped(
                header: const Text('源管理'),
                children: [
                  CupertinoListTile.notched(
                    key: const Key('my_menu_bookSourceManage'),
                    leading: const Icon(CupertinoIcons.book),
                    title: const Text('书源管理'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const SourceListView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_txtTocRuleManage'),
                    leading: const Icon(CupertinoIcons.doc_text),
                    title: const Text('TXT目录规则'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const TxtTocRuleManageView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_replaceManage'),
                    leading: const Icon(CupertinoIcons.wand_stars),
                    title: const Text('替换净化'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const ReplaceRuleListView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_dictRuleManage'),
                    leading: const Icon(CupertinoIcons.dot_radiowaves_right),
                    title: const Text('字典规则'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const DictRuleManageView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_themeMode'),
                    leading: const Icon(CupertinoIcons.paintbrush),
                    title: const Text('主题模式'),
                    additionalInfo: Text(_themeModeSummary),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _pickThemeMode,
                  ),
                  if (!MigrationExclusions.excludeWebService)
                    CupertinoListTile.notched(
                      key: const Key('my_menu_webService'),
                      leading: const Icon(CupertinoIcons.globe),
                      title: const Text('Web服务'),
                      trailing: CupertinoSwitch(
                        value: false,
                        onChanged: (_) => _showWebServiceNotImplemented(),
                      ),
                      onTap: _showWebServiceNotImplemented,
                    ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('主题'),
                children: [
                  CupertinoListTile.notched(
                    key: const Key('my_menu_web_dav_setting'),
                    leading: const Icon(CupertinoIcons.cloud_upload),
                    title: const Text('备份与恢复'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const BackupSettingsView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_theme_setting'),
                    leading: const Icon(CupertinoIcons.paintbrush),
                    title: const Text('主题设置'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const ThemeSettingsView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_setting'),
                    leading: const Icon(CupertinoIcons.gear),
                    title: const Text('其它设置'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const OtherSettingsView(),
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('功能 & 设置'),
                children: [
                  CupertinoListTile.notched(
                    key: const Key('my_menu_bookmark'),
                    leading: const Icon(CupertinoIcons.bookmark),
                    title: const Text('书签'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const AllBookmarkView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_readRecord'),
                    leading: const Icon(CupertinoIcons.clock),
                    title: const Text('阅读记录'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const ReadingHistoryView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_fileManage'),
                    leading: const Icon(CupertinoIcons.folder),
                    title: const Text('文件管理'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const FileManageView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_about'),
                    leading: const Icon(CupertinoIcons.info_circle),
                    title: const Text('关于'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _open(
                      context,
                      const AboutSettingsView(),
                    ),
                  ),
                  CupertinoListTile.notched(
                    key: const Key('my_menu_exit'),
                    leading: const Icon(CupertinoIcons.arrow_right_circle),
                    title: const Text('退出'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => SystemNavigator.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => page),
    );
  }
}
