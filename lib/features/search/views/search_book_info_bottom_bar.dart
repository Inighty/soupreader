// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoBottomBar on SearchBookInfoViewState {
  Widget _buildBookInfoBottomBar(
    BuildContext context, {
    required Color backgroundColor,
    required Color borderColor,
    required Color primaryActionColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: SourceUiTokens.borderWidth,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        SourceUiTokens.pagePaddingHorizontal,
        8,
        SourceUiTokens.pagePaddingHorizontal,
        math.max(8, MediaQuery.paddingOf(context).bottom),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildShelfButton(
              context,
              backgroundColor: backgroundColor,
              primaryActionColor: primaryActionColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildReadButton(
              context,
              primaryActionColor: primaryActionColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelfButton(
    BuildContext context, {
    required Color backgroundColor,
    required Color primaryActionColor,
  }) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _shelfBusy ? null : _toggleShelf,
      minimumSize: const Size.square(SourceUiTokens.minTapSize),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(SourceUiTokens.radiusControl),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              if (_shelfBusy) ...[
                const SizedBox.square(
                  dimension: 14,
                  child: CupertinoActivityIndicator(radius: 7),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                _inBookshelf ? '移出书架' : '加入书架',
                style: textStyle.copyWith(
                  fontSize: SourceUiTokens.actionTextSize,
                  fontWeight: FontWeight.w600,
                  color: primaryActionColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadButton(
    BuildContext context, {
    required Color primaryActionColor,
  }) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: (_loading || _loadingToc)
          ? null
          : () => _openReader(initialChapter: _resolveReadStartChapter()),
      minimumSize: const Size.square(SourceUiTokens.minTapSize),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primaryActionColor,
          borderRadius: BorderRadius.circular(SourceUiTokens.radiusControl),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Center(
            child: Text(
              '开始阅读',
              style: textStyle.copyWith(
                fontSize: SourceUiTokens.actionTextSize,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
