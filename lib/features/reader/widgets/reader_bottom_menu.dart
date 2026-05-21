import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';
import 'reader_brightness_panel.dart';
import 'reader_chapter_slider.dart';
import 'reader_menu_surface_style.dart';

/// 阅读器底部菜单：操作路径对齐 legado（目录/朗读/界面/设置）。
class ReaderBottomMenuNew extends StatefulWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final int currentPageIndex;
  final int totalPages;
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<int> onSeekChapterProgress;
  final ValueChanged<int> onSeekPageProgress;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowReadAloud;
  final VoidCallback? onReadAloudLongPress;
  final VoidCallback onShowInterfaceSettings;
  final VoidCallback onShowBehaviorSettings;
  final VoidCallback? onToggleAutoPage;
  final VoidCallback? onSearchContent;
  final VoidCallback? onToggleReplaceRule;
  final VoidCallback? onToggleNightMode;
  final bool showReadAloud;
  final bool readBarStyleFollowPage;
  final bool readAloudRunning;
  final bool readAloudPaused;
  final bool autoPageRunning;
  final bool isNightMode;
  final Animation<double>? menuFadeAnimation;
  final Animation<Offset>? menuSlideAnimation;

  const ReaderBottomMenuNew({
    super.key,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.currentPageIndex,
    required this.totalPages,
    required this.settings,
    required this.currentTheme,
    required this.onChapterChanged,
    required this.onSeekChapterProgress,
    required this.onSeekPageProgress,
    required this.onSettingsChanged,
    required this.onShowChapterList,
    required this.onShowReadAloud,
    this.onReadAloudLongPress,
    required this.onShowInterfaceSettings,
    required this.onShowBehaviorSettings,
    this.onToggleAutoPage,
    this.onSearchContent,
    this.onToggleReplaceRule,
    this.onToggleNightMode,
    this.showReadAloud = true,
    this.readBarStyleFollowPage = false,
    this.readAloudRunning = false,
    this.readAloudPaused = false,
    this.autoPageRunning = false,
    this.isNightMode = false,
    this.menuFadeAnimation,
    this.menuSlideAnimation,
  });

  @override
  State<ReaderBottomMenuNew> createState() => _ReaderBottomMenuNewState();
}

class _ReaderBottomMenuNewState extends State<ReaderBottomMenuNew> {
  static const Key _brightnessPanelKey = Key('reader_brightness_panel');
  static const Key _brightnessAutoToggleKey = Key('reader_brightness_auto');
  static const Key _brightnessPositionToggleKey = Key('reader_brightness_pos');
  static const Key _bottomMenuPanelKey = Key('reader_bottom_menu_panel');
  static const double _brightnessPanelTopOffset = 78.0;
  static const double _brightnessPanelTopOffsetWithTitleAddition = 94.0;
  static const double _brightnessPanelBottomOffset = 98.0;

  bool get _isDarkMode => widget.currentTheme.isDark;

  @override
  Widget build(BuildContext context) {
    final style = resolveReaderMenuSurfaceStyle(
      currentTheme: widget.currentTheme,
      readBarStyleFollowPage: widget.readBarStyleFollowPage,
    );
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final brightnessTopOffset = widget.settings.showReadTitleAddition
        ? _brightnessPanelTopOffsetWithTitleAddition
        : _brightnessPanelTopOffset;

    final fadeAnim = widget.menuFadeAnimation;
    final slideAnim = widget.menuSlideAnimation;

    Widget brightnessPanelChild = ReaderBrightnessPanel(
      rootKey: _brightnessPanelKey,
      autoToggleKey: _brightnessAutoToggleKey,
      positionToggleKey: _brightnessPositionToggleKey,
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
      panelBackground: style.panelBackground,
      foreground: style.primaryText,
      mutedForeground: style.secondaryText,
      borderColor: style.borderColor,
      isDarkMode: _isDarkMode,
    );
    if (fadeAnim != null) {
      brightnessPanelChild = FadeTransition(
        opacity: fadeAnim,
        child: brightnessPanelChild,
      );
    }

    Widget bottomPanel = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          key: _bottomMenuPanelKey,
          decoration: BoxDecoration(
            color: style.panelBackground.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: style.dividerColor,
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: bottomPadding + (bottomPadding > 0 ? 4 : 8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onSearchContent != null ||
                  widget.onToggleReplaceRule != null ||
                  widget.onToggleNightMode != null ||
                  widget.onToggleAutoPage != null) ...[
                _buildQuickActionRow(
                  foreground: style.primaryText,
                  accent: _isDarkMode
                      ? AppDesignTokens.brandSecondary
                      : AppDesignTokens.brandPrimary,
                ),
                _buildDivider(style.dividerColor),
              ],
              ReaderChapterSlider(
                currentChapterIndex: widget.currentChapterIndex,
                totalChapters: widget.totalChapters,
                currentPageIndex: widget.currentPageIndex,
                totalPages: widget.totalPages,
                settings: widget.settings,
                onChapterChanged: widget.onChapterChanged,
                onSeekPageProgress: widget.onSeekPageProgress,
                onSeekChapterProgress: widget.onSeekChapterProgress,
                foreground: style.primaryText,
                mutedForeground: style.secondaryText,
                isDarkMode: _isDarkMode,
              ),
              _buildDivider(style.dividerColor),
              _buildBottomTabs(foreground: style.primaryText),
            ],
          ),
        ),
      ),
    );
    if (slideAnim != null && fadeAnim != null) {
      bottomPanel = SlideTransition(
        position: slideAnim,
        child: FadeTransition(
          opacity: fadeAnim,
          child: bottomPanel,
        ),
      );
    }

    return Positioned.fill(
      child: Stack(
        children: [
          if (widget.settings.showBrightnessView)
            Positioned(
              top: mediaQuery.padding.top + brightnessTopOffset,
              bottom: bottomPadding + _brightnessPanelBottomOffset,
              left: widget.settings.brightnessViewOnRight ? null : 16,
              right: widget.settings.brightnessViewOnRight ? 16 : null,
              child: brightnessPanelChild,
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: bottomPanel,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      height: 0.5,
      color: color,
    );
  }

  Widget _buildQuickActionRow({
    required Color foreground,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (widget.onSearchContent != null)
            Expanded(
              child: _buildQuickActionItem(
                icon: CupertinoIcons.search,
                foreground: foreground,
                onTap: widget.onSearchContent!,
              ),
            ),
          if (widget.onToggleAutoPage != null)
            Expanded(
              child: _buildQuickActionItem(
                icon: widget.autoPageRunning
                    ? CupertinoIcons.timer_fill
                    : CupertinoIcons.timer,
                foreground: foreground,
                active: widget.autoPageRunning,
                activeColor: accent,
                onTap: widget.onToggleAutoPage!,
              ),
            ),
          if (widget.onToggleReplaceRule != null)
            Expanded(
              child: _buildQuickActionItem(
                icon: CupertinoIcons.wand_stars,
                foreground: foreground,
                onTap: widget.onToggleReplaceRule!,
              ),
            ),
          if (widget.onToggleNightMode != null)
            Expanded(
              child: _buildQuickActionItem(
                icon: widget.isNightMode
                    ? CupertinoIcons.moon_fill
                    : CupertinoIcons.sun_max,
                foreground: foreground,
                active: widget.isNightMode,
                activeColor: accent,
                onTap: widget.onToggleNightMode!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required Color foreground,
    required VoidCallback onTap,
    bool active = false,
    Color? activeColor,
  }) {
    final color = active ? (activeColor ?? foreground) : foreground;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _buildBottomTabs({required Color foreground}) {
    final readAloudActive = widget.readAloudRunning;
    final readAloudIcon = widget.readAloudPaused
        ? CupertinoIcons.pause_circle
        : CupertinoIcons.speaker_2_fill;
    final accent = _isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;

    final tabs = <Widget>[
      _buildTabItem(
        foreground: foreground,
        icon: CupertinoIcons.list_bullet,
        label: '目录',
        onTap: widget.onShowChapterList,
      ),
      if (widget.showReadAloud)
        _buildTabItem(
          foreground: foreground,
          icon: readAloudIcon,
          label: '朗读',
          onTap: widget.onShowReadAloud,
          onLongPress: widget.onReadAloudLongPress,
          active: readAloudActive,
          activeColor: accent,
        ),
      _buildTabItem(
        foreground: foreground,
        icon: CupertinoIcons.textformat,
        label: '界面',
        onTap: widget.onShowInterfaceSettings,
      ),
      _buildTabItem(
        foreground: foreground,
        icon: CupertinoIcons.slider_horizontal_3,
        label: '设置',
        onTap: widget.onShowBehaviorSettings,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: tabs.map((tab) => Expanded(child: tab)).toList(),
      ),
    );
  }

  Widget _buildTabItem({
    required Color foreground,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool active = false,
    Color? activeColor,
  }) {
    final contentColor = active ? (activeColor ?? foreground) : foreground;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: contentColor,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: contentColor,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
