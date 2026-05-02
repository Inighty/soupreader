import 'package:flutter/cupertino.dart';

import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import 'search_book_info_widgets.dart';

/// 目录页右上角菜单项类型。
enum SearchBookTocMenuAction {
  reverseToc,
  useReplace,
  loadWordCount,
  tocRule,
  splitLongChapter,
  exportBookmark,
  exportBookmarkMarkdown,
  log,
}

/// 构建目录页菜单项列表（只读，外部决定显隐与勾选状态）。
List<AppActionListItem<SearchBookTocMenuAction>> buildSearchBookTocMenuItems({
  required bool showTxtTocRuleAction,
  required bool showSplitLongChapterAction,
  required bool splitLongChapterEnabled,
  required bool showUseReplaceAction,
  required bool useReplaceEnabled,
  required bool showLoadWordCountAction,
  required bool loadWordCountEnabled,
  required bool showExportBookmarkAction,
}) {
  return <AppActionListItem<SearchBookTocMenuAction>>[
    if (showTxtTocRuleAction)
      const AppActionListItem<SearchBookTocMenuAction>(
        value: SearchBookTocMenuAction.tocRule,
        icon: CupertinoIcons.doc_text,
        label: 'TXT 目录规则',
      ),
    if (showSplitLongChapterAction)
      AppActionListItem<SearchBookTocMenuAction>(
        value: SearchBookTocMenuAction.splitLongChapter,
        icon: splitLongChapterEnabled
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.textformat_size,
        label: splitLongChapterEnabled ? '✓ 拆分超长章节' : '拆分超长章节',
      ),
    const AppActionListItem<SearchBookTocMenuAction>(
      value: SearchBookTocMenuAction.reverseToc,
      icon: CupertinoIcons.arrow_up_arrow_down,
      label: '反转目录',
    ),
    if (showUseReplaceAction)
      AppActionListItem<SearchBookTocMenuAction>(
        value: SearchBookTocMenuAction.useReplace,
        icon: useReplaceEnabled
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.textformat,
        label: useReplaceEnabled ? '✓ 使用替换' : '使用替换',
      ),
    if (showLoadWordCountAction)
      AppActionListItem<SearchBookTocMenuAction>(
        value: SearchBookTocMenuAction.loadWordCount,
        icon: loadWordCountEnabled
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.number,
        label: loadWordCountEnabled ? '✓ 加载字数' : '加载字数',
      ),
    if (showExportBookmarkAction)
      const AppActionListItem<SearchBookTocMenuAction>(
        value: SearchBookTocMenuAction.exportBookmark,
        icon: CupertinoIcons.square_arrow_up,
        label: '导出',
      ),
    if (showExportBookmarkAction)
      const AppActionListItem<SearchBookTocMenuAction>(
        value: SearchBookTocMenuAction.exportBookmarkMarkdown,
        icon: CupertinoIcons.doc_text_fill,
        label: '导出(MD)',
      ),
    const AppActionListItem<SearchBookTocMenuAction>(
      value: SearchBookTocMenuAction.log,
      icon: CupertinoIcons.doc_text_search,
      label: '日志',
    ),
  ];
}

/// 目录页一行：序号 + 章节标题 + 字数标签 + 右箭头。
class SearchBookTocChapterRow extends StatelessWidget {
  final int chapterIndex;
  final String displayTitle;
  final TocItem item;
  final String? wordCountLabel;
  final VoidCallback onTap;

  const SearchBookTocChapterRow({
    super.key,
    required this.chapterIndex,
    required this.displayTitle,
    required this.item,
    required this.wordCountLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final cardColor = SourceUiTokens.resolveCardBackgroundColor(context);
    final borderColor = SourceUiTokens.resolveSeparatorColor(context);
    final primaryTextColor = CupertinoColors.label.resolveFrom(context);
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: SearchBookInfoCardContainer(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          backgroundColor: cardColor,
          borderColor: borderColor,
          borderWidth: SourceUiTokens.borderWidth,
          borderRadius: SourceUiTokens.radiusCard,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '${chapterIndex + 1}',
                  style: textStyle.copyWith(
                    fontSize: SourceUiTokens.itemMetaSize,
                    color: secondaryTextColor,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle.copyWith(
                    fontSize: SourceUiTokens.actionTextSize,
                    color: primaryTextColor,
                  ),
                ),
              ),
              if (wordCountLabel != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    wordCountLabel!,
                    style: textStyle.copyWith(
                      fontSize: SourceUiTokens.itemMetaSize,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
