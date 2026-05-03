import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/source_consistent_card.dart';
import '../../../app/widgets/source_group_badge.dart';
import '../../../core/models/book_source.dart';
import '../../source/services/source/explore_kinds_service.dart';

/// 发现页中单个书源的卡片：标题、分组徽标、URL；展开后渲染发现入口。
class DiscoverySourceItemCard extends StatelessWidget {
  const DiscoverySourceItemCard({
    super.key,
    required this.source,
    required this.expanded,
    required this.loadingKinds,
    required this.kinds,
    required this.onToggle,
    required this.onLongPress,
    required this.onOpenKind,
  });

  final BookSource source;
  final bool expanded;
  final bool loadingKinds;
  final List<SourceExploreKind> kinds;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final void Function(SourceExploreKind kind) onOpenKind;

  static const Duration _expandCollapseDuration = AppDesignTokens.motionNormal;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    final groupText = (source.bookSourceGroup ?? '').trim();
    final secondaryLabel = uiTokens.colors.secondaryLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SourceConsistentCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              theme: theme,
              uiTokens: uiTokens,
              groupText: groupText,
              secondaryLabel: secondaryLabel,
            ),
            AnimatedSize(
              duration: _expandCollapseDuration,
              curve: Curves.easeOutQuart,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: expanded
                  ? _buildExpandedKindsSection(
                      theme: theme,
                      uiTokens: uiTokens,
                      secondaryLabel: secondaryLabel,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required String groupText,
    required Color secondaryLabel,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SourceUiTokens.minTapSize),
        child: Row(
          children: [
            Expanded(
              child: _buildInfoBlock(
                theme: theme,
                uiTokens: uiTokens,
                groupText: groupText,
                secondaryLabel: secondaryLabel,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              expanded
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_forward,
              size: 15,
              color: uiTokens.colors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock({
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required String groupText,
    required Color secondaryLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                source.bookSourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: SourceUiTokens.itemTitleSize,
                  fontWeight: FontWeight.w600,
                  color: uiTokens.colors.foreground,
                ),
              ),
            ),
            if (groupText.isNotEmpty) ...[
              const SizedBox(width: 8),
              SourceGroupBadge(
                text: groupText,
                textColor: secondaryLabel.withValues(alpha: 0.9),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          source.bookSourceUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.textStyle.copyWith(
            fontSize: SourceUiTokens.itemMetaSize,
            color: uiTokens.colors.tertiaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedKindsSection({
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required Color secondaryLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          height: AppDesignTokens.hairlineBorderWidth,
          color: uiTokens.colors.separator,
        ),
        const SizedBox(height: 8),
        _buildKindsBody(
          theme: theme,
          uiTokens: uiTokens,
          secondaryLabel: secondaryLabel,
        ),
      ],
    );
  }

  Widget _buildKindsBody({
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required Color secondaryLabel,
  }) {
    if (loadingKinds) {
      return _buildLoadingRow(theme: theme, secondaryLabel: secondaryLabel);
    }
    if (kinds.isEmpty) {
      return Text(
        '暂无发现入口',
        style: theme.textTheme.textStyle.copyWith(
          fontSize: SourceUiTokens.discoveryMetaTextSize,
          color: secondaryLabel,
        ),
      );
    }
    return _buildKindsWrap(theme: theme, uiTokens: uiTokens);
  }

  Widget _buildLoadingRow({
    required CupertinoThemeData theme,
    required Color secondaryLabel,
  }) {
    return Row(
      children: [
        const CupertinoActivityIndicator(),
        const SizedBox(width: 8),
        Text(
          '正在加载发现入口…',
          style: theme.textTheme.textStyle.copyWith(
            fontSize: SourceUiTokens.discoveryMetaTextSize,
            color: secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildKindsWrap({
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final chips = <Widget>[];
        for (final kind in kinds) {
          if (kind.style?.layoutWrapBefore == true) {
            chips.add(SizedBox(width: maxWidth, height: 0));
          }
          final width = _kindWidth(kind.style, maxWidth);
          final chip = _buildKindChip(
            context,
            kind,
            theme: theme,
            uiTokens: uiTokens,
          );
          chips.add(width == null ? chip : SizedBox(width: width, child: chip));
        }
        return Wrap(
          spacing: SourceUiTokens.discoveryHeaderGap,
          runSpacing: SourceUiTokens.discoveryHeaderGap,
          children: chips,
        );
      },
    );
  }

  Widget _buildKindChip(
    BuildContext context,
    SourceExploreKind kind, {
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
  }) {
    final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
    final url = kind.url?.trim() ?? '';
    final isEnabled = url.isNotEmpty;
    final isError = title.startsWith('ERROR:');
    final normalBackground =
        CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final enabledBackground =
        CupertinoColors.secondarySystemFill.resolveFrom(context);

    final backgroundColor = isError
        ? uiTokens.colors.destructive.withValues(alpha: 0.1)
        : isEnabled
            ? enabledBackground
            : normalBackground;
    final textColor = isError
        ? uiTokens.colors.destructive
        : isEnabled
            ? uiTokens.colors.foreground
            : uiTokens.colors.tertiaryLabel;
    final resolvedBorderColor = isError
        ? uiTokens.colors.destructive.withValues(alpha: 0.4)
        : uiTokens.colors.separator.withValues(alpha: 0.55);

    return _DiscoveryKindPill(
      uiTokens: uiTokens,
      backgroundColor: backgroundColor,
      borderColor: resolvedBorderColor,
      onTap: isEnabled ? () => onOpenKind(kind) : null,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.textStyle.copyWith(
          fontSize: SourceUiTokens.actionTextSize,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static double? _kindWidth(SourceExploreKindStyle? style, double maxWidth) {
    if (style == null) return null;
    var basis = style.layoutFlexBasisPercent;
    if (basis > 1 && basis <= 100) {
      basis = basis / 100;
    }
    if (basis > 0 && basis <= 1) {
      return (maxWidth * basis).clamp(64.0, maxWidth).toDouble();
    }
    if (style.layoutFlexGrow > 0) {
      return maxWidth;
    }
    return null;
  }
}

class _DiscoveryKindPill extends StatelessWidget {
  const _DiscoveryKindPill({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.uiTokens,
    required this.onTap,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final AppUiTokens uiTokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tapHandler = onTap == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onTap!();
          };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tapHandler,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(uiTokens.radii.control),
          border: Border.all(
            color: borderColor,
            width: SourceUiTokens.borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SourceUiTokens.discoveryChipHorizontalPadding,
            vertical: SourceUiTokens.discoveryChipVerticalPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}
