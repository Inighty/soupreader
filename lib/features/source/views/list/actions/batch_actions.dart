import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';

import 'package:soupreader/app/widgets/app_action_list_sheet.dart';
import 'package:soupreader/app/widgets/app_toast.dart';
import 'package:soupreader/app/widgets/cupertino_bottom_dialog.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/source_variable_store.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_availability/check_task_service.dart';
import 'package:soupreader/features/source/services/source_import/export_service.dart';
import 'package:soupreader/features/source/views/list/widgets/dialogs.dart';
import 'package:soupreader/features/source/views/list/actions/group_actions.dart';
import 'package:soupreader/features/source/views/list/actions/settings_helper.dart';
import 'package:soupreader/features/source/views/list/source_list_support.dart';
import 'package:soupreader/features/source/views/list/source_list_types.dart';

class SourceListBatchActions {
  const SourceListBatchActions({
    required this.context,
    required this.sourceRepo,
    required this.importExportService,
    required this.checkTaskService,
    required this.settingsHelper,
    required this.groupActions,
    required this.moveSourcesHandler,
  });

  final BuildContext context;
  final SourceRepository sourceRepo;
  final SourceImportExportService importExportService;
  final SourceAvailabilityCheckTaskService checkTaskService;
  final SourceListSettingsHelper settingsHelper;
  final SourceListGroupActions groupActions;
  final SourceMoveSourcesHandler? moveSourcesHandler;

  List<BookSource> selectedSources({
    required Set<String> selectedUrls,
    required List<BookSource> allSources,
  }) {
    return allSources
        .where((source) => selectedUrls.contains(source.bookSourceUrl))
        .toList(growable: false);
  }

  Future<void> showBatchMoreActions({
    required List<BookSource> visibleSources,
    required Set<String> selectedUrls,
    required VoidCallback onSelectInterval,
  }) async {
    final action = await showAppActionListSheet<SourceBatchAction>(
      context: context,
      title: '批量操作',
      titleAlign: TextAlign.left,
      items: const [
        AppActionListItem(
          value: SourceBatchAction.enableSelected,
          icon: CupertinoIcons.check_mark_circled,
          label: '启用所选',
        ),
        AppActionListItem(
          value: SourceBatchAction.disableSelected,
          icon: CupertinoIcons.nosign,
          label: '禁用所选',
        ),
        AppActionListItem(
          value: SourceBatchAction.addGroup,
          icon: CupertinoIcons.folder_badge_plus,
          label: '添加分组',
        ),
        AppActionListItem(
          value: SourceBatchAction.removeGroup,
          icon: CupertinoIcons.minus_circle,
          label: '移除分组',
        ),
        AppActionListItem(
          value: SourceBatchAction.enableExplore,
          icon: CupertinoIcons.globe,
          label: '启用发现',
        ),
        AppActionListItem(
          value: SourceBatchAction.disableExplore,
          icon: CupertinoIcons.globe,
          label: '禁用发现',
        ),
        AppActionListItem(
          value: SourceBatchAction.moveToTop,
          icon: CupertinoIcons.arrow_up,
          label: '置顶所选',
        ),
        AppActionListItem(
          value: SourceBatchAction.moveToBottom,
          icon: CupertinoIcons.arrow_down,
          label: '置底所选',
        ),
        AppActionListItem(
          value: SourceBatchAction.exportSelected,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出所选',
        ),
        AppActionListItem(
          value: SourceBatchAction.shareSelected,
          icon: CupertinoIcons.share,
          label: '分享选中源',
        ),
        AppActionListItem(
          value: SourceBatchAction.checkSelected,
          icon: CupertinoIcons.checkmark_seal,
          label: '校验所选',
        ),
        AppActionListItem(
          value: SourceBatchAction.selectInterval,
          icon: CupertinoIcons.rectangle_3_offgrid,
          label: '选中所选区间',
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case SourceBatchAction.enableSelected:
        await updateEnabledSelection(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
          enabled: true,
        );
        return;
      case SourceBatchAction.disableSelected:
        await updateEnabledSelection(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
          enabled: false,
        );
        return;
      case SourceBatchAction.addGroup:
        await addGroup(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
        );
        return;
      case SourceBatchAction.removeGroup:
        await removeGroup(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
        );
        return;
      case SourceBatchAction.enableExplore:
        await updateExploreSelection(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
          enabled: true,
        );
        return;
      case SourceBatchAction.disableExplore:
        await updateExploreSelection(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
          enabled: false,
        );
        return;
      case SourceBatchAction.moveToTop:
        await moveSelection(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
          toTop: true,
        );
        return;
      case SourceBatchAction.moveToBottom:
        await moveSelection(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
          toTop: false,
        );
        return;
      case SourceBatchAction.exportSelected:
        await exportSelected(
          visibleSources: visibleSources,
          selectedUrls: selectedUrls,
        );
        return;
      case SourceBatchAction.shareSelected:
        await shareSelected(
          visibleSources: visibleSources,
          selectedUrls: selectedUrls,
        );
        return;
      case SourceBatchAction.checkSelected:
        await checkSelected(
          allSources: visibleSources,
          selectedUrls: selectedUrls,
        );
        return;
      case SourceBatchAction.selectInterval:
        onSelectInterval();
        return;
    }
  }

  Future<void> updateEnabledSelection({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
    required bool enabled,
  }) async {
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: allSources,
    );
    if (selected.isEmpty) return;
    await Future.wait(
      selected.map(
        (source) => sourceRepo.updateSource(source.copyWith(enabled: enabled)),
      ),
    );
  }

  Future<void> updateExploreSelection({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
    required bool enabled,
  }) async {
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: allSources,
    );
    if (selected.isEmpty) return;
    await Future.wait(
      selected.map(
        (source) =>
            sourceRepo.updateSource(source.copyWith(enabledExplore: enabled)),
      ),
    );
  }

  Future<void> addGroup({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
  }) async {
    final groupInput = await groupActions.askGroupName('添加分组');
    if (groupInput == null || groupInput.trim().isEmpty) return;
    final addGroups = SourceListSupport.splitGroups(groupInput);
    if (addGroups.isEmpty) return;
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: allSources,
    );
    if (selected.isEmpty) return;
    await Future.wait(selected.map((source) async {
      final groups = SourceListSupport.splitGroups(source.bookSourceGroup);
      groups.addAll(addGroups);
      await sourceRepo.updateSource(
        groupActions.copySourceWithGroup(
          source,
          SourceListSupport.joinGroups(groups),
        ),
      );
    }));
  }

  Future<void> removeGroup({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
  }) async {
    final groupInput = await groupActions.askGroupName('移除分组');
    if (groupInput == null || groupInput.trim().isEmpty) return;
    final removeGroups = SourceListSupport.splitGroups(groupInput).toSet();
    if (removeGroups.isEmpty) return;
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: allSources,
    );
    if (selected.isEmpty) return;
    await Future.wait(selected.map((source) async {
      final groups = SourceListSupport.splitGroups(source.bookSourceGroup);
      groups.removeWhere(removeGroups.contains);
      await sourceRepo.updateSource(
        groupActions.copySourceWithGroup(
          source,
          SourceListSupport.joinGroups(groups),
        ),
      );
    }));
  }

  Future<void> moveSelection({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
    required bool toTop,
  }) async {
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: allSources,
    );
    if (selected.isEmpty) return;
    await moveSourcesToTopBottom(selected, toTop: toTop);
  }

  Future<void> checkSelected({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
  }) async {
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: allSources,
    );
    if (selected.isEmpty) return;
    final keyword = await settingsHelper.askCheckKeyword();
    if (keyword == null) return;
    final checkSettings = settingsHelper.loadCheckSettings();
    final startResult = await checkTaskService.start(
      SourceCheckTaskConfig(
        includeDisabled: true,
        sourceUrls:
            selected.map((source) => source.bookSourceUrl).toList(growable: false),
        keywordOverride: keyword,
        timeoutMs: checkSettings.timeoutMs,
        checkSearch: checkSettings.checkSearch,
        checkDiscovery: checkSettings.checkDiscovery,
        checkInfo: checkSettings.checkInfo,
        checkCategory: checkSettings.checkCategory,
        checkContent: checkSettings.checkContent,
      ),
      forceRestart: true,
    );
    if (startResult.type == SourceCheckStartType.runningOtherTask ||
        startResult.type == SourceCheckStartType.attachedExisting) {
      unawaited(showAppToast(context, message: '已有书源在校验，等完成后再试'));
    }
  }

  Future<void> deleteSelected({
    required List<BookSource> allSources,
    required Set<String> selectedUrls,
    required VoidCallback onSelectionCleared,
  }) async {
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: allSources,
    );
    if (selected.isEmpty) {
      unawaited(showAppToast(context, message: '当前未选择书源'));
      return;
    }

    final ok = await showCupertinoBottomSheetDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('批量删除'),
            content: Text('\n将删除 ${selected.length} 条书源，此操作不可撤销。'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认删除'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    await Future.wait(
      selected.map((source) => deleteSourceByLegacyRule(source.bookSourceUrl)),
    );
    onSelectionCleared();
    unawaited(showAppToast(context, message: '已删除 ${selected.length} 条书源'));
  }

  Future<void> exportSelected({
    required List<BookSource> visibleSources,
    required Set<String> selectedUrls,
  }) async {
    final sources = resolveExportShareSources(
      visibleSources: visibleSources,
      selectedUrls: selectedUrls,
    );
    if (sources.isEmpty) {
      unawaited(showAppToast(context, message: '当前未选择书源'));
      return;
    }
    final result = await importExportService.exportToFile(
      sources,
      defaultFileName: 'bookSource.json',
    );
    if (result.cancelled) return;
    if (!result.success) {
      await SourceListDialogs.showMessage(
        context,
        result.errorMessage ?? '导出失败',
      );
      return;
    }
    final path = (result.outputPath ?? '').trim();
    if (path.isEmpty) {
      unawaited(showAppToast(context, message: '导出成功'));
      return;
    }
    await SourceListDialogs.showExportPathDialog(context, path);
  }

  Future<void> shareSelected({
    required List<BookSource> visibleSources,
    required Set<String> selectedUrls,
  }) async {
    final sources = resolveExportShareSources(
      visibleSources: visibleSources,
      selectedUrls: selectedUrls,
    );
    if (sources.isEmpty) return;
    await shareSources(sources);
  }

  Future<void> shareSources(List<BookSource> sources) async {
    if (sources.isEmpty) return;
    try {
      final file = await importExportService.exportToShareFile(sources);
      if (file == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/*')],
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(file)：分享异常不追加提示。
    }
  }

  List<BookSource> resolveExportShareSources({
    required List<BookSource> visibleSources,
    required Set<String> selectedUrls,
  }) {
    final selected = selectedSources(
      selectedUrls: selectedUrls,
      allSources: visibleSources,
    );
    if (selected.isEmpty || visibleSources.isEmpty) {
      return const <BookSource>[];
    }
    final selectedRate = selected.length / visibleSources.length;
    if (selected.length == visibleSources.length) {
      return visibleSources;
    }
    if (selectedRate < 0.3) {
      return selected;
    }
    final selectedKeys =
        selected.map((source) => source.bookSourceUrl).toSet();
    return visibleSources
        .where((source) => selectedKeys.contains(source.bookSourceUrl))
        .toList(growable: false);
  }

  Future<void> deleteSourceByLegacyRule(String sourceUrl) async {
    await sourceRepo.deleteSource(sourceUrl);
    await SourceVariableStore.removeVariable(sourceUrl);
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
