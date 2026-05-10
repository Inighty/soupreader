import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/models/book.dart';

/// 搜索页右下角的浮动设置按钮。
class SearchFloatingSettingsButton extends StatelessWidget {
  const SearchFloatingSettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final shadow = CupertinoColors.black.withValues(alpha: 0.10);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: uiTokens.sizes.compactTapSquare,
      onPressed: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 8)),
          ],
        ),
        child: Icon(
          CupertinoIcons.line_horizontal_3,
          size: 18,
          color: uiTokens.colors.accent,
        ),
      ),
    );
  }
}

/// 顶部状态条容器（统一边框/内边距）。
class SearchStatusPanel extends StatelessWidget {
  const SearchStatusPanel({
    super.key,
    required this.borderColor,
    required this.child,
  });

  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: borderColor.withValues(alpha: 0.82),
        borderWidth: 0.5,
        child: child,
      ),
    );
  }
}

/// 顶部输入法辅助面板（书架快速命中 + 历史词列表）。
class SearchInputHelpPanel extends StatelessWidget {
  const SearchInputHelpPanel({
    super.key,
    required this.bookshelfHints,
    required this.historyHints,
    required this.hasQueryText,
    required this.onClearHistory,
    required this.onHistoryTap,
    required this.onHistoryLongPress,
    required this.onBookshelfTap,
  });

  final List<Book> bookshelfHints;
  final List<String> historyHints;
  final bool hasQueryText;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onHistoryTap;
  final ValueChanged<String> onHistoryLongPress;
  final ValueChanged<Book> onBookshelfTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        CupertinoColors.systemBackground.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
        children: [
          if (bookshelfHints.isNotEmpty) ...[
            SearchBookshelfHintPanel(
              books: bookshelfHints,
              onTap: onBookshelfTap,
            ),
            const SizedBox(height: 10),
          ],
          SearchHistoryPanel(
            historyHints: historyHints,
            hasQueryText: hasQueryText,
            onClearHistory: onClearHistory,
            onTap: onHistoryTap,
            onLongPress: onHistoryLongPress,
          ),
        ],
      ),
    );
  }
}

/// 结果为空时的占位 + 历史词。
class SearchEmptyBody extends StatelessWidget {
  const SearchEmptyBody({
    super.key,
    required this.totalSources,
    required this.isSearching,
    required this.hasIssues,
    required this.historyHints,
    required this.hasQueryText,
    required this.onClearHistory,
    required this.onHistoryTap,
    required this.onHistoryLongPress,
  });

  final int totalSources;
  final bool isSearching;
  final bool hasIssues;
  final List<String> historyHints;
  final bool hasQueryText;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onHistoryTap;
  final ValueChanged<String> onHistoryLongPress;

  @override
  Widget build(BuildContext context) {
    if (isSearching) return const SizedBox.shrink();
    final uiTokens = AppUiTokens.resolve(context);
    final hint = hasIssues
        ? '本次有失败书源，点上方“查看”了解原因'
        : totalSources == 0
            ? '当前没有启用书源，请先在“搜索设置”里调整范围'
            : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      children: [
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: uiTokens.colors.mutedForeground,
              ),
            ),
          ),
        SearchHistoryPanel(
          historyHints: historyHints,
          hasQueryText: hasQueryText,
          onClearHistory: onClearHistory,
          onTap: onHistoryTap,
          onLongPress: onHistoryLongPress,
        ),
      ],
    );
  }
}

/// 「书架匹配」面板。
class SearchBookshelfHintPanel extends StatelessWidget {
  const SearchBookshelfHintPanel({
    super.key,
    required this.books,
    required this.onTap,
  });

  final List<Book> books;
  final ValueChanged<Book> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '书架匹配',
            style: theme.textTheme.textStyle.copyWith(
              color: uiTokens.colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: books
                .map((book) =>
                    _SearchBookshelfHintChip(book: book, onTap: onTap))
                .toList(growable: false),
          ),
          const SizedBox(height: 6),
          Text(
            '点击可直接进入该书详情',
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 12,
              color: uiTokens.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBookshelfHintChip extends StatelessWidget {
  const _SearchBookshelfHintChip({required this.book, required this.onTap});

  final Book book;
  final ValueChanged<Book> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: uiTokens.sizes.compactTapSquare,
      color: uiTokens.colors.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      onPressed: () => onTap(book),
      child: Text(
        book.title,
        style: theme.textTheme.textStyle.copyWith(
          fontSize: 12,
          color: uiTokens.colors.foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 「搜索历史」面板。
class SearchHistoryPanel extends StatelessWidget {
  const SearchHistoryPanel({
    super.key,
    required this.historyHints,
    required this.hasQueryText,
    required this.onClearHistory,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> historyHints;
  final bool hasQueryText;
  final VoidCallback onClearHistory;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    if (historyHints.isEmpty) {
      return AppEmptyState(
        illustration: const AppEmptyPlanetIllustration(size: 72),
        title: hasQueryText ? '无匹配历史词' : '暂无历史记录',
        message: hasQueryText ? '可调整关键词后重试' : '搜索后会自动保存历史词',
      );
    }
    final headerColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '搜索历史',
                style: theme.textTheme.textStyle.copyWith(
                  color: headerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                onPressed: onClearHistory,
                child: Text(
                  '清除',
                  style: TextStyle(
                    color: uiTokens.colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: historyHints
                .map((keyword) => _SearchHistoryChip(
                      keyword: keyword,
                      onTap: onTap,
                      onLongPress: onLongPress,
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _SearchHistoryChip extends StatelessWidget {
  const _SearchHistoryChip({
    required this.keyword,
    required this.onTap,
    required this.onLongPress,
  });

  final String keyword;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    final chipBg = CupertinoColors.systemGrey5.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    return GestureDetector(
      onLongPress: () => onLongPress(keyword),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: uiTokens.sizes.compactTapSquare,
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
        onPressed: () => onTap(keyword),
        child: Text(
          keyword,
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 12,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
