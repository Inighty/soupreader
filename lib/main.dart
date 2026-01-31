import 'package:flutter/material.dart';
import 'app/theme/app_theme.dart';
import 'features/bookshelf/views/bookshelf_view.dart';
import 'features/source/views/source_list_view.dart';
import 'features/settings/views/settings_view.dart';
import 'app/theme/colors.dart';

void main() {
  runApp(const SoupReaderApp());
}

/// SoupReader 阅读应用
class SoupReaderApp extends StatelessWidget {
  const SoupReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // 默认深色模式
      home: const MainScreen(),
    );
  }
}

/// 主屏幕（带底部导航）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    BookshelfView(), // 书架
    ExploreView(), // 发现/搜索
    SourceListView(), // 书源
    SettingsView(), // 设置
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: '书架',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: '发现',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.source_outlined),
              activeIcon: Icon(Icons.source),
              label: '书源',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}

/// 发现/探索页面（搜索书籍）
class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _hotKeywords = [
    '斗破苍穹',
    '完美世界',
    '遮天',
    '凡人修仙传',
    '诛仙',
    '盗墓笔记',
    '鬼吹灯',
    '三体',
  ];

  bool _isSearching = false;
  List<Map<String, String>> _searchResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: _buildSearchBar()),
      body: _isSearching ? _buildSearchResults() : _buildExploreContent(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索书籍、作者',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onSubmitted: _onSearch,
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildExploreContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 热门搜索
          Text(
            '热门搜索',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hotKeywords.map((keyword) {
              return ActionChip(
                label: Text(keyword),
                backgroundColor: AppColors.accent.withOpacity(0.1),
                labelStyle: const TextStyle(color: AppColors.accent),
                onPressed: () {
                  _searchController.text = keyword;
                  _onSearch(keyword);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // 分类推荐
          Text(
            '分类',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildCategoryItem(Icons.flash_on, '玄幻'),
              _buildCategoryItem(Icons.favorite, '言情'),
              _buildCategoryItem(Icons.history_edu, '历史'),
              _buildCategoryItem(Icons.science, '科幻'),
              _buildCategoryItem(Icons.sports_martial_arts, '武侠'),
              _buildCategoryItem(Icons.location_city, '都市'),
              _buildCategoryItem(Icons.psychology, '灵异'),
              _buildCategoryItem(Icons.more_horiz, '更多'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _onSearch(label);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              '正在搜索...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Icon(Icons.book, color: AppColors.accent),
              ),
            ),
            title: Text(book['title'] ?? ''),
            subtitle: Text(book['author'] ?? ''),
            trailing: ElevatedButton(
              onPressed: () {
                // TODO: 添加到书架
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加《${book['title']}》到书架')),
                );
              },
              child: const Text('加入'),
            ),
          ),
        );
      },
    );
  }

  void _onSearch(String query) {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    // 模拟搜索延迟
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _searchResults = [
            {'title': '$query - 第一部', 'author': '作者A'},
            {'title': '$query - 第二部', 'author': '作者B'},
            {'title': '$query 外传', 'author': '作者C'},
          ];
        });
      }
    });
  }
}
