import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../controllers/reader_coordinator.dart';
import '../controllers/source_switch_coordinator.dart';
import '../services/reader_source_switch_helper.dart';
import '../widgets/source_switch_candidate_sheet.dart';
import 'reader_dialog_helpers.dart';

/// 换源相关的对话框操作。
///
/// 将 [SourceSwitchCoordinator] 的纯逻辑与
/// [showSourceSwitchCandidateSheet] 的 UI 桥接。
class SourceSwitchDialogs {
  SourceSwitchDialogs._();

  /// 打开"按书名换源"的完整流程。
  ///
  /// 1. 搜索候选源
  /// 2. 显示候选列表弹窗
  /// 3. 用户选择后切换到新源
  /// 4. 重新加载当前章节
  static Future<void> showBookSourceSwitch({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) async {
    final ssc = coordinator.sourceSwitchCoordinator;
    if (ssc == null) {
      ReaderDialogHelpers.showToast(context, '换源功能不可用');
      return;
    }

    final book = ssc.buildCurrentBookForSwitch();
    final keyword = (book.title ?? '').trim();
    if (keyword.isEmpty) {
      ReaderDialogHelpers.showToast(context, '书名为空，无法换源');
      return;
    }

    // 搜索候选源
    final candidates = await ssc.searchCandidates(
      keyword: keyword,
      authorKeyword: book.author,
    );
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      ReaderDialogHelpers.showToast(context, '未找到可切换的匹配书源');
      return;
    }

    // 显示候选列表
    final selected = await showSourceSwitchCandidateSheet(
      context: context,
      keyword: keyword,
      candidates: candidates,
      currentSourceUrl: ssc.image.sourceUrl ?? '',
      changeSourceGroup: ssc.group,
      sourceGroups: ssc.buildSourceGroups(),
      authorKeyword: book.author ?? '',
      checkAuthorEnabled: ssc.checkAuthor,
      loadInfoEnabled: ssc.loadInfo,
      loadWordCountEnabled: ssc.loadWordCount,
      loadTocEnabled: ssc.loadToc,
      changeSourceDelaySeconds: ssc.delaySeconds,
      onCheckAuthorChanged: (enabled) async {
        ssc.updateCheckAuthor(enabled);
      },
      onLoadInfoChanged: (enabled) async {
        ssc.updateLoadInfo(enabled);
      },
      onLoadWordCountChanged: (enabled) async {
        ssc.updateLoadWordCount(enabled);
      },
      onLoadTocChanged: (enabled) async {
        ssc.updateLoadToc(enabled);
      },
      onChangeSourceDelayChanged: (seconds) async {
        ssc.updateDelay(seconds);
      },
      onChangeSourceGroupChanged: (group) async {
        ssc.updateGroup(group);
      },
      onStartCandidatesSearch: (currentCandidates) async {
        return await ssc.searchCandidates(
          keyword: keyword,
          authorKeyword: book.author,
        );
      },
      onStopCandidatesSearch: () async {
        ssc.stopCandidateSearch();
      },
    );

    ssc.stopCandidateSearch();
    if (selected == null || !context.mounted) return;

    // 切换到选中的源
    final success = await ssc.switchToCandidate(selected);
    if (!context.mounted) return;
    if (!success) {
      ReaderDialogHelpers.showToast(context, '换源失败');
      return;
    }

    // 重新加载当前章节
    await coordinator.loadChapter(
      coordinator.chapter.currentIndex,
      restoreOffset: true,
    );
  }

  /// 打开"按章节换源"的流程。
  static Future<void> showChapterSourceSwitch({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) async {
    final ssc = coordinator.sourceSwitchCoordinator;
    if (ssc == null) {
      ReaderDialogHelpers.showToast(context, '换源功能不可用');
      return;
    }

    final chapterTitle = ssc.resolveCurrentChapterTitle();
    if (chapterTitle.isEmpty) {
      ReaderDialogHelpers.showToast(context, '当前章节标题为空');
      return;
    }

    final candidates = await ssc.searchCandidates(
      keyword: chapterTitle,
    );
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      ReaderDialogHelpers.showToast(context, '未找到匹配的书源');
      return;
    }

    final selected = await showSourceSwitchCandidateSheet(
      context: context,
      keyword: chapterTitle,
      candidates: candidates,
      currentSourceUrl: ssc.image.sourceUrl ?? '',
      onStopCandidatesSearch: () async {
        ssc.stopCandidateSearch();
      },
    );

    ssc.stopCandidateSearch();
    if (selected == null || !context.mounted) return;

    final success = await ssc.switchToCandidate(selected);
    if (!context.mounted) return;
    if (!success) {
      ReaderDialogHelpers.showToast(context, '换源失败');
      return;
    }

    await coordinator.loadChapter(
      coordinator.chapter.currentIndex,
      restoreOffset: true,
    );
  }

  /// 打开换源入口选择（按书名 / 按章节）。
  static Future<void> showSourceSwitchEntry({
    required BuildContext context,
    required ReaderCoordinator coordinator,
  }) async {
    final action = await showCupertinoBottomSheetDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('换源方式'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 0),
            child: const Text('按书名换源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 1),
            child: const Text('按章节换源'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 0:
        await showBookSourceSwitch(
          context: context,
          coordinator: coordinator,
        );
      case 1:
        await showChapterSourceSwitch(
          context: context,
          coordinator: coordinator,
        );
    }
  }
}
