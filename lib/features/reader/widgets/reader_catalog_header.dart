import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';

/// 抽屉顶部「书籍信息 + grabber」头部。
class ReaderCatalogHeader extends StatelessWidget {
  const ReaderCatalogHeader({
    super.key,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.chapterCount,
    required this.textStrong,
    required this.textSubtle,
  });

  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final int chapterCount;
  final Color textStrong;
  final Color textSubtle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          AppCoverImage(
            urlOrPath: coverUrl,
            title: bookTitle,
            width: 50,
            height: 70,
            borderRadius: 8,
            showTextOnPlaceholder: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  style: TextStyle(
                    color: textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  bookAuthor.trim().isNotEmpty
                      ? bookAuthor.trim()
                      : '未知作者',
                  style: TextStyle(color: textSubtle, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '共$chapterCount章',
                  style: TextStyle(color: textSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 抽屉顶部 grabber（细横条）。
class ReaderCatalogGrabber extends StatelessWidget {
  const ReaderCatalogGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final color = CupertinoColors.separator.resolveFrom(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 2),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Tab 切换栏（目录 / 书签）+ 工具按钮（更多 / 清缓存 / 刷新）。
class ReaderCatalogTabBar extends StatelessWidget {
  const ReaderCatalogTabBar({
    super.key,
    required this.selectedTab,
    required this.chapterCount,
    required this.bookmarkCount,
    required this.busy,
    required this.accent,
    required this.textNormal,
    required this.lineColor,
    required this.onSelectTab,
    required this.onShowMoreActions,
    required this.onClearCache,
    required this.onRefreshCatalog,
  });

  final int selectedTab;
  final int chapterCount;
  final int bookmarkCount;
  final bool busy;
  final Color accent;
  final Color textNormal;
  final Color lineColor;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onShowMoreActions;
  final VoidCallback onClearCache;
  final VoidCallback onRefreshCatalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildTab(context, 0, '目录', count: chapterCount),
            _buildTab(context, 1, '书签', count: bookmarkCount),
            const Spacer(),
            _toolButton(context, CupertinoIcons.ellipsis_circle,
                onShowMoreActions),
            _toolButton(context, CupertinoIcons.trash, onClearCache),
            _toolButton(
                context, CupertinoIcons.arrow_clockwise, onRefreshCatalog),
          ],
        ),
        Container(height: 0.5, color: lineColor),
      ],
    );
  }

  Widget _buildTab(
    BuildContext context,
    int index,
    String label, {
    int? count,
  }) {
    final isSelected = selectedTab == index;
    final title = count == null ? label : '$label ($count)';
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => onSelectTab(index),
      child: AnimatedContainer(
        duration: AppDesignTokens.motionQuick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? accent : CupertinoColors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? accent : textNormal,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _toolButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onPressed: busy ? null : onPressed,
      child: Icon(
        icon,
        size: 20,
        color: busy
            ? CupertinoColors.tertiaryLabel.resolveFrom(context)
            : textNormal,
      ),
    );
  }
}

/// 搜索框 + 排序按钮 + 计数行。
class ReaderCatalogSearchAndSort extends StatelessWidget {
  const ReaderCatalogSearchAndSort({
    super.key,
    required this.controller,
    required this.selectedTab,
    required this.searchQuery,
    required this.totalChapterCount,
    required this.matchedChapterCount,
    required this.isReversed,
    required this.textStrong,
    required this.textNormal,
    required this.textSubtle,
    required this.cardMutedBg,
    required this.onQueryChanged,
    required this.onToggleReverse,
  });

  final TextEditingController controller;
  final int selectedTab;
  final String searchQuery;
  final int totalChapterCount;
  final int matchedChapterCount;
  final bool isReversed;
  final Color textStrong;
  final Color textNormal;
  final Color textSubtle;
  final Color cardMutedBg;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleReverse;

  @override
  Widget build(BuildContext context) {
    final showSort = selectedTab == 0;
    final placeholder = selectedTab == 0 ? '输入关键字搜索目录' : '搜索书签';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  controller: controller,
                  placeholder: placeholder,
                  style: TextStyle(color: textStrong, fontSize: 14),
                  backgroundColor: cardMutedBg,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusControl),
                  onChanged: onQueryChanged,
                ),
              ),
              if (showSort)
                CupertinoButton(
                  padding: const EdgeInsets.only(left: 12),
                  onPressed: onToggleReverse,
                  child: Icon(
                    isReversed
                        ? CupertinoIcons.sort_up
                        : CupertinoIcons.sort_down,
                    size: 22,
                    color: textNormal,
                  ),
                ),
            ],
          ),
          if (selectedTab == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  searchQuery.trim().isEmpty
                      ? '共 $totalChapterCount 章'
                      : '匹配 $matchedChapterCount 章',
                  style: TextStyle(color: textSubtle, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
