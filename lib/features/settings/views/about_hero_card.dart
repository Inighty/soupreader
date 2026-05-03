import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_ui_kit.dart';

/// 关于页顶部「应用名 + 版本 + 包名」的英雄卡片。
class AboutHeroCard extends StatelessWidget {
  const AboutHeroCard({
    super.key,
    required this.appName,
    required this.version,
    required this.versionSummary,
    required this.packageName,
  });

  final String appName;
  final String version;
  final String versionSummary;
  final String packageName;

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final theme = CupertinoTheme.of(context);
    final trimmed = packageName.trim();
    final packageText = trimmed.isEmpty ? '包名未读取' : trimmed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        borderColor: tokens.colors.separator.withValues(alpha: 0.72),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.colors.accent,
              ),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  CupertinoIcons.info_circle_fill,
                  color: CupertinoColors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.24,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    versionSummary,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: tokens.colors.secondaryLabel,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    packageText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 11,
                      color: tokens.colors.tertiaryLabel,
                      letterSpacing: -0.16,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'v$version',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.colors.accent,
                letterSpacing: -0.16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
