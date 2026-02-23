import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../core/services/exception_log_service.dart';
import '../models/bookshelf_book_group.dart';
import '../services/bookshelf_book_group_store.dart';

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
    final groupName = await _showAddGroupDialog();
    if (groupName == null) return;
    setState(() => _adding = true);
    try {
      await _groupStore.addGroup(groupName);
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

  Future<String?> _showAddGroupDialog() async {
    final controller = TextEditingController();
    String? errorText;
    try {
      return await showCupertinoDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return CupertinoAlertDialog(
                title: const Text('添加分组'),
                content: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoTextField(
                        controller: controller,
                        placeholder: '分组名称',
                        autofocus: true,
                      ),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        setDialogState(() => errorText = '分组名称不能为空');
                        return;
                      }
                      Navigator.pop(dialogContext, name);
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showHintDialog(String message) {
    return showCupertinoDialog<void>(
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 34),
                        const Expanded(
                          child: Text(
                            '分组管理',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          minSize: 30,
                          onPressed: _adding ? null : _handleAddGroup,
                          child: _adding
                              ? const CupertinoActivityIndicator(radius: 8)
                              : const Icon(CupertinoIcons.add),
                        ),
                      ],
                    ),
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
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                itemCount: _groups.length,
                                separatorBuilder: (_, __) => Container(
                                  height: 0.5,
                                  color: separatorColor,
                                ),
                                itemBuilder: (context, index) {
                                  final group = _groups[index];
                                  return SizedBox(
                                    height: 44,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            group.manageName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  Container(height: 0.5, color: separatorColor),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minSize: 30,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('完成'),
                      ),
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
