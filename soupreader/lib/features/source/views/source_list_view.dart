import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../../../app/theme/colors.dart';

/// 书源管理页面
class SourceListView extends StatefulWidget {
  const SourceListView({super.key});

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  // 示例书源数据
  final List<BookSource> _sources = [
    BookSource(
      bookSourceName: '起点中文网',
      bookSourceUrl: 'https://www.qidian.com',
      bookSourceGroup: '正版',
      enabled: true,
      weight: 100,
    ),
    BookSource(
      bookSourceName: '纵横中文网',
      bookSourceUrl: 'https://www.zongheng.com',
      bookSourceGroup: '正版',
      enabled: true,
      weight: 90,
    ),
    BookSource(
      bookSourceName: '晋江文学城',
      bookSourceUrl: 'https://www.jjwxc.net',
      bookSourceGroup: '正版',
      enabled: false,
      weight: 80,
    ),
    BookSource(
      bookSourceName: '笔趣阁',
      bookSourceUrl: 'https://www.biquge.com',
      bookSourceGroup: '盗版',
      enabled: true,
      weight: 50,
    ),
  ];

  String _searchQuery = '';
  String? _selectedGroup;

  List<BookSource> get _filteredSources {
    return _sources.where((source) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          source.bookSourceName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          source.bookSourceUrl.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesGroup =
          _selectedGroup == null || source.bookSourceGroup == _selectedGroup;

      return matchesSearch && matchesGroup;
    }).toList();
  }

  List<String> get _groups {
    return _sources
        .map((s) => s.bookSourceGroup)
        .where((g) => g != null)
        .cast<String>()
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _showSearch),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 12),
                    Text('导入书源'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, size: 20),
                    SizedBox(width: 12),
                    Text('导出书源'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'network',
                child: Row(
                  children: [
                    Icon(Icons.cloud_download, size: 20),
                    SizedBox(width: 12),
                    Text('网络导入'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'enable_all',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 12),
                    Text('全部启用'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'disable_all',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('全部禁用'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildGroupFilter(),
        ),
      ),
      body: _filteredSources.isEmpty ? _buildEmptyState() : _buildSourceList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSource,
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('全部', null),
          ..._groups.map((group) => _buildFilterChip(group, group)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? group) {
    final isSelected = _selectedGroup == group;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedGroup = selected ? group : null;
          });
        },
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: AppColors.accent.withOpacity(0.2),
        checkmarkColor: AppColors.accent,
        labelStyle: TextStyle(color: isSelected ? AppColors.accent : null),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.source_outlined,
            size: 80,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无书源',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角添加书源',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _filteredSources.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final source = _filteredSources[index];
        return _buildSourceItem(source, key: ValueKey(source.id));
      },
    );
  }

  Widget _buildSourceItem(BookSource source, {Key? key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: source.enabled
                ? AppColors.accent.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.language,
            color: source.enabled ? AppColors.accent : Colors.grey,
          ),
        ),
        title: Text(
          source.bookSourceName,
          style: TextStyle(color: source.enabled ? null : AppColors.textMuted),
        ),
        subtitle: Text(
          source.bookSourceUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted.withOpacity(source.enabled ? 1 : 0.5),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (source.bookSourceGroup != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  source.bookSourceGroup!,
                  style: const TextStyle(fontSize: 10, color: AppColors.accent),
                ),
              ),
            const SizedBox(width: 8),
            Switch(
              value: source.enabled,
              activeColor: AppColors.accent,
              onChanged: (value) => _toggleSource(source, value),
            ),
          ],
        ),
        onTap: () => _editSource(source),
        onLongPress: () => _showSourceActions(source),
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _sources.removeAt(oldIndex);
      _sources.insert(newIndex, item);
    });
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: _SourceSearchDelegate(sources: _sources, onSelect: _editSource),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'import':
        _importSources();
        break;
      case 'export':
        _exportSources();
        break;
      case 'network':
        _networkImport();
        break;
      case 'enable_all':
        _setAllEnabled(true);
        break;
      case 'disable_all':
        _setAllEnabled(false);
        break;
    }
  }

  void _importSources() {
    // TODO: 实现导入功能
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('导入功能开发中...')));
  }

  void _exportSources() {
    // TODO: 实现导出功能
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('导出功能开发中...')));
  }

  void _networkImport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('网络导入'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: '输入书源URL或JSON',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 解析并导入
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _setAllEnabled(bool enabled) {
    setState(() {
      for (int i = 0; i < _sources.length; i++) {
        _sources[i] = _sources[i].copyWith(enabled: enabled);
      }
    });
  }

  void _toggleSource(BookSource source, bool enabled) {
    setState(() {
      final index = _sources.indexWhere((s) => s.id == source.id);
      if (index != -1) {
        _sources[index] = source.copyWith(enabled: enabled);
      }
    });
  }

  void _addSource() {
    // TODO: 添加书源页面
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('添加书源功能开发中...')));
  }

  void _editSource(BookSource source) {
    // TODO: 编辑书源页面
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('编辑书源: ${source.bookSourceName}')));
  }

  void _showSourceActions(BookSource source) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                _editSource(source);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 复制书源
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('测试'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 测试书源
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('删除', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteSource(source);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSource(BookSource source) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除书源「${source.bookSourceName}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _sources.removeWhere((s) => s.id == source.id);
              });
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 书源搜索代理
class _SourceSearchDelegate extends SearchDelegate<BookSource?> {
  final List<BookSource> sources;
  final Function(BookSource) onSelect;

  _SourceSearchDelegate({required this.sources, required this.onSelect});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = sources.where((source) {
      return source.bookSourceName.toLowerCase().contains(
            query.toLowerCase(),
          ) ||
          source.bookSourceUrl.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final source = results[index];
        return ListTile(
          leading: const Icon(Icons.language),
          title: Text(source.bookSourceName),
          subtitle: Text(source.bookSourceUrl),
          onTap: () {
            close(context, source);
            onSelect(source);
          },
        );
      },
    );
  }
}
