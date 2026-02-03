import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../models/reading_settings.dart';

class ReaderStatusBar extends StatelessWidget {
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final String currentTime;
  final String title;
  final double progress;

  const ReaderStatusBar({
    super.key,
    required this.settings,
    required this.currentTheme,
    required this.currentTime,
    required this.title,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 4,
          top: 4,
          left: settings.marginHorizontal,
          right: settings.marginHorizontal,
        ),
        color: currentTheme.background,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 时间
            if (settings.showTime)
              Text(
                currentTime,
                style: TextStyle(
                  color: currentTheme.text.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            // 章节标题（缩略）
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: currentTheme.text.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ),
            // 进度
            if (settings.showProgress)
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: currentTheme.text.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
