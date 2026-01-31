import 'package:flutter/cupertino.dart';
import '../models/book_source.dart';
import '../../../app/theme/colors.dart';

/// 书源管理页面 - iOS 原生风格
class SourceListView extends StatefulWidget {
  const SourceListView({super.key});

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  String _selectedGroup = '全部';
  final List<String> _groups = ['全部', '小说', '漫画', '有声', '失效'];

  final List<BookSource> _sources = [
    BookSource(
      bookSourceUrl: 'https://www.example1.com',
      bookSourceName: '笔趣阁',
      bookSourceGroup: '小说',
      enabled: true,
    ),
    BookSource(
      bookSourceUrl: 'https://www.example2.com',
      bookSourceName: '起点中文网',
      bookSourceGroup: '小说',
      enabled: true,
    ),
    BookSource(
      bookSourceUrl: 'https://www.example3.com',
      bookSourceName: '番茄小说',
      bookSourceGroup: '小说',
      enabled: false,
    ),
    BookSource(
      bookSourceUrl: 'https://www.example4.com',
      bookSourceName: '喜马拉雅',
      bookSourceGroup: '有声',
      enabled: true,
    ),
  ];

  List<BookSource> get _filteredSources {
    if (_selectedGroup == '全部') return _sources;
    if (_selectedGroup == '失效') {
      return _sources.where((s) => !s.enabled).toList();
    }
    return _sources.where((s) => s.bookSourceGroup == _selectedGroup).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书源管理'),
        backgroundColor: const Color(0xE6121212),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child:
                  const Icon(CupertinoIcons.plus, color: CupertinoColors.white),
              onPressed: _showImportOptions,
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.ellipsis_vertical,
                  color: CupertinoColors.white),
              onPressed: _showMoreOptions,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 分组筛选
            _buildGroupFilter(),
            // 书源列表
            Expanded(
              child: _filteredSources.isEmpty
                  ? _buildEmptyState()
                  : _buildSourceList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupFilter() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = _groups[index];
          final isSelected = group == _selectedGroup;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedGroup = group);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                group,
                style: TextStyle(
                  color: isSelected
                      ? CupertinoColors.black
                      : CupertinoColors.white,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.cloud,
            size: 64,
            color: CupertinoColors.systemGrey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无书源',
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            child: const Text('导入书源'),
            onPressed: _showImportOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredSources.length,
      itemBuilder: (context, index) {
        final source = _filteredSources[index];
        return _buildSourceItem(source);
      },
    );
  }

  Widget _buildSourceItem(BookSource source) {
    return GestureDetector(
      onTap: () => _onSourceTap(source),
      onLongPress: () => _onSourceLongPress(source),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: source.enabled
                    ? AppColors.accent.withOpacity(0.15)
                    : CupertinoColors.systemGrey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.globe,
                color: source.enabled
                    ? AppColors.accent
                    : CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.bookSourceName,
                    style: TextStyle(
                      color: source.enabled
                          ? CupertinoColors.white
                          : CupertinoColors.systemGrey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source.bookSourceGroup ?? '未分组',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // 开关
            CupertinoSwitch(
              value: source.enabled,
              activeTrackColor: AppColors.accent,
              onChanged: (value) {
                setState(() {
                  final index = _sources.indexOf(source);
                  _sources[index] = source.copyWith(enabled: value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImportOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('导入书源'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('从剪贴板导入'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从文件导入'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从网络导入'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('全选'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出书源'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('检查可用性'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除失效书源'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _onSourceTap(BookSource source) {
    // TODO: 编辑书源
  }

  void _onSourceLongPress(BookSource source) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('编辑书源'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('置顶'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('分享'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () {
              Navigator.pop(context);
              _deleteSource(source);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _deleteSource(BookSource source) {
    setState(() {
      _sources.removeWhere((s) => s.bookSourceUrl == source.bookSourceUrl);
    });
  }
}
