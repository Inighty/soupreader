import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:soupreader/app/theme/source_ui_tokens.dart';
import 'package:soupreader/app/widgets/app_empty_state.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_availability/check_task_service.dart';
import 'package:soupreader/features/source/views/list/widgets/batch_bar.dart';

class SourceListCheckTaskBanner extends StatelessWidget {
  const SourceListCheckTaskBanner({
    super.key,
    required this.snapshot,
    required this.progressText,
    required this.onStop,
  });

  final SourceCheckTaskSnapshot? snapshot;
  final String progressText;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    if (current == null || !current.running) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: CupertinoColors.systemYellow.resolveFrom(context).withValues(alpha: 0.14),
      padding: const EdgeInsets.fromLTRB(
        SourceUiTokens.pagePaddingHorizontal,
        8,
        SourceUiTokens.pagePaddingHorizontal,
        8,
      ),
      child: Row(
        children: [
          const CupertinoActivityIndicator(radius: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              progressText,
              style: TextStyle(
                fontSize: SourceUiTokens.itemMetaSize,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: const Size(44, 28),
            onPressed: current.stopRequested ? null : onStop,
            child: Text(current.stopRequested ? '停止中' : '停止'),
          ),
        ],
      ),
    );
  }
}

class SourceListContent extends StatelessWidget {
  const SourceListContent({
    super.key,
    required this.visibleSources,
    required this.selectedUrls,
    required this.itemKeyForUrl,
    required this.listViewportKey,
    required this.listScrollController,
    required this.canManualReorder,
    required this.groupSourcesByDomain,
    required this.sortModeIsManual,
    required this.hostOf,
    required this.checkTaskRunning,
    required this.inlineCheckStatus,
    required this.inlineCheckMessage,
    required this.inlineCheckColor,
    required this.onToggleEnabled,
    required this.onToggleExplore,
    required this.onToggleSelection,
    required this.onStartDragSelection,
    required this.onUpdateDragSelection,
    required this.onAutoScrollForDragSelection,
    required this.onEndDragSelection,
    required this.onOpenEditor,
    required this.onMoveToTop,
    required this.onShowSourceActions,
    required this.onConfirmDelete,
    required this.onReorderVisible,
    required this.onSelectAllOrClearVisible,
    required this.onInvertVisibleSelection,
    required this.onBatchDeleteSelected,
    required this.onShowBatchMoreActions,
  });

  final List<BookSource> visibleSources;
  final Set<String> selectedUrls;
  final GlobalKey Function(String url) itemKeyForUrl;
  final GlobalKey listViewportKey;
  final ScrollController listScrollController;
  final bool canManualReorder;
  final bool groupSourcesByDomain;
  final bool sortModeIsManual;
  final String Function(String url) hostOf;
  final bool checkTaskRunning;
  final SourceCheckStatus? Function(BookSource source) inlineCheckStatus;
  final String? Function(BookSource source) inlineCheckMessage;
  final Color Function(SourceCheckStatus status) inlineCheckColor;
  final Future<void> Function(BookSource source) onToggleEnabled;
  final Future<void> Function(BookSource source) onToggleExplore;
  final void Function(String url) onToggleSelection;
  final void Function(List<BookSource> visible, int index) onStartDragSelection;
  final void Function(List<BookSource> visible, Offset globalPosition)
      onUpdateDragSelection;
  final void Function(List<BookSource> visible, Offset globalPosition)
      onAutoScrollForDragSelection;
  final VoidCallback onEndDragSelection;
  final Future<void> Function(String bookSourceUrl) onOpenEditor;
  final Future<void> Function(BookSource source) onMoveToTop;
  final Future<void> Function(BookSource source) onShowSourceActions;
  final Future<void> Function(BookSource source) onConfirmDelete;
  final Future<void> Function(List<BookSource> visible, int oldIndex, int newIndex)
      onReorderVisible;
  final VoidCallback onSelectAllOrClearVisible;
  final VoidCallback onInvertVisibleSelection;
  final Future<void> Function() onBatchDeleteSelected;
  final Future<void> Function() onShowBatchMoreActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: visibleSources.isEmpty
              ? const AppEmptyState(
                  illustration: AppEmptyPlanetIllustration(size: 86),
                  title: '暂无书源',
                  message: '点击右上角更多导入书源',
                )
              : _buildSourceList(context),
        ),
        SourceListBatchBar(
          visibleSources: visibleSources,
          selectedUrls: selectedUrls,
          onSelectAllOrClearVisible: onSelectAllOrClearVisible,
          onInvertVisibleSelection: onInvertVisibleSelection,
          onBatchDeleteSelected: onBatchDeleteSelected,
          onShowBatchMoreActions: onShowBatchMoreActions,
        ),
      ],
    );
  }

  Widget _buildSourceList(BuildContext context) {
    final reorderEnabled = canManualReorder;
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final secondaryTextColor = SourceUiTokens.resolveSecondaryTextColor(context);
    final primaryActionColor = SourceUiTokens.resolvePrimaryActionColor(context);
    final titleStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: SourceUiTokens.itemTitleSize,
          color: titleColor,
        );

    Widget buildStatusIcon(
      bool? state,
      VoidCallback? onTap, {
      IconData activeIcon = CupertinoIcons.checkmark_circle_fill,
      IconData inactiveIcon = CupertinoIcons.circle,
    }) {
      if (state == null) return const SizedBox(width: 36, height: 44);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 44,
          child: Icon(
            state ? activeIcon : inactiveIcon,
            size: 20,
            color: state
                ? primaryActionColor
                : CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
        ),
      );
    }

    Widget buildItem(BookSource source, int index) {
      final selected = selectedUrls.contains(source.bookSourceUrl);
      final checkStatus = inlineCheckStatus(source);
      final checkMessage = inlineCheckMessage(source);
      final showHeader = groupSourcesByDomain &&
          (index == 0 ||
              hostOf(visibleSources[index - 1].bookSourceUrl) !=
                  hostOf(source.bookSourceUrl));
      final groupText = (source.bookSourceGroup ?? '').trim();
      final hasExplore = (source.exploreUrl ?? '').trim().isNotEmpty;
      final displayName = groupText.isEmpty
          ? source.bookSourceName
          : '${source.bookSourceName} ($groupText)';

      final rowContent = Column(
        key: itemKeyForUrl(source.bookSourceUrl),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                hostOf(source.bookSourceUrl),
                style: TextStyle(
                  fontSize: SourceUiTokens.itemMetaSize,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ),
          ColoredBox(
            color: selected
                ? primaryActionColor.withValues(alpha: 0.06)
                : CupertinoColors.systemBackground.resolveFrom(context),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggleSelection(source.bookSourceUrl),
              onLongPressStart: (_) => onStartDragSelection(visibleSources, index),
              onLongPressMoveUpdate: (details) {
                onUpdateDragSelection(visibleSources, details.globalPosition);
                onAutoScrollForDragSelection(
                  visibleSources,
                  details.globalPosition,
                );
              },
              onLongPressEnd: (_) => onEndDragSelection(),
              onLongPressCancel: onEndDragSelection,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: selected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            size: 20,
                            color: primaryActionColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        if (reorderEnabled)
                          ReorderableDragStartListener(
                            index: index,
                            child: SizedBox(
                              width: 32,
                              height: 44,
                              child: Icon(
                                CupertinoIcons.line_horizontal_3,
                                size: 18,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                        buildStatusIcon(
                          source.enabled,
                          () => unawaited(onToggleEnabled(source)),
                        ),
                        buildStatusIcon(
                          hasExplore ? source.enabledExplore : null,
                          hasExplore ? () => unawaited(onToggleExplore(source)) : null,
                          activeIcon: CupertinoIcons.compass_fill,
                          inactiveIcon: CupertinoIcons.compass,
                        ),
                      ],
                    ),
                    if (checkMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                checkMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: SourceUiTokens.itemSubMetaSize,
                                  color: inlineCheckColor(
                                    checkStatus ?? SourceCheckStatus.pending,
                                  ),
                                ),
                              ),
                            ),
                            if (checkTaskRunning &&
                                (checkStatus == SourceCheckStatus.pending ||
                                    checkStatus == SourceCheckStatus.running))
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CupertinoActivityIndicator(radius: 7),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

      return Slidable(
        key: ValueKey(source.bookSourceUrl),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: sortModeIsManual ? 0.75 : 0.6,
          children: [
            SlidableAction(
              onPressed: (_) => unawaited(onOpenEditor(source.bookSourceUrl)),
              backgroundColor: primaryActionColor,
              foregroundColor: CupertinoColors.white,
              icon: CupertinoIcons.pencil,
              label: '编辑',
            ),
            if (sortModeIsManual)
              SlidableAction(
                onPressed: (_) => unawaited(onMoveToTop(source)),
                backgroundColor: CupertinoColors.systemOrange.resolveFrom(context),
                foregroundColor: CupertinoColors.white,
                icon: CupertinoIcons.arrow_up,
                label: '置顶',
              ),
            SlidableAction(
              onPressed: (_) => unawaited(onShowSourceActions(source)),
              backgroundColor: CupertinoColors.systemGrey.resolveFrom(context),
              foregroundColor: CupertinoColors.white,
              icon: CupertinoIcons.ellipsis,
              label: '更多',
            ),
            SlidableAction(
              onPressed: (_) => unawaited(onConfirmDelete(source)),
              backgroundColor: CupertinoColors.systemRed.resolveFrom(context),
              foregroundColor: CupertinoColors.white,
              icon: CupertinoIcons.delete,
              label: '删除',
            ),
          ],
        ),
        child: rowContent,
      );
    }

    if (reorderEnabled) {
      return CustomScrollView(
        key: listViewportKey,
        controller: listScrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            sliver: SliverReorderableList(
              itemCount: visibleSources.length,
              onReorder: (oldIndex, newIndex) {
                return onReorderVisible(visibleSources, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final source = visibleSources[index];
                return KeyedSubtree(
                  key: ValueKey(source.bookSourceUrl),
                  child: buildItem(source, index),
                );
              },
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      key: listViewportKey,
      controller: listScrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      itemCount: visibleSources.length,
      separatorBuilder: (_, __) => Container(
        height: SourceUiTokens.borderWidth,
        margin: const EdgeInsets.only(left: 44),
        color: SourceUiTokens.resolveSeparatorColor(context),
      ),
      itemBuilder: (context, index) => buildItem(visibleSources[index], index),
    );
  }
}
