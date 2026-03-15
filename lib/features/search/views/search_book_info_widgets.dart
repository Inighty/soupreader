import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';

class SearchBookInfoCardContainer extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;

  const SearchBookInfoCardContainer({
    super.key,
    required this.padding,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = SourceUiTokens.borderWidth,
    this.borderRadius = SourceUiTokens.radiusCard,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBackground =
        backgroundColor ?? SourceUiTokens.resolveCardBackgroundColor(context);
    final resolvedBorder =
        borderColor ?? SourceUiTokens.resolveSeparatorColor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: resolvedBorder,
          width: borderWidth,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class SearchBookInfoHeroBackground extends StatelessWidget {
  final String coverUrl;
  final String title;
  final String author;

  const SearchBookInfoHeroBackground({
    super.key,
    required this.coverUrl,
    required this.title,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    const blurSigma = 18.0;
    const blurScale = 1.08;

    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Transform.scale(
          scale: blurScale,
          child: AppCoverImage(
            urlOrPath: coverUrl,
            title: title,
            author: author,
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
            fit: BoxFit.cover,
            showTextOnPlaceholder: false,
          ),
        ),
      ),
    );
  }
}

class SearchBookInfoMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;
  final bool isLast;

  const SearchBookInfoMetaLine({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final borderColor = SourceUiTokens.resolveSeparatorColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: borderColor.withValues(alpha: 0.6),
                  width: SourceUiTokens.borderWidth,
                ),
              ),
            ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: secondaryTextColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle.copyWith(
                fontSize: SourceUiTokens.itemMetaSize,
                color: secondaryTextColor,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class SearchBookInfoMetaActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const SearchBookInfoMetaActionChip({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final disabledColor = CupertinoColors.inactiveGray.resolveFrom(context);
    final resolvedColor = onPressed == null ? disabledColor : color;
    final resolvedBackground = resolvedColor.withValues(alpha: 0.12);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: resolvedBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: textStyle.copyWith(
            fontSize: SourceUiTokens.itemMetaSize,
            color: resolvedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class SearchBookInfoStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const SearchBookInfoStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textStyle.copyWith(
          fontSize: SourceUiTokens.itemMetaSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
