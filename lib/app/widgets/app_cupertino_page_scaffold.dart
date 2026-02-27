import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

typedef AppSliverBodyBuilder = Widget Function(BuildContext context);

/// 统一页面容器：导航栏 + 渐变背景 + SafeArea。
class AppCupertinoPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? middle;
  final Widget? leading;
  final Widget? trailing;
  final bool includeTopSafeArea;
  final bool includeBottomSafeArea;
  final bool useSliverNavigationBar;
  final Widget? largeTitle;
  final AppSliverBodyBuilder? sliverBodyBuilder;
  final ScrollController? sliverScrollController;
  final ScrollPhysics? sliverScrollPhysics;

  const AppCupertinoPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.middle,
    this.leading,
    this.trailing,
    this.includeTopSafeArea = true,
    this.includeBottomSafeArea = true,
    this.useSliverNavigationBar = false,
    this.largeTitle,
    this.sliverBodyBuilder,
    this.sliverScrollController,
    this.sliverScrollPhysics,
  });

  Widget? _buildNavBarItem(
    BuildContext context,
    Widget? child, {
    required Alignment alignment,
  }) {
    if (child == null) return null;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width * 0.42;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: child,
      ),
    );
  }

  Widget _buildBackground({
    required Color topLayer,
    required Color baseBackground,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            topLayer,
            baseBackground,
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildDefaultSliverBody() {
    return SliverSafeArea(
      // Sliver 导航栏已处理顶部安全区，这里只处理底部，避免双重 SafeArea。
      top: false,
      bottom: includeBottomSafeArea,
      sliver: SliverFillRemaining(
        hasScrollBody: true,
        child: PrimaryScrollController.none(
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final brightness = theme.brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark
        ? AppDesignTokens.borderDark.withValues(alpha: 0.85)
        : AppDesignTokens.borderLight;
    final baseBackground = theme.scaffoldBackgroundColor;
    final surface = isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.78)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.96);
    final topLayer = Color.alphaBlend(surface, baseBackground);
    final navBarBackground = Color.alphaBlend(
      (isDark ? AppDesignTokens.surfaceDark : AppDesignTokens.surfaceLight)
          .withValues(alpha: isDark ? 0.36 : 0.22),
      theme.barBackgroundColor,
    );
    final border = Border(bottom: BorderSide(color: borderColor, width: 0.5));

    if (!useSliverNavigationBar) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: middle ?? Text(title),
          leading: _buildNavBarItem(
            context,
            leading,
            alignment: Alignment.centerLeft,
          ),
          trailing: _buildNavBarItem(
            context,
            trailing,
            alignment: Alignment.centerRight,
          ),
          backgroundColor: navBarBackground,
          border: border,
        ),
        child: _buildBackground(
          topLayer: topLayer,
          baseBackground: baseBackground,
          child: SafeArea(
            top: includeTopSafeArea,
            bottom: includeBottomSafeArea,
            child: child,
          ),
        ),
      );
    }

    final bodySliver =
        sliverBodyBuilder?.call(context) ?? _buildDefaultSliverBody();

    return CupertinoPageScaffold(
      child: _buildBackground(
        topLayer: topLayer,
        baseBackground: baseBackground,
        child: CustomScrollView(
          primary: sliverScrollController == null,
          controller: sliverScrollController,
          physics: sliverScrollPhysics,
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: largeTitle ?? Text(title),
              middle: middle ?? Text(title),
              alwaysShowMiddle: false,
              leading: _buildNavBarItem(
                context,
                leading,
                alignment: Alignment.centerLeft,
              ),
              trailing: _buildNavBarItem(
                context,
                trailing,
                alignment: Alignment.centerRight,
              ),
              backgroundColor: navBarBackground,
              automaticBackgroundVisibility: false,
              border: border,
            ),
            bodySliver,
          ],
        ),
      ),
    );
  }
}
