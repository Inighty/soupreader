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
  bool barrierDismissible = true,
  Color? accentColor,
}) {
  final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
  final barrier = isDark ? const Color(0x80000000) : const Color(0x4D000000);
  return showCupertinoModalPopup<T>(
    context: context,
    barrierColor: barrier,
    barrierDismissible: barrierDismissible,
    builder: (_) => _AppActionListSheet<T>(
      title: title,
      message: message,
      items: items,
      cancelText: cancelText,
      titleAlign: titleAlign,
      accentColor: accentColor,
    ),
  );
}

class _AppActionListSheet<T> extends StatelessWidget {
  static const double _radius = 18;
  static const double _handleWidth = 36;
  static const double _handleHeight = 4;

  final String title;
  final String? message;
  final List<AppActionListItem<T>> items;
  final String cancelText;
  final TextAlign titleAlign;
  final Color? accentColor;

  const _AppActionListSheet({
    required this.title,
    required this.message,
    required this.items,
    required this.cancelText,
    required this.titleAlign,
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
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: children,
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
    final children = <Widget>[
      _SheetHeader(
        title: title,
        message: trimmedMessage,
        titleAlign: titleAlign,
        titleColor: tokens.labelColor,
        messageColor: tokens.subtleColor,
        handleColor: tokens.handleColor,
      ),
    ];
    if (items.isNotEmpty) {
      children.add(
        CupertinoListSection.insetGrouped(
          children: [
            for (final item in items)
              _ActionRow<T>(
                item: item,
                accent: tokens.accent,
                labelColor: tokens.labelColor,
                destructiveColor: tokens.destructiveColor,
              ),
          ],
        ),
      );
    }
    children.add(
      CupertinoListSection.insetGrouped(
        children: [
          CupertinoListTile.notched(
            title: Text(
              cancelText,
              style: TextStyle(
                color: tokens.labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    return children;
  }
}

class _ActionListTokens {
  final Color accent;
  final Color labelColor;
  final Color subtleColor;
  final Color destructiveColor;
  final Color handleColor;
  final Color sheetBg;

  const _ActionListTokens({
    required this.accent,
    required this.labelColor,
    required this.subtleColor,
    required this.destructiveColor,
    required this.handleColor,
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
      handleColor:
          CupertinoColors.systemGrey3.resolveFrom(context).withValues(alpha: 0.72),
      sheetBg: CupertinoColors.systemGroupedBackground.resolveFrom(context),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String message;
  final TextAlign titleAlign;
  final Color titleColor;
  final Color messageColor;
  final Color handleColor;

  const _SheetHeader({
    required this.title,
    required this.message,
    required this.titleAlign,
    required this.titleColor,
    required this.messageColor,
    required this.handleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _AppActionListSheet._handleWidth,
          height: _AppActionListSheet._handleHeight,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
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
              textAlign: TextAlign.center,
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
  final AppActionListItem<T> item;
  final Color accent;
  final Color labelColor;
  final Color destructiveColor;

  const _ActionRow({
    required this.item,
    required this.accent,
    required this.labelColor,
    required this.destructiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = item.enabled;
    final color = item.isDestructiveAction ? destructiveColor : accent;
    final textColor = item.isDestructiveAction ? destructiveColor : labelColor;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CupertinoListTile.notched(
        leading: Icon(item.icon, size: 18, color: color),
        title: Text(
          item.label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: enabled ? () => Navigator.of(context).pop(item.value) : null,
      ),
    );
  }
}
