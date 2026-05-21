// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_sheet_header.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'bookshelf_layout_options.dart';
import 'bookshelf_sort_layout_engine.dart';
import 'bookshelf_view.dart';

extension BookshelfLayoutDialog on BookshelfViewState {
  Future<void> showLayoutConfigDialog() async {
    final settings = settingsService.appSettings;
    var groupStyle = settings.bookshelfGroupStyle.clamp(0, 1);
    var showUnread = settings.bookshelfShowUnread;
    var showLastUpdateTime = settings.bookshelfShowLastUpdateTime;
    var showWaitUpCount = settings.bookshelfShowWaitUpCount;
    var showFastScroller = settings.bookshelfShowFastScroller;
    var layoutIndex = normalizeLayoutIndex(settings.bookshelfLayoutIndex);
    var sortIndex = normalizeSortIndex(settings.bookshelfSortIndex);

    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark =
                CupertinoTheme.of(context).brightness == Brightness.dark;
            final bg = isDark
                ? CupertinoColors.systemGroupedBackground
                    .resolveFrom(context)
                    .darkColor
                : CupertinoColors.systemGroupedBackground
                    .resolveFrom(context)
                    .color;
            final h = MediaQuery.sizeOf(context).height;
            final secondaryLabel =
                CupertinoColors.secondaryLabel.resolveFrom(context);
            final primaryColor = CupertinoTheme.of(context).primaryColor;

            Widget hdr(String t) => Text(
                  t,
                  style: TextStyle(
                    color: secondaryLabel,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                );

            Widget sw(String title, bool value, ValueChanged<bool> cb) =>
                AppListTile(
                  title: Text(
                    title,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 15,
                    ),
                  ),
                  trailing: CupertinoSwitch(
                    value: value,
                    activeTrackColor: primaryColor,
                    onChanged: cb,
                  ),
                  onTap: () => cb(!value),
                  showChevron: false,
                );

            Widget choiceRow(String label, bool selected, VoidCallback onTap) =>
                AppListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 15,
                    ),
                  ),
                  trailing: selected
                      ? Icon(
                          CupertinoIcons.check_mark,
                          size: 17,
                          color: primaryColor,
                        )
                      : null,
                  onTap: onTap,
                  showChevron: false,
                );

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDesignTokens.radiusSheet),
              ),
              child: Container(
                color: bg,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppSheetHeader(title: '书架布局'),
                      SizedBox(
                        height: h * 0.62,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            AppListSection(
                              header: hdr('分组样式'),
                              hasLeading: false,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: CupertinoSlidingSegmentedControl<int>(
                                    groupValue: groupStyle,
                                    children: const {
                                      0: Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 7),
                                        child: Text('样式一',
                                            textAlign: TextAlign.center),
                                      ),
                                      1: Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 7),
                                        child: Text('样式二',
                                            textAlign: TextAlign.center),
                                      ),
                                    },
                                    onValueChanged: (value) {
                                      if (value == null) return;
                                      setDialogState(() => groupStyle = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            AppListSection(
                              header: hdr('显示'),
                              hasLeading: false,
                              children: [
                                sw(
                                    '显示未读数量',
                                    showUnread,
                                    (v) =>
                                        setDialogState(() => showUnread = v)),
                                sw(
                                    '显示最新更新时间',
                                    showLastUpdateTime,
                                    (v) => setDialogState(
                                        () => showLastUpdateTime = v)),
                                sw(
                                    '显示待更新计数',
                                    showWaitUpCount,
                                    (v) => setDialogState(
                                        () => showWaitUpCount = v)),
                                sw(
                                    '显示快速滚动条',
                                    showFastScroller,
                                    (v) => setDialogState(
                                        () => showFastScroller = v)),
                              ],
                            ),
                            AppListSection(
                              header: hdr('视图'),
                              hasLeading: false,
                              children: [
                                for (var i = 0; i <= 4; i++)
                                  choiceRow(
                                    layoutLabel(i),
                                    layoutIndex == i,
                                    () => setDialogState(() => layoutIndex = i),
                                  ),
                              ],
                            ),
                            AppListSection(
                              header: hdr('排序'),
                              hasLeading: false,
                              children: [
                                for (var i = 0; i <= 5; i++)
                                  choiceRow(
                                    legacySortLabel(i),
                                    sortIndex == i,
                                    () => setDialogState(() => sortIndex = i),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                color: CupertinoColors.systemFill
                                    .resolveFrom(context)
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(
                                    AppDesignTokens.radiusControl),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                onPressed: () => Navigator.pop(sheetContext),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                    color: CupertinoColors.label
                                        .resolveFrom(context)
                                        .resolveFrom(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CupertinoButton(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(
                                    AppDesignTokens.radiusControl),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await applyLayoutConfig(
                                    groupStyle: groupStyle,
                                    showUnread: showUnread,
                                    showLastUpdateTime: showLastUpdateTime,
                                    showWaitUpCount: showWaitUpCount,
                                    showFastScroller: showFastScroller,
                                    layoutIndex: layoutIndex,
                                    sortIndex: sortIndex,
                                  );
                                },
                                child: const Text(
                                  '确定',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
