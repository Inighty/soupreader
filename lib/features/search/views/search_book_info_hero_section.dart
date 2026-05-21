// ignore_for_file: invalid_use_of_protected_member

part of 'search_book_info_view.dart';

extension _SearchBookInfoHeroSection on SearchBookInfoViewState {
  Widget _buildBookInfoHero(
    BuildContext context, {
    required String coverUrl,
    required double heroTopExtend,
    required Color backgroundColor,
  }) {
    return SizedBox(
      height: 286,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -heroTopExtend,
            left: 0,
            right: 0,
            height: 286 + heroTopExtend,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SearchBookInfoHeroBackground(
                    coverUrl: coverUrl,
                    title: _displayName,
                    author: _displayAuthor,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          CupertinoColors.black.withValues(alpha: 0.32),
                          CupertinoColors.black.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.elliptical(320, 72),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius:
                      BorderRadius.circular(AppDesignTokens.radiusControl),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: AppCoverImage(
                  urlOrPath: coverUrl,
                  title: _displayName,
                  author: _displayAuthor,
                  width: 110,
                  height: 160,
                  borderRadius: 8,
                  showTextOnPlaceholder: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
