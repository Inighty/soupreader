import 'package:flutter/cupertino.dart';

class AppWebViewToolbar extends StatelessWidget {
  static const double height = 46;
  static const double _iconSize = 20;
  static const double _dividerHeight = 0.5;
  static const EdgeInsets _itemPadding = EdgeInsets.symmetric(horizontal: 10);

  final bool canGoBack;
  final bool canGoForward;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback? onMore;
  final VoidCallback? onToggleFullScreen;

  const AppWebViewToolbar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.isLoading,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    this.onMore,
    this.onToggleFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final border = CupertinoColors.separator.resolveFrom(context);
    final iconColor = CupertinoColors.label.resolveFrom(context);
    final disabledColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final accent = CupertinoTheme.of(context).primaryColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: _dividerHeight)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolbarIconButton(
                icon: CupertinoIcons.chevron_back,
                enabled: canGoBack,
                padding: _itemPadding,
                color: canGoBack ? iconColor : disabledColor,
                onPressed: onBack,
              ),
              _ToolbarIconButton(
                icon: CupertinoIcons.chevron_forward,
                enabled: canGoForward,
                padding: _itemPadding,
                color: canGoForward ? iconColor : disabledColor,
                onPressed: onForward,
              ),
              _ToolbarIconButton(
                icon: isLoading ? CupertinoIcons.xmark : CupertinoIcons.refresh,
                enabled: true,
                padding: _itemPadding,
                color: isLoading ? accent : iconColor,
                onPressed: onReload,
              ),
              if (onToggleFullScreen != null)
                _ToolbarIconButton(
                  icon: CupertinoIcons.fullscreen,
                  enabled: true,
                  padding: _itemPadding,
                  color: iconColor,
                  onPressed: onToggleFullScreen!,
                )
              else
                const SizedBox(width: _iconSize + 20),
              if (onMore != null)
                _ToolbarIconButton(
                  icon: CupertinoIcons.ellipsis_circle,
                  enabled: true,
                  padding: _itemPadding,
                  color: iconColor,
                  onPressed: onMore!,
                )
              else
                const SizedBox(width: _iconSize + 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.enabled,
    required this.padding,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: padding,
      minimumSize: const Size(44, 44),
      onPressed: enabled ? onPressed : null,
      child: Icon(icon, size: AppWebViewToolbar._iconSize, color: color),
    );
  }
}
