import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView, ReorderableDragStartListener;

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/bookshelf_book_group.dart';
import '../services/bookshelf_book_group_store.dart';
import 'bookshelf_group_edit_dialog.dart';

export 'bookshelf_group_edit_dialog.dart' show BookshelfGroupEditDraft;

class BookshelfGroupManagePlaceholderDialog extends StatefulWidget {
  const BookshelfGroupManagePlaceholderDialog({super.key});

  @override
  State<BookshelfGroupManagePlaceholderDialog> createState() =>
      _BookshelfGroupManagePlaceholderDialogState();
}

class _BookshelfGroupManagePlaceholderDialogState
    extends State<BookshelfGroupManagePlaceholderDialog> {
  final BookshelfBookGroupStore _groupStore = BookshelfBookGroupStore();

  List<BookshelfBookGroup> _groups = const <BookshelfBookGroup>[];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadGroups(showLoading: true);
  }

  Future<void> _loadGroups({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }
    try {
      final groups = await _groupStore.getGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.load.failed',
        message: '分组管理加载分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await _showHintDialog('加载分组失败：$error');
    }
  }

  Future<void> _handleAddGroup() async {
    if (_adding) return;
    bool canAdd = false;
    try {
      canAdd = await _groupStore.canAddGroup();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.menu_add.check_limit_failed',
        message: '检查分组数量上限失败',
        error: error,
        stackTrace: stackTrace,
      );
      await _showHintDialog('添加分组失败：$error');
      return;
    }
    if (!canAdd) {
      await _showHintDialog('分组已达上限(64个)');
      return;
    }
    final draft = await _showEditGroupDialog(null);
    if (draft == null) return;
    setState(() => _adding = true);
    try {
      await _groupStore.addGroup(
        draft.groupName,
        cover: draft.coverPath,
        bookSort: draft.bookSort,
        enableRefresh: draft.enableRefresh,
      );
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.menu_add.failed',
        message: '添加分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHintDialog('添加分组失败：$error');
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _handleEditGroup(BookshelfBookGroup group) async {
    final draft = await _showEditGroupDialog(group);
    if (draft == null) return;
    try {
      final updated = group.copyWith(
        groupName: draft.groupName,
        cover: draft.coverPath,
        clearCover: draft.coverPath == null && group.cover != null,
        bookSort: draft.bookSort,
        enableRefresh: draft.enableRefresh,
      );
      await _groupStore.updateGroup(updated);
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.edit.failed',
        message: '编辑分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHintDialog('编辑分组失败：$error');
    }
  }

  Future<void> _handleToggleShow(BookshelfBookGroup group, bool show) async {
    try {
      await _groupStore.updateGroup(group.copyWith(show: show));
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.toggle_show.failed',
        message: '切换分组显示失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleDeleteGroup(BookshelfBookGroup group) async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除分组'),
        content: Text('\n确定要删除分组「${group.groupName}」吗？书籍不会被删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _groupStore.deleteGroup(group.groupId);
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.delete.failed',
        message: '删除分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHintDialog('删除分组失败：$error');
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final mutable = List<BookshelfBookGroup>.from(_groups);
    final moved = mutable.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    mutable.insert(insertAt, moved);
    // 重新分配 order：保留内置分组原始顺序，仅对自定义分组重排
    var customOrder = 0;
    final reordered = mutable.map((g) {
      if (g.isCustomGroup) {
        return g.copyWith(order: customOrder++);
      }
      return g;
    }).toList();
    setState(() => _groups = reordered);
    try {
      await _groupStore.saveGroups(reordered);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.reorder.failed',
        message: '分组排序保存失败',
        error: error,
        stackTrace: stackTrace,
      );
      await _loadGroups(showLoading: false);
    }
  }

  Future<BookshelfGroupEditDraft?> _showEditGroupDialog(
    BookshelfBookGroup? existing,
  ) {
    return showCupertinoBottomSheetDialog<BookshelfGroupEditDraft>(
      context: context,
      builder: (dialogContext) => BookshelfGroupEditDialog(existing: existing),
    );
  }

  Future<void> _showHintDialog(String message) {
    return showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 520.0);
    final height = math.min(screenSize.height * 0.82, 620.0);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final secondaryTextColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return Center(
      child: CupertinoPopupSurface(
        child: SizedBox(
          width: width,
          height: height,
          child: CupertinoPageScaffold(
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _GroupManageHeader(
                    adding: _adding,
                    onAdd: _handleAddGroup,
                    onClose: () => Navigator.pop(context),
                  ),
                  Container(height: 0.5, color: separatorColor),
                  Expanded(
                    child: _loading
                        ? const Center(child: CupertinoActivityIndicator())
                        : _groups.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无分组',
                                  style: TextStyle(color: secondaryTextColor),
                                ),
                              )
                            : ReorderableListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 4, 0, 8),
                                itemCount: _groups.length,
                                onReorder: _handleReorder,
                                buildDefaultDragHandles: false,
                                itemBuilder: (context, index) {
                                  final group = _groups[index];
                                  return _GroupManageRow(
                                    key: ValueKey(group.groupId),
                                    group: group,
                                    index: index,
                                    separatorColor: separatorColor,
                                    onToggleShow: (show) =>
                                        _handleToggleShow(group, show),
                                    onEdit: () => _handleEditGroup(group),
                                    onDelete: group.isCustomGroup
                                        ? () => _handleDeleteGroup(group)
                                        : null,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupManageHeader extends StatelessWidget {
  const _GroupManageHeader({
    required this.adding,
    required this.onAdd,
    required this.onClose,
  });

  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size(34, 34),
            onPressed: onClose,
            child: const Text('完成'),
          ),
          const Expanded(
            child: Text(
              '分组管理',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minimumSize: Size(34, 34),
            onPressed: adding ? null : onAdd,
            child: adding
                ? const CupertinoActivityIndicator(radius: 8)
                : const Icon(CupertinoIcons.add),
          ),
        ],
      ),
    );
  }
}

class _GroupManageRow extends StatelessWidget {
  const _GroupManageRow({
    super.key,
    required this.group,
    required this.index,
    required this.separatorColor,
    required this.onToggleShow,
    required this.onEdit,
    this.onDelete,
  });

  final BookshelfBookGroup group;
  final int index;
  final Color separatorColor;
  final ValueChanged<bool> onToggleShow;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accentColor = CupertinoTheme.of(context).primaryColor;
    final tertiaryLabel =
        CupertinoColors.tertiaryLabel.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (group.isCustomGroup)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        CupertinoIcons.bars,
                        size: 18,
                        color: tertiaryLabel,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 26),
                Expanded(
                  child: Text(
                    group.manageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                if (onDelete != null)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size(36, 36),
                    onPressed: onDelete,
                    child: Text(
                      '删除',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                  ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size(36, 36),
                  onPressed: onEdit,
                  child: Text(
                    '编辑',
                    style: TextStyle(fontSize: 14, color: accentColor),
                  ),
                ),
                CupertinoSwitch(
                  value: group.show,
                  onChanged: onToggleShow,
                ),
              ],
            ),
          ),
        ),
        Container(height: 0.5, color: separatorColor),
      ],
    );
  }
}
