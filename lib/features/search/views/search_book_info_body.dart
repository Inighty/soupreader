// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoBody on SearchBookInfoViewState {
  Widget _buildBookInfoPage(BuildContext context) {
    final showInlineEditAction = _shouldShowInlineEditAction(context);
    final showInlineShareAction = _shouldShowInlineShareAction(context);
    final backgroundColor =
        CupertinoColors.systemBackground.resolveFrom(context);
    final borderColor = SourceUiTokens.resolveSeparatorColor(context);
    final primaryTextColor = CupertinoColors.label.resolveFrom(context);
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final primaryActionColor =
        SourceUiTokens.resolvePrimaryActionColor(context);
    final destructiveColor = SourceUiTokens.resolveDangerColor(context);
    final warningColor = CupertinoColors.systemOrange.resolveFrom(context);
    final coverUrl = _displayCoverUrl;
    final heroTopExtend =
        MediaQuery.paddingOf(context).top + kMinInteractiveDimensionCupertino;
    final kind = _pickFirstNonEmpty([_detail?.kind ?? '', _activeResult.kind]);
    final updateTime = _pickFirstNonEmpty([
      _detail?.updateTime ?? '',
      _activeResult.updateTime,
    ]);
    final wordCount = _pickFirstNonEmpty([
      _detail?.wordCount ?? '',
      _activeResult.wordCount,
    ]);
    final lastChapter = _pickFirstNonEmpty([
      _detail?.lastChapter ?? '',
      _activeResult.lastChapter,
    ]);
    final showUpdateTime = updateTime != null;
    final showWordCount = wordCount != null;

    return AppCupertinoPageScaffold(
      title: '书籍详情',
      includeTopSafeArea: false,
      includeBottomSafeArea: false,
      transitionBetweenRoutes: false,
      navigationBarBackgroundColor: CupertinoColors.transparent,
      navigationBarBorder: const Border(),
      navigationBarEnableBackgroundFilterBlur: false,
      navigationBarAutomaticBackgroundVisibility: false,
      trailing: _buildBookInfoTrailingActions(
        showInlineEditAction: showInlineEditAction,
        showInlineShareAction: showInlineShareAction,
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              clipBehavior: Clip.none,
              children: [
                _buildBookInfoHero(
                  context,
                  coverUrl: coverUrl,
                  heroTopExtend: heroTopExtend,
                  backgroundColor: backgroundColor,
                ),
                _buildBookInfoDetails(
                  context,
                  kind: kind,
                  lastChapter: lastChapter,
                  updateTime: updateTime,
                  wordCount: wordCount,
                  tocIsLast: !showUpdateTime && !showWordCount,
                  updateTimeIsLast: showUpdateTime && !showWordCount,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  primaryActionColor: primaryActionColor,
                  destructiveColor: destructiveColor,
                  warningColor: warningColor,
                ),
              ],
            ),
          ),
          _buildBookInfoBottomBar(
            context,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            primaryActionColor: primaryActionColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBookInfoTrailingActions({
    required bool showInlineEditAction,
    required bool showInlineShareAction,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showInlineEditAction)
          AppNavBarButton(
            onPressed: _openBookEdit,
            child: const Icon(CupertinoIcons.pencil),
          ),
        if (showInlineShareAction)
          AppNavBarButton(
            onPressed: _shareBook,
            child: const Icon(CupertinoIcons.share),
          ),
        AppNavBarButton(
          key: _moreMenuKey,
          onPressed: _showMoreActions,
          child: _switchingSource
              ? const CupertinoActivityIndicator(radius: 9)
              : const Icon(CupertinoIcons.ellipsis_circle),
        ),
      ],
    );
  }
}
