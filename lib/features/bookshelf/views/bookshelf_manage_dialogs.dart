import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../source/models/book_source.dart';
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
      BookshelfManageGroupSelectDialogState();
}

class BookshelfManageGroupSelectDialogState
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
      BookshelfManageSourcePickerViewState();
}

class BookshelfManageSourcePickerViewState
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
