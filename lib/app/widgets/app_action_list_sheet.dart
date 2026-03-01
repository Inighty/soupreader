import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

class AppActionListItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDestructiveAction;

  const AppActionListItem({
    required this.value,
    required this.icon,
    required this.label,
    this.enabled = true,
    this.isDestructiveAction = false,
  });
}

Future<T?> showAppActionListSheet<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<AppActionListItem<T>> items,
  String cancelText = '取消',
  TextAlign titleAlign = TextAlign.left,
  bool showCancel = false,
  bool barrierDismissible = true,
  Color? accentColor,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _AppActionListSheet<T>(
      title: title,
      message: message,
      items: items,
      cancelText: cancelText,
      titleAlign: titleAlign,
      showCancel: showCancel,
      accentColor: accentColor,
    ),
  );
}

class _AppActionListSheet<T> extends StatelessWidget {
  static const double _radius = 18;
  static const double _maxHeightFactor = 0.74;
  static const double _rowHeight = 48;
  static const double _dividerHeight = 0.5;

  final String title;
  final String? message;
  final List<AppActionListItem<T>> items;
  final String cancelText;
  final TextAlign titleAlign;
  final bool showCancel;
  final Color? accentColor;

  const _AppActionListSheet({
    required this.title,
    required this.message,
    required this.items,
    required this.cancelText,
    required this.titleAlign,
    required this.showCancel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = _ActionListTokens.resolve(
      context: context,
      accentColor: accentColor,
    );
    final bottomInset = math.max(MediaQuery.of(context).padding.bottom, 8.0);
    final trimmedMessage = (message ?? '').trim();
    final maxHeight = MediaQuery.sizeOf(context).height * _maxHeightFactor;
    final children = _buildChildren(
      context,
      tokens: tokens,
      trimmedMessage: trimmedMessage,
    );

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(_radius)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(
    BuildContext context, {
    required _ActionListTokens tokens,
    required String trimmedMessage,
  }) {
    final dividerColor = CupertinoColors.systemGrey5.resolveFrom(context);

    final children = <Widget>[
      _SheetHeader(
        title: title,
        message: trimmedMessage,
        titleAlign: titleAlign,
        titleColor: tokens.labelColor,
        messageColor: tokens.subtleColor,
      ),
    ];

    if (items.isNotEmpty) {
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _ActionRow<T>(
                height: _rowHeight,
                item: items[i],
                accent: tokens.accent,
                labelColor: tokens.labelColor,
                destructiveColor: tokens.destructiveColor,
              ),
              if (i != items.length - 1)
                Container(height: _dividerHeight, color: dividerColor),
            ],
          ],
        ),
      );
    }

    if (showCancel) {
      children.addAll(
        [
          const SizedBox(height: 10),
          _CancelRow(
            height: _rowHeight,
            label: cancelText,
            labelColor: tokens.labelColor,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
    return children;
  }
}

class _ActionListTokens {
  final Color accent;
  final Color labelColor;
  final Color subtleColor;
  final Color destructiveColor;
  final Color sheetBg;

  const _ActionListTokens({
    required this.accent,
    required this.labelColor,
    required this.subtleColor,
    required this.destructiveColor,
    required this.sheetBg,
  });

  factory _ActionListTokens.resolve({
    required BuildContext context,
    required Color? accentColor,
  }) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final accent = accentColor ??
        (isDark
            ? AppDesignTokens.brandSecondary
            : AppDesignTokens.brandPrimary);
    return _ActionListTokens(
      accent: accent,
      labelColor: CupertinoColors.label.resolveFrom(context),
      subtleColor: CupertinoColors.secondaryLabel.resolveFrom(context),
      destructiveColor: CupertinoColors.systemRed.resolveFrom(context),
      sheetBg: CupertinoColors.systemBackground.resolveFrom(context),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String message;
  final TextAlign titleAlign;
  final Color titleColor;
  final Color messageColor;

  const _SheetHeader({
    required this.title,
    required this.message,
    required this.titleAlign,
    required this.titleColor,
    required this.messageColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAlign = switch (titleAlign) {
      TextAlign.left => CrossAxisAlignment.start,
      TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: resolvedAlign,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            title,
            textAlign: titleAlign,
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Text(
              message,
              textAlign: titleAlign,
              style: TextStyle(color: messageColor, fontSize: 13, height: 1.3),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  final double height;
  final AppActionListItem<T> item;
  final Color accent;
  final Color labelColor;
  final Color destructiveColor;

  const _ActionRow({
    required this.height,
    required this.item,
    required this.accent,
    required this.labelColor,
    required this.destructiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = item.enabled;
    final textColor = item.isDestructiveAction ? destructiveColor : labelColor;
    final iconColor = item.isDestructiveAction ? destructiveColor : accent;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: enabled ? () => Navigator.of(context).pop(item.value) : null,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
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

class _CancelRow extends StatelessWidget {
  final double height;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  const _CancelRow({
    required this.height,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = CupertinoColors.systemGrey5.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: _AppActionListSheet._dividerHeight, color: dividerColor),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onTap,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
