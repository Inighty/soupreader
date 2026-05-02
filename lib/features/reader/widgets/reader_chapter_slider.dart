import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

/// 阅读器底部章节滑杆 + 上一章/下一章按钮 + 进度文字。
///
/// 同时支持 page 模式（按页索引滑动）与 chapter 模式（按章索引滑动）。
class ReaderChapterSlider extends StatefulWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final int currentPageIndex;
  final int totalPages;
  final ReadingSettings settings;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<int> onSeekPageProgress;
  final ValueChanged<int> onSeekChapterProgress;
  final Color foreground;
  final Color mutedForeground;
  final bool isDarkMode;

  const ReaderChapterSlider({
    super.key,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.currentPageIndex,
    required this.totalPages,
    required this.settings,
    required this.onChapterChanged,
    required this.onSeekPageProgress,
    required this.onSeekChapterProgress,
    required this.foreground,
    required this.mutedForeground,
    required this.isDarkMode,
  });

  @override
  State<ReaderChapterSlider> createState() => _ReaderChapterSliderState();
}

class _ReaderChapterSliderState extends State<ReaderChapterSlider> {
  bool _isDragging = false;
  double _dragValue = 0;

  double _safeFinite(double value, {double fallback = 0.0}) {
    return value.isFinite ? value : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isPageMode =
        widget.settings.progressBarBehavior == ProgressBarBehavior.page;
    final accent = widget.isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;

    if (isPageMode) {
      return _buildPageModeSlider(accent);
    }
    return _buildChapterModeSlider(accent);
  }

  Widget _buildPageModeSlider(Color accent) {
    final maxPage = (widget.totalPages - 1).clamp(0, 999999);
    final canSlide = maxPage > 0;
    final sliderMax = canSlide ? maxPage.toDouble() : 1.0;
    final rawValue = _isDragging
        ? _safeFinite(_dragValue)
        : _safeFinite(widget.currentPageIndex.toDouble());
    final sliderValue = rawValue.clamp(0.0, sliderMax).toDouble();
    final canPrev = widget.currentChapterIndex > 0;
    final canNext = widget.currentChapterIndex < widget.totalChapters - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavButton(
                label: '上一章',
                enabled: canPrev,
                onTap: canPrev
                    ? () =>
                        widget.onChapterChanged(widget.currentChapterIndex - 1)
                    : null,
              ),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: CupertinoSlider(
                    value: sliderValue,
                    min: 0,
                    max: sliderMax,
                    activeColor: accent,
                    thumbColor:
                        widget.isDarkMode ? CupertinoColors.white : accent,
                    onChanged: canSlide
                        ? (value) => setState(() {
                              _isDragging = true;
                              _dragValue = value;
                            })
                        : null,
                    onChangeEnd: canSlide
                        ? (value) {
                            setState(() => _isDragging = false);
                            widget.onSeekPageProgress(
                                value.round().clamp(0, maxPage).toInt());
                          }
                        : null,
                  ),
                ),
              ),
              _buildNavButton(
                label: '下一章',
                enabled: canNext,
                onTap: canNext
                    ? () =>
                        widget.onChapterChanged(widget.currentChapterIndex + 1)
                    : null,
              ),
            ],
          ),
          Text(
            '${widget.currentPageIndex + 1} / ${widget.totalPages}',
            style: TextStyle(color: widget.mutedForeground, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterModeSlider(Color accent) {
    final maxChapter = (widget.totalChapters - 1).clamp(0, 9999);
    final canSlide = maxChapter > 0;
    final sliderMax = canSlide ? maxChapter.toDouble() : 1.0;
    final rawSliderValue = _isDragging
        ? _safeFinite(_dragValue)
        : _safeFinite(widget.currentChapterIndex.toDouble());
    final sliderValue = rawSliderValue.clamp(0.0, sliderMax).toDouble();
    final canPrev = widget.currentChapterIndex > 0;
    final canNext = widget.currentChapterIndex < widget.totalChapters - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavButton(
                label: '上一章',
                enabled: canPrev,
                onTap: canPrev
                    ? () =>
                        widget.onChapterChanged(widget.currentChapterIndex - 1)
                    : null,
              ),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: CupertinoSlider(
                    value: sliderValue,
                    min: 0,
                    max: sliderMax,
                    activeColor: accent,
                    thumbColor:
                        widget.isDarkMode ? CupertinoColors.white : accent,
                    onChanged: canSlide
                        ? (value) => setState(() {
                              _isDragging = true;
                              _dragValue = value;
                            })
                        : null,
                    onChangeEnd: canSlide
                        ? (value) {
                            setState(() => _isDragging = false);
                            widget.onSeekChapterProgress(
                                value.round().clamp(0, maxChapter).toInt());
                          }
                        : null,
                  ),
                ),
              ),
              _buildNavButton(
                label: '下一章',
                enabled: canNext,
                onTap: canNext
                    ? () =>
                        widget.onChapterChanged(widget.currentChapterIndex + 1)
                    : null,
              ),
            ],
          ),
          Text(
            '${widget.currentChapterIndex + 1} / ${widget.totalChapters}',
            style: TextStyle(color: widget.mutedForeground, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final color = enabled ? widget.foreground : widget.mutedForeground;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
