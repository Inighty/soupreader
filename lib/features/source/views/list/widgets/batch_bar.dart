import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/theme/source_ui_tokens.dart';
import 'package:soupreader/features/source/models/book_source.dart';

class SourceListBatchBar extends StatelessWidget {
  const SourceListBatchBar({
    super.key,
    required this.visibleSources,
    required this.selectedUrls,
    required this.onSelectAllOrClearVisible,
    required this.onInvertVisibleSelection,
    required this.onBatchDeleteSelected,
    required this.onShowBatchMoreActions,
  });

  final List<BookSource> visibleSources;
  final Set<String> selectedUrls;
  final VoidCallback onSelectAllOrClearVisible;
  final VoidCallback onInvertVisibleSelection;
  final Future<void> Function() onBatchDeleteSelected;
  final Future<void> Function() onShowBatchMoreActions;

  @override
  Widget build(BuildContext context) {
    final selectedCount = visibleSources
        .where((source) => selectedUrls.contains(source.bookSourceUrl))
        .length;
    final totalCount = visibleSources.length;
    final allSelected = totalCount > 0 && selectedCount >= totalCount;
    final hasSelection = selectedCount > 0;
    final enabledColor = SourceUiTokens.resolvePrimaryActionColor(context);
    final disabledColor = SourceUiTokens.resolveMutedTextColor(context);
    final dangerColor = SourceUiTokens.resolveDangerColor(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          SourceUiTokens.pagePaddingHorizontal,
          8,
          8,
          8,
        ),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          border: Border(
            top: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: SourceUiTokens.borderWidth,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(
                  SourceUiTokens.minTapSize,
                  SourceUiTokens.minTapSize,
                ),
                alignment: Alignment.centerLeft,
                onPressed: totalCount == 0 ? null : onSelectAllOrClearVisible,
                child: Text(
                  allSelected
                      ? '取消全选（$selectedCount/$totalCount）'
                      : '全选（$selectedCount/$totalCount）',
                  style: TextStyle(
                    fontSize: SourceUiTokens.actionTextSize,
                    color: totalCount == 0 ? disabledColor : enabledColor,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(
                SourceUiTokens.minTapSize,
                SourceUiTokens.minTapSize,
              ),
              onPressed: hasSelection ? onInvertVisibleSelection : null,
              child: Text(
                '反选',
                style: TextStyle(
                  fontSize: SourceUiTokens.actionTextSize,
                  color: hasSelection ? enabledColor : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(
                SourceUiTokens.minTapSize,
                SourceUiTokens.minTapSize,
              ),
              onPressed: hasSelection ? () => unawaited(onBatchDeleteSelected()) : null,
              child: Text(
                '删除',
                style: TextStyle(
                  fontSize: SourceUiTokens.actionTextSize,
                  color: hasSelection ? dangerColor : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: const Size(
                SourceUiTokens.minTapSize,
                SourceUiTokens.minTapSize,
              ),
              onPressed: hasSelection ? () => unawaited(onShowBatchMoreActions()) : null,
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                size: SourceUiTokens.actionIconSize,
                color: hasSelection ? enabledColor : disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
