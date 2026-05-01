import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/theme/design_tokens.dart';

Color resolveSourceWebViewAccentColor(BuildContext context) {
  final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
  return isDark
      ? AppDesignTokens.brandSecondary
      : AppDesignTokens.brandPrimary;
}

class SourceWebViewProgressBar extends StatelessWidget {
  const SourceWebViewProgressBar({
    super.key,
    required this.showProgress,
    required this.progress,
    required this.isLoading,
    this.height = 2,
    this.minFactor = 0.08,
  });

  final bool showProgress;
  final int progress;
  final bool isLoading;
  final double height;
  final double minFactor;

  @override
  Widget build(BuildContext context) {
    if (!showProgress) return const SizedBox.shrink();
    final factor = progress <= 0 && isLoading ? minFactor : (progress / 100.0);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: factor.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: resolveSourceWebViewAccentColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SourceWebViewHintBanner extends StatelessWidget {
  const SourceWebViewHintBanner({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 8),
  });

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final value = text.trim();
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
