// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoDetailSection on SearchBookInfoViewState {
  Widget _buildBookInfoDetails(
    BuildContext context, {
    required String? kind,
    required String? lastChapter,
    required String? updateTime,
    required String? wordCount,
    required bool tocIsLast,
    required bool updateTimeIsLast,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color primaryActionColor,
    required Color destructiveColor,
    required Color warningColor,
  }) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SourceUiTokens.pagePaddingHorizontal,
        4,
        SourceUiTokens.pagePaddingHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(
              fontSize: SourceUiTokens.detailTitleSize,
              height: 1.25,
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (kind != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: SearchBookInfoStatusChip(
                label: kind,
                color: primaryActionColor,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildBookInfoMetaCard(
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            tocIsLast: tocIsLast,
            updateTimeIsLast: updateTimeIsLast,
            primaryActionColor: primaryActionColor,
          ),
          const SizedBox(height: 10),
          _buildBookInfoIntroCard(
            context,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          _buildBookInfoStatusChips(
            primaryActionColor: primaryActionColor,
            warningColor: warningColor,
          ),
          _buildBookInfoErrorCards(
            context,
            destructiveColor: destructiveColor,
            warningColor: warningColor,
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildBookInfoMetaCard({
    required String? lastChapter,
    required String? updateTime,
    required String? wordCount,
    required bool tocIsLast,
    required bool updateTimeIsLast,
    required Color primaryActionColor,
  }) {
    return SearchBookInfoCardContainer(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          SearchBookInfoMetaLine(
            icon: CupertinoIcons.person,
            text: '作者：$_displayAuthor',
          ),
          SearchBookInfoMetaLine(
            icon: CupertinoIcons.globe,
            text: '来源：$_displaySourceName',
            trailing: _canFetchOnlineDetail
                ? SearchBookInfoMetaActionChip(
                    label: '换源',
                    onPressed: _switchingSource ? null : _switchSource,
                    color: primaryActionColor,
                  )
                : null,
          ),
          SearchBookInfoMetaLine(
            icon: CupertinoIcons.book,
            text: '最新：${lastChapter ?? '暂无'}',
          ),
          SearchBookInfoMetaLine(
            icon: CupertinoIcons.folder_open,
            text: '目录：${_resolveTocMetaValue()}',
            trailing: SearchBookInfoMetaActionChip(
              label: '查看',
              onPressed: _openToc,
              color: primaryActionColor,
            ),
            isLast: tocIsLast,
          ),
          if (updateTime != null)
            SearchBookInfoMetaLine(
              icon: CupertinoIcons.clock,
              text: '更新：$updateTime',
              isLast: updateTimeIsLast,
            ),
          if (wordCount != null)
            SearchBookInfoMetaLine(
              icon: CupertinoIcons.doc_text,
              text: '字数：$wordCount',
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildBookInfoIntroCard(
    BuildContext context, {
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return SearchBookInfoCardContainer(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '简介',
            style: textStyle.copyWith(
              fontSize: SourceUiTokens.itemTitleSize,
              color: primaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Text(
              _displayIntro,
              style: textStyle.copyWith(
                fontSize: SourceUiTokens.actionTextSize,
                color: secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookInfoStatusChips({
    required Color primaryActionColor,
    required Color warningColor,
  }) {
    if (!_inBookshelf && !_switchingSource) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (_inBookshelf)
            SearchBookInfoStatusChip(
              label: '已在书架',
              color: primaryActionColor,
            ),
          if (_switchingSource)
            SearchBookInfoStatusChip(
              label: '换源中',
              color: warningColor,
            ),
        ],
      ),
    );
  }

  Widget _buildBookInfoErrorCards(
    BuildContext context, {
    required Color destructiveColor,
    required Color warningColor,
  }) {
    return Column(
      children: [
        if (_error != null)
          _buildBookInfoMessageCard(
            context,
            message: _error!,
            color: destructiveColor,
          ),
        if (_tocError != null)
          _buildBookInfoMessageCard(
            context,
            message: _tocError!,
            color: warningColor,
          ),
      ],
    );
  }

  Widget _buildBookInfoMessageCard(
    BuildContext context, {
    required String message,
    required Color color,
  }) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SearchBookInfoCardContainer(
        borderColor: color,
        borderWidth: 0.5,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Text(
          message,
          style: textStyle.copyWith(
            fontSize: SourceUiTokens.actionTextSize,
            color: color,
          ),
        ),
      ),
    );
  }
}
