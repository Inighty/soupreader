import 'package:flutter/cupertino.dart';

import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../services/reader_theme_resolver.dart';
import 'reader_status_bar.dart';

/// Overlay that shows the top header bar and bottom status bar in scroll mode.
///
/// Uses a [ValueNotifier<ScrollTipData>] for efficient, fine-grained rebuilds
/// without rebuilding the entire reader tree.
class ReaderStatusBarOverlay extends StatelessWidget {
  const ReaderStatusBarOverlay({
    super.key,
    required this.visible,
    required this.isScrollMode,
    required this.settings,
    required this.theme,
    required this.tipNotifier,
  });

  /// Whether the overlay should be displayed (hidden when menus are open).
  final bool visible;

  /// Whether the reader is in scroll mode (status bars are only shown in
  /// scroll mode; paged mode handles them internally).
  final bool isScrollMode;

  final ReadingSettings settings;
  final ReadingThemeColors theme;
  final ValueNotifier<ScrollTipData> tipNotifier;

  @override
  Widget build(BuildContext context) {
    if (!visible || !isScrollMode) return const SizedBox.shrink();

    return Stack(
      children: [
        // Bottom status bar
        if (settings.shouldShowFooter())
          ValueListenableBuilder<ScrollTipData>(
            valueListenable: tipNotifier,
            builder: (context, tip, _) => ReaderStatusBar(
              settings: settings,
              currentTheme: theme,
              currentTime: tip.currentTime,
              title: tip.title,
              bookTitle: tip.bookTitle,
              bookProgress: tip.bookProgress,
              chapterProgress: tip.chapterProgress,
              currentPage: tip.currentPage,
              totalPages: tip.totalPages,
            ),
          ),

        // Top header bar
        if (settings.shouldShowHeader(
          showStatusBar: settings.showStatusBar,
        ))
          ValueListenableBuilder<ScrollTipData>(
            valueListenable: tipNotifier,
            builder: (context, tip, _) => ReaderHeaderBar(
              settings: settings,
              currentTheme: theme,
              currentTime: tip.currentTime,
              title: tip.title,
              bookTitle: tip.bookTitle,
              bookProgress: tip.bookProgress,
              chapterProgress: tip.chapterProgress,
              currentPage: tip.currentPage,
              totalPages: tip.totalPages,
            ),
          ),
      ],
    );
  }
}
