import 'package:flutter/cupertino.dart';

const Duration _kBottomDialogDuration = Duration(milliseconds: 260);

Future<T?> showCupertinoBottomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  String? barrierLabel,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
  final resolvedBarrierColor = barrierColor ??
      (isDark ? const Color(0x99000000) : const Color(0x4D000000));
  return navigator.push<T>(
    _CupertinoBottomDialogRoute<T>(
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel ?? '关闭弹窗',
      barrierColor: resolvedBarrierColor,
      settings: routeSettings,
    ),
  );
}

class _CupertinoBottomDialogRoute<T> extends PopupRoute<T> {
  _CupertinoBottomDialogRoute({
    required this.builder,
    required this.barrierDismissible,
    required this.barrierLabel,
    required this.barrierColor,
    super.settings,
  });

  final WidgetBuilder builder;

  @override
  final bool barrierDismissible;

  @override
  final String barrierLabel;

  @override
  final Color barrierColor;

  @override
  Duration get transitionDuration => _kBottomDialogDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: builder(context),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final offsetTween = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: offsetTween,
        child: child,
      ),
    );
  }
}
