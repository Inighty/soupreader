import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/bookshelf_book_group.dart';

/// 用户编辑分组时返回的草稿。
class BookshelfGroupEditDraft {
  const BookshelfGroupEditDraft({
    required this.groupName,
    required this.bookSort,
    required this.enableRefresh,
    this.coverPath,
  });

  final String groupName;
  final String? coverPath;
  final int bookSort;
  final bool enableRefresh;
}

class BookshelfGroupSortOption {
  const BookshelfGroupSortOption(this.value, this.label);

  final int value;
  final String label;
}

const List<BookshelfGroupSortOption> bookshelfGroupSortOptions =
    <BookshelfGroupSortOption>[
  BookshelfGroupSortOption(-1, '默认'),
  BookshelfGroupSortOption(0, '按阅读时间'),
  BookshelfGroupSortOption(1, '按更新时间'),
  BookshelfGroupSortOption(2, '按书名'),
  BookshelfGroupSortOption(3, '手动排序'),
  BookshelfGroupSortOption(4, '综合排序'),
  BookshelfGroupSortOption(5, '按作者'),
];

String bookshelfGroupSortLabel(int value) {
  for (final option in bookshelfGroupSortOptions) {
    if (option.value == value) return option.label;
  }
  return '默认';
}

/// 添加 / 编辑书架分组对话框。
class BookshelfGroupEditDialog extends StatefulWidget {
  const BookshelfGroupEditDialog({super.key, this.existing});

  final BookshelfBookGroup? existing;

  @override
  State<BookshelfGroupEditDialog> createState() =>
      _BookshelfGroupEditDialogState();
}

class _BookshelfGroupEditDialogState extends State<BookshelfGroupEditDialog> {
  late final TextEditingController _groupNameController;

  String? _coverPath;
  late int _bookSort;
  late bool _enableRefresh;
  bool _pickingCover = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _groupNameController =
        TextEditingController(text: existing?.groupName ?? '');
    _coverPath = existing?.cover;
    _bookSort = existing?.bookSort ?? -1;
    _enableRefresh = existing?.enableRefresh ?? true;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_pickingCover) return;
    setState(() => _pickingCover = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final selected =
          (result.files.first.path ?? result.files.first.name).trim();
      if (selected.isEmpty) return;
      setState(() {
        _coverPath = selected;
        _errorText = null;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.edit.pick_cover_failed',
        message: '选择分组封面失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _errorText = '选择封面失败：$error');
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  Future<void> _pickSort() async {
    final selected = await showCupertinoBottomSheetDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('排序'),
        actions: [
          for (final option in bookshelfGroupSortOptions)
            CupertinoActionSheetAction(
              isDefaultAction: option.value == _bookSort,
              onPressed: () => Navigator.pop(popupContext, option.value),
              child: Text(option.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _bookSort = selected);
  }

  void _submit() {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      setState(() => _errorText = '分组名称不能为空');
      return;
    }
    Navigator.pop(
      context,
      BookshelfGroupEditDraft(
        groupName: groupName,
        coverPath:
            (_coverPath ?? '').trim().isEmpty ? null : _coverPath!.trim(),
        bookSort: _bookSort,
        enableRefresh: _enableRefresh,
      ),
    );
  }

  String _coverDisplayName() {
    final path = (_coverPath ?? '').trim();
    if (path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    if (slashIndex < 0 || slashIndex == normalized.length - 1) {
      return normalized;
    }
    return normalized.substring(slashIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final destructiveColor = CupertinoColors.systemRed.resolveFrom(context);
    return CupertinoAlertDialog(
      title: Text(_isEditing ? '编辑分组' : '添加分组'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: _groupNameController,
              placeholder: '分组名称',
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: Text('封面')),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size(26, 26),
                  onPressed: _pickingCover ? null : _pickCover,
                  child: _pickingCover
                      ? const CupertinoActivityIndicator(radius: 7)
                      : const Text('选择封面'),
                ),
                if ((_coverPath ?? '').trim().isNotEmpty)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size(26, 26),
                    onPressed: () => setState(() {
                      _coverPath = null;
                      _errorText = null;
                    }),
                    child: Text(
                      '清除',
                      style: TextStyle(color: destructiveColor),
                    ),
                  ),
              ],
            ),
            if ((_coverPath ?? '').trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _coverDisplayName(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('排序')),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size(26, 26),
                  onPressed: _pickSort,
                  child: Text(bookshelfGroupSortLabel(_bookSort)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('允许下拉刷新')),
                CupertinoSwitch(
                  value: _enableRefresh,
                  onChanged: (value) =>
                      setState(() => _enableRefresh = value),
                ),
              ],
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    color: destructiveColor,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
