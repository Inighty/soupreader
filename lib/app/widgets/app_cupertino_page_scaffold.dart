import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 统一页面容器：导航栏 + 渐变背景 + SafeArea。
class AppCupertinoPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final bool includeTopSafeArea;
  final bool includeBottomSafeArea;

  const AppCupertinoPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.leading,
    this.trailing,
    this.includeTopSafeArea = false,
    this.includeBottomSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final isDark = shad.brightness == Brightness.dark;
    final borderColor =
        scheme.border.withValues(alpha: isDark ? 0.85 : 1);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        leading: leading,
        trailing: trailing,
        backgroundColor: theme.barBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark
                  ? scheme.card.withValues(alpha: 0.78)
                  : scheme.card.withValues(alpha: 0.96),
              scheme.background,
            ],
          ),
        ),
        child: SafeArea(
          top: includeTopSafeArea,
          bottom: includeBottomSafeArea,
          child: child,
        ),
      ),
    );
  }
}
