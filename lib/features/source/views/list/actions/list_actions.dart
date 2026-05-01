import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/widgets/app_action_list_sheet.dart';
import 'package:soupreader/app/widgets/app_popover_menu.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/source_variable_store.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/views/shared/group_filter_sheet.dart';
import 'package:soupreader/features/source/views/list/source_list_support.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';
import 'package:soupreader/features/source/views/shared/sort_sheet.dart';

class SourceListActions {
  const SourceListActions({
    required this.context,
    required this.sourceRepo,
    required this.moveSourcesHandler,
    required this.moreMenuKey,
    required this.sortMode,
    required this.sortAscending,
    required this.groupSourcesByDomain,
    required this.setSearchQuery,
    required this.getAllSources,
    required this.sortModeLabel,
    required this.applySortChange,
    required this.onOpenGroupManage,
    required this.onToggleGroupByDomain,
    required this.onImportFile,
    required this.onImportUrl,
    required this.onImportQr,
    required this.onShowHelp,
    required this.onCreateNewSource,
    required this.onShareSources,
    required this.onConfirmDeleteSource,
    required this.onOpenSourceLogin,
    required this.onOpenSourceDebug,
    required this.onOpenSourceScopedSearch,
    required this.onToggleSourceExplore,
  });

  final BuildContext context;
  final SourceRepository sourceRepo;
  final SourceMoveSourcesHandler? moveSourcesHandler;
  final GlobalKey moreMenuKey;
  final SourceSortMode sortMode;
  final bool sortAscending;
  final bool groupSourcesByDomain;
  final void Function(String query) setSearchQuery;
  final List<BookSource> Function() getAllSources;
  final String Function(SourceSortMode mode) sortModeLabel;
  final void Function(SourceSortMode mode, bool ascending) applySortChange;
  final Future<void> Function() onOpenGroupManage;
  final VoidCallback onToggleGroupByDomain;
  final Future<void> Function() onImportFile;
  final Future<void> Function() onImportUrl;
  final Future<void> Function() onImportQr;
  final Future<void> Function() onShowHelp;
  final Future<void> Function() onCreateNewSource;
  final Future<void> Function(List<BookSource> sources) onShareSources;
  final Future<void> Function(BookSource source) onConfirmDeleteSource;
  final Future<void> Function(String bookSourceUrl) onOpenSourceLogin;
  final Future<void> Function(BookSource source) onOpenSourceDebug;
  final Future<void> Function(BookSource source) onOpenSourceScopedSearch;
  final Future<void> Function(BookSource source) onToggleSourceExplore;

  Future<void> showMainOptions() async {
    final action = await showAppPopoverMenu<SourceMainMenuAction>(
      context: context,
      anchorKey: moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: SourceMainMenuAction.sort,
          icon: CupertinoIcons.arrow_up_arrow_down,
          label: '排序',
        ),
        AppPopoverMenuItem(
          value: SourceMainMenuAction.groupFilter,
          icon: CupertinoIcons.folder,
          label: '分组筛选',
        ),
        AppPopoverMenuItem(
          value: SourceMainMenuAction.create,
          icon: CupertinoIcons.add_circled,
          label: '新建书源',
        ),
        AppPopoverMenuItem(
          value: SourceMainMenuAction.importFile,
          icon: CupertinoIcons.doc,
          label: '本地导入',
        ),
        AppPopoverMenuItem(
          value: SourceMainMenuAction.importUrl,
          icon: CupertinoIcons.globe,
          label: '网络导入',
        ),
        AppPopoverMenuItem(
          value: SourceMainMenuAction.importQr,
          icon: CupertinoIcons.qrcode,
          label: '二维码导入',
        ),
        AppPopoverMenuItem(
          value: SourceMainMenuAction.help,
          icon: CupertinoIcons.question_circle,
          label: '帮助',
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case SourceMainMenuAction.sort:
        showSortOptions();
        return;
      case SourceMainMenuAction.groupFilter:
        showGroupFilterOptions();
        return;
      case SourceMainMenuAction.create:
        await onCreateNewSource();
        return;
      case SourceMainMenuAction.importFile:
        await onImportFile();
        return;
      case SourceMainMenuAction.importUrl:
        await onImportUrl();
        return;
      case SourceMainMenuAction.importQr:
        await onImportQr();
        return;
      case SourceMainMenuAction.help:
        await onShowHelp();
        return;
    }
  }

  void showSortOptions() {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SourceSortSheet(
        mode: sortMode,
        ascending: sortAscending,
        modeLabelBuilder: sortModeLabel,
        onChanged: applySortChange,
      ),
    );
  }

  void showGroupFilterOptions() {
    final groups = SourceListSupport.buildGroups(
      SourceListSupport.normalizeSources(getAllSources()),
    );
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SourceGroupFilterSheet(
        groups: groups,
        groupSourcesByDomain: groupSourcesByDomain,
        onOpenGroupManage: (sheetContext) {
          Navigator.pop(sheetContext);
          unawaited(onOpenGroupManage());
        },
        onToggleGroupByDomain: (sheetContext) {
          Navigator.pop(sheetContext);
          onToggleGroupByDomain();
        },
        onApplyQuery: (query, sheetContext) {
          setSearchQuery(query);
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  Future<void> showSourceActions(BookSource source) async {
    final items = <AppActionListItem<SourceItemAction>>[];
    if (sortMode == SourceSortMode.manual) {
      items.add(const AppActionListItem(
        value: SourceItemAction.toTop,
        icon: CupertinoIcons.arrow_up,
        label: '置顶',
      ));
      items.add(const AppActionListItem(
        value: SourceItemAction.toBottom,
        icon: CupertinoIcons.arrow_down,
        label: '置底',
      ));
    }
    items.add(AppActionListItem(
      value: SourceItemAction.toggleEnabled,
      icon: source.enabled ? CupertinoIcons.nosign : CupertinoIcons.check_mark,
      label: source.enabled ? '禁用' : '启用',
    ));
    items.add(const AppActionListItem(
      value: SourceItemAction.delete,
      icon: CupertinoIcons.delete,
      label: '删除',
      isDestructiveAction: true,
    ));
    items.add(const AppActionListItem(
      value: SourceItemAction.share,
      icon: CupertinoIcons.share,
      label: '分享',
    ));
    if ((source.loginUrl ?? '').trim().isNotEmpty) {
      items.add(const AppActionListItem(
        value: SourceItemAction.login,
        icon: CupertinoIcons.person,
        label: '登录',
      ));
    }
    items.add(const AppActionListItem(
      value: SourceItemAction.search,
      icon: CupertinoIcons.search,
      label: '搜索',
    ));
    items.add(const AppActionListItem(
      value: SourceItemAction.debug,
      icon: CupertinoIcons.ant,
      label: '调试',
    ));
    if ((source.exploreUrl ?? '').trim().isNotEmpty) {
      items.add(AppActionListItem(
        value: SourceItemAction.toggleExplore,
        icon: CupertinoIcons.globe,
        label: source.enabledExplore ? '禁用发现' : '启用发现',
      ));
    }

    final action = await showAppActionListSheet<SourceItemAction>(
      context: context,
      title: '更多操作',
      items: items,
      titleAlign: TextAlign.left,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case SourceItemAction.toTop:
        await toTop(source);
        return;
      case SourceItemAction.toBottom:
        await toBottom(source);
        return;
      case SourceItemAction.toggleEnabled:
        await sourceRepo.updateSource(source.copyWith(enabled: !source.enabled));
        return;
      case SourceItemAction.delete:
        await onConfirmDeleteSource(source);
        return;
      case SourceItemAction.share:
        await onShareSources([source]);
        return;
      case SourceItemAction.login:
        await onOpenSourceLogin(source.bookSourceUrl);
        return;
      case SourceItemAction.search:
        await onOpenSourceScopedSearch(source);
        return;
      case SourceItemAction.debug:
        await onOpenSourceDebug(source);
        return;
      case SourceItemAction.toggleExplore:
        await onToggleSourceExplore(source);
        return;
    }
  }

  Future<void> confirmDeleteSource(BookSource source) async {
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n${source.bookSourceName}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await deleteSourceByLegacyRule(source.bookSourceUrl);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteSourceByLegacyRule(String sourceUrl) async {
    await sourceRepo.deleteSource(sourceUrl);
    await SourceVariableStore.removeVariable(sourceUrl);
  }

  Future<void> toTop(BookSource source) async {
    await moveSourcesToTopBottom([source], toTop: sortAscending);
  }

  Future<void> toBottom(BookSource source) async {
    await moveSourcesToTopBottom([source], toTop: !sortAscending);
  }

  Future<void> moveSourcesToTopBottom(
    List<BookSource> sources, {
    required bool toTop,
  }) async {
    if (sources.isEmpty) return;
    if (moveSourcesHandler != null) {
      await moveSourcesHandler!(sources, toTop: toTop);
      return;
    }
    final all = sourceRepo.getAllSources();
    if (all.isEmpty) return;

    final sorted = sources.toList(growable: false)
      ..sort((a, b) => a.customOrder.compareTo(b.customOrder));

    if (toTop) {
      final minOrder = all.map((source) => source.customOrder).reduce(math.min) - 1;
      final updated = sorted
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(customOrder: minOrder - entry.key))
          .toList(growable: false);
      await sourceRepo.addSources(updated);
      return;
    }

    final maxOrder = all.map((source) => source.customOrder).reduce(math.max) + 1;
    final updated = sorted
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(customOrder: maxOrder + entry.key))
        .toList(growable: false);
    await sourceRepo.addSources(updated);
  }
}
