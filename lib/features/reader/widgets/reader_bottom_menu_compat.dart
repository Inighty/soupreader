import 'package:flutter/cupertino.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/reading_settings.dart';

class ReaderBottomMenu extends StatelessWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowInterfaceSettings;
  final VoidCallback onShowMoreMenu;

  const ReaderBottomMenu({
    super.key,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.settings,
    required this.currentTheme,
    required this.onChapterChanged,
    required this.onSettingsChanged,
    required this.onShowChapterList,
    required this.onShowInterfaceSettings,
    required this.onShowMoreMenu,
  });

  @override
  Widget build(BuildContext context) {
    final maxChapterIndex = (totalChapters - 1).clamp(0, 9999);
    final canSlideChapter = maxChapterIndex > 0;
    // CupertinoSlider 在 min==max 时语义计算会除 0，需保证可渲染范围大于 0。
    final chapterSliderMax = canSlideChapter ? maxChapterIndex.toDouble() : 1.0;
    final chapterSliderValue =
        currentChapterIndex.toDouble().clamp(0.0, chapterSliderMax).toDouble();
    final safeBrightness =
        settings.brightness.isFinite ? settings.brightness : 1.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 8,
          top: 16,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDesignTokens.radiusSheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：章节进度
            Row(
              children: [
                _buildIconBtn(
                    context,
                    CupertinoIcons.arrow_left,
                    currentChapterIndex > 0
                        ? () => onChapterChanged(currentChapterIndex - 1)
                        : null),
                Expanded(
                  child: Column(
                    children: [
                      CupertinoSlider(
                        value: chapterSliderValue,
                        min: 0,
                        max: chapterSliderMax,
                        activeColor: AppDesignTokens.brandSecondary,
                        thumbColor: AppDesignTokens.brandSecondary,
                        onChanged: canSlideChapter
                            ? (value) {
                                // 实时更新章节（拖动时立即跳转）
                                onChapterChanged(
                                  value
                                      .round()
                                      .clamp(0, maxChapterIndex)
                                      .toInt(),
                                );
                              }
                            : null,
                      ),
                      Text(
                        '${currentChapterIndex + 1} / $totalChapters',
                        style: TextStyle(
                          color:
                              CupertinoColors.systemGrey.resolveFrom(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildIconBtn(
                    context,
                    CupertinoIcons.arrow_right,
                    currentChapterIndex < totalChapters - 1
                        ? () => onChapterChanged(currentChapterIndex + 1)
                        : null),
              ],
            ),
            const SizedBox(height: 16),

            // 第二行：亮度调节
            Row(
              children: [
                Icon(
                  CupertinoIcons.sun_min,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                  size: 20,
                ),
                Expanded(
                  child: CupertinoSlider(
                    value: safeBrightness.clamp(0.0, 1.0).toDouble(),
                    min: 0.0,
                    max: 1.0,
                    activeColor: AppDesignTokens.brandSecondary,
                    thumbColor: AppDesignTokens.brandSecondary,
                    onChanged: (value) {
                      onSettingsChanged(settings.copyWith(brightness: value));
                    },
                  ),
                ),
                Icon(
                  CupertinoIcons.sun_max,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                  size: 20,
                ),
                const SizedBox(width: 16),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    onSettingsChanged(settings.copyWith(
                        useSystemBrightness: !settings.useSystemBrightness));
                  },
                  child: AnimatedContainer(
                    duration: AppDesignTokens.motionQuick,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: settings.useSystemBrightness
                          ? AppDesignTokens.brandSecondary
                          : CupertinoColors.systemGrey.resolveFrom(context)
                              .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusSheet),
                    ),
                    child: Text(
                      '跟随系统',
                      style: TextStyle(
                        color: settings.useSystemBrightness
                            ? CupertinoColors.white
                            : CupertinoColors.systemGrey.resolveFrom(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 第三行：底部功能栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMenuBtn(context, CupertinoIcons.list_bullet, '目录',
                    onShowChapterList),
                _buildMenuBtn(context, CupertinoIcons.slider_horizontal_3, '界面',
                    onShowInterfaceSettings),
                _buildMenuBtn(
                    context,
                    currentTheme.isDark
                        ? CupertinoIcons.moon_fill
                        : CupertinoIcons.sun_max,
                    currentTheme.isDark ? '夜间' : '日间', () {
                  final isDark = currentTheme.isDark;
                  final targetIndex = AppColors.readingThemes
                      .indexWhere((t) => isDark ? !t.isDark : t.isDark);
                  if (targetIndex != -1) {
                    onSettingsChanged(
                        settings.copyWith(themeIndex: targetIndex));
                  }
                }),
                // 翻页模式切换（点击弹窗选择）
                Builder(
                  builder: (context) => _buildMenuBtn(
                      context,
                      _getPageTurnModeIcon(settings.pageTurnMode),
                      settings.pageTurnMode.name, () {
                    _showPageTurnModeSheet(
                        context, settings, onSettingsChanged);
                  }),
                ),
                _buildMenuBtn(context, CupertinoIcons.ellipsis_circle, '更多',
                    onShowMoreMenu),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Icon(
        icon,
        color: onTap != null
            ? AppDesignTokens.brandSecondary
            : CupertinoColors.systemGrey.resolveFrom(context),
        size: 24,
      ),
    );
  }

  Widget _buildMenuBtn(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final compactTapSquare =
        AppUiTokens.resolve(context).sizes.compactTapSquare;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: compactTapSquare,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CupertinoColors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style:
                  const TextStyle(color: CupertinoColors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据翻页模式返回对应图标
  IconData _getPageTurnModeIcon(PageTurnMode mode) {
    switch (mode) {
      case PageTurnMode.slide:
        return CupertinoIcons.arrow_left_right;
      case PageTurnMode.simulation:
      case PageTurnMode.simulation2:
        return CupertinoIcons.book;
      case PageTurnMode.cover:
        return CupertinoIcons.square_stack;
      case PageTurnMode.none:
        return CupertinoIcons.stop;
      case PageTurnMode.scroll:
        return CupertinoIcons.arrow_up_arrow_down;
    }
  }

  /// 显示翻页模式选择弹窗
  void _showPageTurnModeSheet(
    BuildContext context,
    ReadingSettings settings,
    ValueChanged<ReadingSettings> onSettingsChanged,
  ) {
    final rootContext = context;
    showCupertinoBottomSheetDialog<void>(
      context: rootContext,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('选择翻页模式'),
        actions:
            PageTurnModeUi.values(current: settings.pageTurnMode).map((mode) {
          final isSelected = mode == settings.pageTurnMode;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              if (PageTurnModeUi.isHidden(mode)) {
                _showMessage(rootContext, '仿真2模式已隐藏');
                return;
              }
              onSettingsChanged(settings.copyWith(pageTurnMode: mode));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getPageTurnModeIcon(mode),
                  color: isSelected
                      ? AppDesignTokens.brandSecondary
                      : PageTurnModeUi.isHidden(mode)
                          ? CupertinoColors.inactiveGray
                              .resolveFrom(sheetContext)
                          : CupertinoColors.label.resolveFrom(sheetContext),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  PageTurnModeUi.isHidden(mode)
                      ? '${mode.name}（隐藏）'
                      : mode.name,
                  style: TextStyle(
                    color: isSelected
                        ? AppDesignTokens.brandSecondary
                        : PageTurnModeUi.isHidden(mode)
                            ? CupertinoColors.inactiveGray.resolveFrom(
                                sheetContext,
                              )
                            : CupertinoColors.label.resolveFrom(sheetContext),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.checkmark,
                    color: AppDesignTokens.brandSecondary,
                    size: 18,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
