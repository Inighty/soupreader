import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../source/models/book_source.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';
class BookshelfManageGroupSelectDialog extends StatefulWidget {
  const BookshelfManageGroupSelectDialog({
    super.key,
    required this.groups,
    required this.initialGroupBits,
  });

  final List<BookshelfBookGroup> groups;
  final int initialGroupBits;

  @override
  State<BookshelfManageGroupSelectDialog> createState() =>
      _BookshelfManageGroupSelectDialogState();
}

class _BookshelfManageGroupSelectDialogState
    extends State<BookshelfManageGroupSelectDialog> {
  late int _selectedGroupBits;

  @override
  void initState() {
    super.initState();
    _selectedGroupBits = widget.initialGroupBits;
  }

  bool _isGroupChecked(int groupId) {
    return (_selectedGroupBits & groupId) > 0;
  }

  void _toggleGroup(BookshelfBookGroup group, bool checked) {
    setState(() {
      if (checked) {
        _selectedGroupBits += group.groupId;
      } else {
        _selectedGroupBits -= group.groupId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoAlertDialog(
      title: const Text('选择分组'),
      content: SizedBox(
        width: double.maxFinite,
        height: 280,
        child: widget.groups.isEmpty
            ? Center(
                child: Text(
                  '暂无分组',
                  style: TextStyle(color: secondaryColor),
                ),
              )
            : CupertinoScrollbar(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: widget.groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final group = widget.groups[index];
                    final checked = _isGroupChecked(group.groupId);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleGroup(group, !checked),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.groupName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              checked
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              size: 18,
                              color: checked
                                  ? CupertinoColors.activeBlue.resolveFrom(
                                      context,
                                    )
                                  : secondaryColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(_selectedGroupBits),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class SelectionSummaryBar extends StatelessWidget {
  const SelectionSummaryBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.allVisibleSelected,
    required this.changingSource,
    required this.clearingCache,
    required this.updatingCanUpdate,
    required this.addingToGroup,
    required this.deletingSelection,
    required this.onToggleSelectAll,
    required this.onClearSelection,
    required this.onBatchChangeSource,
    required this.onClearCache,
    required this.onEnableUpdate,
    required this.onDisableUpdate,
    required this.onAddToGroup,
    required this.onCheckSelectedInterval,
    required this.onDeleteSelection,
  });

  final int selectedCount;
  final int totalCount;
  final bool allVisibleSelected;
  final bool changingSource;
  final bool clearingCache;
  final bool updatingCanUpdate;
  final bool addingToGroup;
  final bool deletingSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onBatchChangeSource;
  final VoidCallback? onClearCache;
  final VoidCallback? onEnableUpdate;
  final VoidCallback? onDisableUpdate;
  final VoidCallback? onAddToGroup;
  final VoidCallback? onCheckSelectedInterval;
  final VoidCallback? onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final textColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已选 $selectedCount / $totalCount',
            style: TextStyle(
              fontSize: 13,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onToggleSelectAll,
                child: Text(allVisibleSelected ? '取消全选' : '全选'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onClearSelection,
                child: const Text('清空'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton.filled(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(28, 28),
                onPressed: onBatchChangeSource,
                child: changingSource
                    ? const CupertinoActivityIndicator()
                    : const Text('批量换源'),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onClearCache,
                child: clearingCache
                    ? const CupertinoActivityIndicator()
                    : const Text('清理缓存'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onDeleteSelection,
                child: deletingSelection
                    ? const CupertinoActivityIndicator()
                    : Text(
                        '删除',
                        style: TextStyle(
                          color: CupertinoColors.destructiveRed
                              .resolveFrom(context),
                        ),
                      ),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onEnableUpdate,
                child: updatingCanUpdate
                    ? const CupertinoActivityIndicator()
                    : const Text('允许更新'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onDisableUpdate,
                child: updatingCanUpdate
                    ? const CupertinoActivityIndicator()
                    : const Text('禁止更新'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onAddToGroup,
                child: addingToGroup
                    ? const CupertinoActivityIndicator()
                    : const Text('加入分组'),
                minimumSize: Size(28, 28),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: onCheckSelectedInterval,
                child: const Text('选中所选区间'),
                minimumSize: Size(28, 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BookSelectionTile extends StatelessWidget {
  const BookSelectionTile({
    super.key,
    required this.book,
    required this.selected,
    required this.sourceLabel,
    required this.titleTapOpensDetail,
    this.onTitleTap,
    this.onTap,
  });

  final Book book;
  final bool selected;
  final String sourceLabel;
  final bool titleTapOpensDetail;
  final VoidCallback? onTitleTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = CupertinoColors.activeBlue.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final bgColor = selected
        ? activeColor.withValues(alpha: 0.12)
        : CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final borderColor =
        selected ? activeColor.withValues(alpha: 0.45) : separator;
    final author = book.author.trim().isEmpty ? '未知作者' : book.author.trim();
    final titleText = Text(
      book.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选择圆圈
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 20,
                color: selected
                    ? activeColor
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(width: 10),
            // 封面图（对齐 legado 66×90）
            AppCoverImage(
              urlOrPath: book.coverUrl,
              title: book.title,
              author: book.author,
              width: 48,
              height: 67,
              borderRadius: 6,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleTapOpensDetail && onTitleTap != null
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onTitleTap,
                          child: titleText,
                        )
                      : titleText,
                  const SizedBox(height: 3),
                  Text(
                    '$author · $sourceLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookshelfManageSourcePickerView extends StatefulWidget {
  const BookshelfManageSourcePickerView({
    super.key,
    required this.sources,
    required this.initialDelaySeconds,
    required this.onDelayChanged,
  });

  final List<BookSource> sources;
  final int initialDelaySeconds;
  final Future<void> Function(int seconds) onDelayChanged;

  @override
  State<BookshelfManageSourcePickerView> createState() =>
      _BookshelfManageSourcePickerViewState();
}

class _BookshelfManageSourcePickerViewState
    extends State<BookshelfManageSourcePickerView> {
  String _query = '';
  final TextEditingController _queryController = TextEditingController();
  late int _delaySeconds;
  bool _updatingDelay = false;

  @override
  void initState() {
    super.initState();
    _delaySeconds = _normalizeDelaySeconds(widget.initialDelaySeconds);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<BookSource> get _filteredSources {
    final keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return widget.sources;
    return widget.sources.where((source) {
      final name = source.bookSourceName.toLowerCase();
      final url = source.bookSourceUrl.toLowerCase();
      final group = (source.bookSourceGroup ?? '').toLowerCase();
      final comment = (source.bookSourceComment ?? '').toLowerCase();
      return name.contains(keyword) ||
          url.contains(keyword) ||
          group.contains(keyword) ||
          comment.contains(keyword);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSources;

    return AppCupertinoPageScaffold(
      title: '选择书源',
      trailing: AppNavBarButton(
        onPressed: _updatingDelay ? null : _showMoreMenu,
        child: _updatingDelay
            ? const CupertinoActivityIndicator(radius: 8)
            : const Icon(CupertinoIcons.ellipsis_circle, size: 22),
      ),
      child: Column(
        children: [
          Padding(
            padding: AppManageSearchField.outerPadding,
            child: AppManageSearchField(
              controller: _queryController,
              placeholder: '搜索书源',
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  '换源间隔：$_delaySeconds 秒',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '共 ${filtered.length} 条',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const AppEmptyState(
                    illustration: AppEmptyPlanetIllustration(size: 82),
                    title: '没有匹配的书源',
                    message: '请尝试其他关键字',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final source = filtered[index];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(source),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: CupertinoColors
                                .secondarySystemGroupedBackground
                                .resolveFrom(context),
                            borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _sourceDisplayName(source),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      source.bookSourceUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: CupertinoColors.secondaryLabel.resolveFrom(context)
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _sourceDisplayName(BookSource source) {
    final group = (source.bookSourceGroup ?? '').trim();
    if (group.isEmpty) return source.bookSourceName;
    return '${source.bookSourceName} · $group';
  }

  int _normalizeDelaySeconds(int value) {
    return value.clamp(0, 9999).toInt();
  }

  void _showMoreMenu() {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(_changeSourceDelay());
              },
              child: Text('换源间隔（$_delaySeconds秒）'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _changeSourceDelay() async {
    if (_updatingDelay) return;
    final picked = await _showChangeSourceDelayPicker();
    if (!mounted || picked == null) return;
    final next = _normalizeDelaySeconds(picked);
    if (next == _delaySeconds) return;
    setState(() => _updatingDelay = true);
    try {
      await widget.onDelayChanged(next);
      if (!mounted) return;
      setState(() => _delaySeconds = next);
    } finally {
      if (mounted) {
        setState(() => _updatingDelay = false);
      }
    }
  }

  Future<int?> _showChangeSourceDelayPicker() async {
    final initialValue = _normalizeDelaySeconds(_delaySeconds);
    final pickerController = FixedExtentScrollController(
      initialItem: initialValue,
    );
    var selectedValue = initialValue;
    final result = await showCupertinoBottomSheetDialog<int>(
      context: context,
      builder: (sheetContext) {
        final theme = CupertinoTheme.of(sheetContext);
        final backgroundColor = theme.scaffoldBackgroundColor;
        return Container(
          height: 320,
          color: backgroundColor,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            '换源间隔',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(selectedValue),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: CupertinoPicker.builder(
                    itemExtent: 36,
                    scrollController: pickerController,
                    onSelectedItemChanged: (index) {
                      selectedValue = index;
                    },
                    childCount: 10000,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Text('$index 秒'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    pickerController.dispose();
    return result;
  }
}
