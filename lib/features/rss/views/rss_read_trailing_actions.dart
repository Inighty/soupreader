import 'package:flutter/cupertino.dart';

class RssReadTrailingActions extends StatelessWidget {
  final bool showFavorite;
  final bool isInFavorites;
  final bool favoriteActionRunning;
  final bool readAloudPlaying;
  final VoidCallback onRefresh;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onReadAloud;
  final VoidCallback onMore;

  const RssReadTrailingActions({
    super.key,
    required this.showFavorite,
    required this.isInFavorites,
    required this.favoriteActionRunning,
    required this.readAloudPlaying,
    required this.onRefresh,
    required this.onFavorite,
    required this.onShare,
    required this.onReadAloud,
    required this.onMore,
  });

  CupertinoButton _btn(IconData icon, VoidCallback? onPressed,
      {double size = 19}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(28, 28),
      onPressed: onPressed,
      child: Icon(icon, size: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(CupertinoIcons.refresh, onRefresh),
        if (showFavorite) ...[
          const SizedBox(width: 6),
          _btn(
            isInFavorites ? CupertinoIcons.star_fill : CupertinoIcons.star,
            favoriteActionRunning ? null : onFavorite,
          ),
        ],
        const SizedBox(width: 6),
        _btn(CupertinoIcons.share, onShare),
        const SizedBox(width: 6),
        _btn(
          readAloudPlaying
              ? CupertinoIcons.stop_circle
              : CupertinoIcons.volume_up,
          onReadAloud,
        ),
        const SizedBox(width: 6),
        _btn(CupertinoIcons.ellipsis_circle, onMore, size: 20),
      ],
    );
  }
}
