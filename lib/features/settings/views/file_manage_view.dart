import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import 'file_manage_delete_error.dart';
import 'file_manage_helpers.dart';

class FileManageView extends StatefulWidget {
  const FileManageView({super.key});

  @override
  State<FileManageView> createState() => _FileManageViewState();
}

class _FileManageViewState extends State<FileManageView> {
  Directory? _rootDir;
  List<Directory> _subDirs = <Directory>[];
  List<FileSystemEntity> _entities = <FileSystemEntity>[];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;
  bool _creatingFolder = false;

  Directory? get _currentDir => _subDirs.isNotEmpty ? _subDirs.last : _rootDir;

  @override
  void initState() {
    super.initState();
    _initRootDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initRootDirectory() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      var root = docs.parent;
      if (!await root.exists()) {
        root = docs;
      }
      _rootDir = root;
      await _reloadCurrentDirectory();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      await _showMessage('初始化文件管理失败：$error');
    }
  }

  Future<void> _reloadCurrentDirectory() async {
    final current = _currentDir;
    if (current == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _entities = <FileSystemEntity>[];
      });
      return;
    }
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final children = current.listSync(followLinks: false);
      children.sort(compareFileEntity);
      if (!mounted) return;
      setState(() {
        _entities = children;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await _showMessage('读取目录失败：$error');
    }
  }

  bool get _atRoot => _subDirs.isEmpty;

  List<FileManageListEntry> _buildVisibleEntries() {
    final query = _searchQuery.trim().toLowerCase();
    final result = <FileManageListEntry>[];
    if (!_atRoot && _currentDir != null) {
      result.add(FileManageListEntry.parent(_currentDir!));
    }
    for (final entity in _entities) {
      final name = entityDisplayName(entity).toLowerCase();
      if (query.isNotEmpty && !name.contains(query)) {
        continue;
      }
      result.add(FileManageListEntry.entity(entity));
    }
    return result;
  }

  Future<void> _openRoot() async {
    if (_rootDir == null) return;
    setState(() => _subDirs = <Directory>[]);
    await _reloadCurrentDirectory();
  }

  Future<void> _openDirectory(Directory dir) async {
    setState(() => _subDirs = <Directory>[..._subDirs, dir]);
    await _reloadCurrentDirectory();
  }

  Future<void> _openPathAt(int index) async {
    if (index < 0 || index >= _subDirs.length) return;
    setState(() => _subDirs = _subDirs.take(index + 1).toList(growable: false));
    await _reloadCurrentDirectory();
  }

  Future<bool> _goParent() async {
    if (_atRoot) return false;
    setState(() {
      _subDirs = _subDirs.take(_subDirs.length - 1).toList(growable: false);
    });
    await _reloadCurrentDirectory();
    return true;
  }

  Future<void> _openFile(File file) async {
    try {
      final launched = await launchUrl(
        Uri.file(file.path),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await _showMessage('系统无法打开该文件');
      }
    } catch (error) {
      await _showMessage('打开文件失败：$error');
    }
  }

  Future<void> _showEntityMenu(FileSystemEntity entity) async {
    final selected = await showAppActionListSheet<_FileEntityAction>(
      context: context,
      title: entityDisplayName(entity),
      showCancel: true,
      items: const [
        AppActionListItem<_FileEntityAction>(
          value: _FileEntityAction.delete,
          icon: CupertinoIcons.delete,
          label: '删除',
          isDestructiveAction: true,
        ),
      ],
    );
    if (selected == _FileEntityAction.delete) {
      await _deleteEntity(entity);
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final entityPath = entity.path;
    final displayName = entityDisplayName(entity);
    try {
      final currentType = await FileSystemEntity.type(
        entityPath,
        followLinks: false,
      );
      if (currentType == FileSystemEntityType.notFound) {
        await _showMessage(buildFileDeleteFailureMessage(
          type: FileDeleteFailureType.targetNotFound,
          displayName: displayName,
        ));
        return;
      }
      if (entity is Directory) {
        await entity.delete(recursive: false);
      } else {
        await entity.delete();
      }
      await _reloadCurrentDirectory();
    } on FileSystemException catch (error) {
      await _showMessage(buildFileDeleteFailureMessage(
        type: resolveFileDeleteFailureType(error),
        displayName: displayName,
        detail: buildFileDeleteErrorDetail(error),
      ));
    } catch (error) {
      await _showMessage(buildFileDeleteFailureMessage(
        type: FileDeleteFailureType.otherIo,
        displayName: displayName,
        detail: error.toString(),
      ));
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final current = _currentDir;
    if (current == null || _creatingFolder) return;
    final controller = TextEditingController();
    final folderName = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('新建文件夹'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('默认在当前目录创建子文件夹'),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              placeholder: '文件夹名',
              autofocus: true,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (folderName == null) return;
    await _createFolder(folderName);
  }

  Future<void> _createFolder(String rawName) async {
    final current = _currentDir;
    if (current == null) {
      await _showMessage('创建文件夹失败：当前目录不可用');
      return;
    }
    final name = rawName.trim();
    if (name.isEmpty) {
      await _showMessage('文件夹名不能为空');
      return;
    }
    final invalidReason = validateFolderName(name);
    if (invalidReason != null) {
      await _showMessage(invalidReason);
      return;
    }
    if (!mounted) return;
    setState(() => _creatingFolder = true);
    try {
      final currentPath = current.absolute.path;
      final targetPath = joinFilePath(currentPath, name);
      if (!isChildPath(parentPath: currentPath, childPath: targetPath)) {
        await _showMessage('文件夹名非法');
        return;
      }

      final targetType = await FileSystemEntity.type(
        targetPath,
        followLinks: false,
      );
      if (targetType != FileSystemEntityType.notFound) {
        await _showMessage('创建文件夹失败：名称已存在');
        return;
      }

      await Directory(targetPath).create(recursive: false);
      if (!mounted) return;
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
      await _reloadCurrentDirectory();
    } catch (error) {
      await _showMessage('创建文件夹失败：$error');
    } finally {
      if (mounted) {
        setState(() => _creatingFolder = false);
      }
    }
  }

  Future<void> _onTapEntry(FileManageListEntry entry) async {
    if (entry.isParentEntry) {
      await _goParent();
      return;
    }
    final entity = entry.entity;
    if (entity is Directory) {
      await _openDirectory(entity);
      return;
    }
    if (entity is File) {
      await _openFile(entity);
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Widget _buildPathBar() {
    final pathButtons = <Widget>[
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onPressed: _openRoot,
        child: const Text('root', maxLines: 1, overflow: TextOverflow.ellipsis),
        minimumSize: Size(28, 28),
      ),
    ];
    for (var i = 0; i < _subDirs.length; i++) {
      final dir = _subDirs[i];
      pathButtons.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(CupertinoIcons.chevron_right, size: 12),
        ),
      );
      pathButtons.add(
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onPressed: () => _openPathAt(i),
          child: Text(
            entityDisplayName(dir),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          minimumSize: Size(28, 28),
        ),
      );
    }
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: pathButtons,
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final entries = _buildVisibleEntries();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(left: 52),
        height: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isParent = entry.isParentEntry;
        final entity = entry.entity;
        final isDir = !isParent && entity is Directory;
        final icon = isParent
            ? CupertinoIcons.arrow_uturn_left
            : (isDir ? CupertinoIcons.folder : CupertinoIcons.doc);
        final name = isParent ? '..' : entityDisplayName(entity);
        final sizeText = (!isParent && entity is File)
            ? formatFileBytes(entity.lengthSync())
            : '';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTapEntry(entry),
          onLongPress: isParent ? null : () => _showEntityMenu(entity),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (sizeText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      sizeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '文件管理',
      trailing: AppNavBarButton(
        onPressed: (_currentDir != null && !_creatingFolder)
            ? _showCreateFolderDialog
            : null,
        child: _creatingFolder
            ? const CupertinoActivityIndicator()
            : const Text('新建文件夹'),
      ),
      child: PopScope<void>(
        canPop: _atRoot,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _goParent();
        },
        child: Column(
          children: [
            _buildPathBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: AppManageSearchField(
                controller: _searchController,
                placeholder: '筛选 • 文件管理',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }
}

enum _FileEntityAction { delete }
