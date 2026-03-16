import 'package:flutter/cupertino.dart';

/// Full-screen image preview with pinch-to-zoom and pan support.
class ReaderImagePreviewPage extends StatelessWidget {
  final ImageProvider imageProvider;

  const ReaderImagePreviewPage({super.key, required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.7),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.xmark,
            color: CupertinoColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8.0,
          child: Center(
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                CupertinoIcons.photo,
                color: CupertinoColors.systemGrey.resolveFrom(context),
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
