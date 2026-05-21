import 'dart:ui';

import 'package:flutter/cupertino.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import 'reader_menu_surface_style.dart';

export 'reader_bottom_menu_compat.dart';

const Key _readerTopMenuPanelKey = Key('reader_top_menu_panel');
const Key _readerTopMenuChangeSourceKey = Key('reader_top_menu_change_source');
const Key _readerTopMenuRefreshKey = Key('reader_top_menu_refresh');
const Key _readerTopMenuOfflineCacheKey = Key('reader_top_menu_offline_cache');
const Key _readerTopMenuTocRuleKey = Key('reader_top_menu_toc_rule');
const Key _readerTopMenuSetCharsetKey = Key('reader_top_menu_set_charset');

class ReaderTopMenu extends StatelessWidget {
  final String bookTitle;
  final String chapterTitle;
  final String? chapterUrl;
  final String? sourceName;
  final ReadingThemeColors currentTheme;
  final VoidCallback onOpenBookInfo;
  final VoidCallback onOpenChapterLink;
  final VoidCallback onToggleChapterLinkOpenMode;
  final VoidCallback? onChangeSource;
  final VoidCallback? onChangeSourceLongPress;
  final VoidCallback? onRefresh;
  final VoidCallback? onRefreshLongPress;
  final VoidCallback? onOfflineCache;
  final VoidCallback? onTocRule;
  final VoidCallback? onSetCharset;
  final VoidCallback onShowSourceActions;
  final VoidCallback onShowMoreMenu;
  final VoidCallback? onBack;
  final bool showChangeSourceAction;
  final bool showRefreshAction;
  final bool showDownloadAction;
  final bool showTocRuleAction;
  final bool showSetCharsetAction;
  final bool showSourceAction;
  final bool showChapterLink;
  final bool showTitleAddition;
  final bool readBarStyleFollowPage;
  final Animation<double>? menuFadeAnimation;
  final Animation<Offset>? menuSlideAnimation;

  const ReaderTopMenu({
    super.key,
    required this.bookTitle,
    required this.chapterTitle,
    this.chapterUrl,
    this.sourceName,
    required this.currentTheme,
    required this.onOpenBookInfo,
    required this.onOpenChapterLink,
    required this.onToggleChapterLinkOpenMode,
    this.onChangeSource,
    this.onChangeSourceLongPress,
    this.onRefresh,
    this.onRefreshLongPress,
    this.onOfflineCache,
    this.onTocRule,
    this.onSetCharset,
    required this.onShowSourceActions,
    required this.onShowMoreMenu,
    this.onBack,
    this.showChangeSourceAction = false,
    this.showRefreshAction = false,
    this.showDownloadAction = false,
    this.showTocRuleAction = false,
    this.showSetCharsetAction = false,
    this.showSourceAction = true,
    this.showChapterLink = true,
    this.showTitleAddition = true,
    this.readBarStyleFollowPage = false,
    this.menuFadeAnimation,
    this.menuSlideAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final narrowScreen = screenWidth < 390;
    final horizontalPadding = narrowScreen ? 8.0 : 12.0;
    final source = sourceName?.trim() ?? '';
    final chapterLabel = chapterTitle.trim().isEmpty ? '暂无章节' : chapterTitle;
    final chapterUrlLabel = chapterUrl?.trim() ?? '';
    final sourceActionLabel = source.isEmpty ? '书源' : source;
    final style = resolveReaderMenuSurfaceStyle(
      currentTheme: currentTheme,
      readBarStyleFollowPage: readBarStyleFollowPage,
    );

    final fadeAnim = menuFadeAnimation;
    final slideAnim = menuSlideAnimation;

    Widget panel = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          key: _readerTopMenuPanelKey,
          padding: EdgeInsets.only(
            top: mediaQuery.padding.top + 8,
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: style.panelBackground.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: style.borderColor.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildBackButton(
                    onTap: onBack ?? () => Navigator.pop(context),
                    color: style.primaryText,
                  ),
                  Expanded(
                    child: _buildSemanticTapTarget(
                      semanticLabel: '打开书籍详情，$bookTitle',
                      onTap: onOpenBookInfo,
                      child: Text(
                        bookTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: style.primaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (showChangeSourceAction && onChangeSource != null) ...[
                    _buildNavButton(
                      key: _readerTopMenuChangeSourceKey,
                      icon: CupertinoIcons.arrow_right_arrow_left,
                      semanticLabel: '切换书源',
                      onTap: onChangeSource,
                      onLongPress: onChangeSourceLongPress,
                      color: style.primaryText,
                    ),
                  ],
                  if (showRefreshAction && onRefresh != null) ...[
                    _buildNavButton(
                      key: _readerTopMenuRefreshKey,
                      icon: CupertinoIcons.refresh,
                      semanticLabel: '刷新当前章节',
                      onTap: onRefresh,
                      onLongPress: onRefreshLongPress,
                      color: style.primaryText,
                    ),
                  ],
                  if (showDownloadAction && onOfflineCache != null) ...[
                    _buildNavButton(
                      key: _readerTopMenuOfflineCacheKey,
                      icon: CupertinoIcons.cloud_download,
                      semanticLabel: '离线缓存',
                      onTap: onOfflineCache,
                      color: style.primaryText,
                    ),
                  ],
                  if (showTocRuleAction && onTocRule != null) ...[
                    _buildNavButton(
                      key: _readerTopMenuTocRuleKey,
                      icon: CupertinoIcons.list_bullet,
                      semanticLabel: '目录规则',
                      onTap: onTocRule,
                      color: style.primaryText,
                    ),
                  ],
                  if (showSetCharsetAction && onSetCharset != null) ...[
                    _buildNavButton(
                      key: _readerTopMenuSetCharsetKey,
                      icon: CupertinoIcons.textformat,
                      semanticLabel: '设置字符编码',
                      onTap: onSetCharset,
                      color: style.primaryText,
                    ),
                  ],
                  _buildNavButton(
                    icon: CupertinoIcons.ellipsis_circle,
                    semanticLabel: '更多操作',
                    onTap: onShowMoreMenu,
                    color: style.primaryText,
                  ),
                ],
              ),
              if (showTitleAddition) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compactInfo =
                              narrowScreen || constraints.maxWidth < 340;
                          final showUrl = showTitleAddition &&
                              showChapterLink &&
                              chapterUrlLabel.isNotEmpty &&
                              !compactInfo;
                          final chapterFontSize = compactInfo ? 12.0 : 12.5;
                          final urlFontSize = compactInfo ? 10.5 : 11.0;
                          final sourceMaxWidth = compactInfo ? 96.0 : 120.0;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSemanticTapTarget(
                                      semanticLabel: '打开章节链接，$chapterLabel',
                                      onTap: onOpenChapterLink,
                                      onLongPress: onToggleChapterLinkOpenMode,
                                      child: Text(
                                        chapterLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: style.secondaryText,
                                          fontSize: chapterFontSize,
                                        ),
                                      ),
                                    ),
                                    if (showUrl) ...[
                                      const SizedBox(height: 1),
                                      _buildSemanticTapTarget(
                                        semanticLabel: '打开章节地址',
                                        onTap: onOpenChapterLink,
                                        onLongPress:
                                            onToggleChapterLinkOpenMode,
                                        child: Text(
                                          chapterUrlLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: style.tertiaryText,
                                            fontSize: urlFontSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (showSourceAction) ...[
                                const SizedBox(width: 8),
                                _buildSourceActionChip(
                                  label: sourceActionLabel,
                                  onTap: onShowSourceActions,
                                  textColor: style.primaryText,
                                  backgroundColor: style.controlBackground,
                                  borderColor: style.controlBorder,
                                  maxWidth: sourceMaxWidth,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (slideAnim != null && fadeAnim != null) {
      panel = SlideTransition(
        position: slideAnim,
        child: FadeTransition(
          opacity: fadeAnim,
          child: panel,
        ),
      );
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: panel,
    );
  }

  Widget _buildSemanticTapTarget({
    required String semanticLabel,
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ExcludeSemantics(child: child),
      ),
    );
  }

  Widget _buildBackButton({
    required VoidCallback onTap,
    required Color color,
  }) {
    return Semantics(
      button: true,
      label: '返回',
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(CupertinoIcons.back, color: color, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    Key? key,
    required IconData icon,
    required String semanticLabel,
    required VoidCallback? onTap,
    VoidCallback? onLongPress,
    required Color color,
  }) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: CupertinoButton(
        key: key,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: onLongPress,
          child: ExcludeSemantics(
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceActionChip({
    required String label,
    required VoidCallback onTap,
    required Color textColor,
    required Color backgroundColor,
    required Color borderColor,
    required double maxWidth,
  }) {
    return Semantics(
      button: true,
      label: '选择书源，$label',
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: ExcludeSemantics(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  BorderRadius.circular(AppDesignTokens.radiusControl),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 10,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
