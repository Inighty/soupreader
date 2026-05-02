import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../models/reading_settings.dart';

const int _kQuickChipCount = 4;

/// 快速面板"背景文字样式"行：横向样式 chip + 共用排版开关 + 「+」新增 + 「⋯」更多。
class ReaderStyleThemePickerRow extends StatelessWidget {
  final ReadingSettings draft;
  final List<ReadStyleConfig> fallbackStyleConfigs;
  final Color accent;
  final bool isDark;
  final ValueChanged<ReadingSettings> onApply;
  final VoidCallback onAddNew;
  final void Function(List<ReadStyleConfig> configs, int selectedIndex)
      onOpenList;
  final void Function(int index, ReadStyleConfig config,
      List<ReadStyleConfig> configs) onOpenEdit;

  const ReaderStyleThemePickerRow({
    super.key,
    required this.draft,
    required this.fallbackStyleConfigs,
    required this.accent,
    required this.isDark,
    required this.onApply,
    required this.onAddNew,
    required this.onOpenList,
    required this.onOpenEdit,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final mutedColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    final configs = draft.readStyleConfigs.isNotEmpty
        ? draft.readStyleConfigs
        : fallbackStyleConfigs;
    final themes = configs
        .map(
          (c) => ReadingThemeColors(
            background: Color(c.backgroundColor),
            text: Color(c.textColor),
            name: c.name.trim().isEmpty ? '文字' : c.name.trim(),
          ),
        )
        .toList(growable: false);
    final safeSelected =
        (draft.themeIndex >= 0 && draft.themeIndex < themes.length)
            ? draft.themeIndex
            : 0;
    final borderNormal = CupertinoColors.separator.resolveFrom(context);
    final visibleCount = themes.length.clamp(0, _kQuickChipCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('背景文字样式',
                  style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w400)),
              const Spacer(),
              Text('共用排版',
                  style: TextStyle(color: mutedColor, fontSize: 13)),
              const SizedBox(width: 4),
              CupertinoSwitch(
                value: draft.shareLayout,
                activeTrackColor: accent,
                onChanged: (v) => onApply(draft.copyWith(shareLayout: v)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _AddCell(
                  isDark: isDark,
                  borderNormal: borderNormal,
                  onTap: onAddNew,
                ),
                const SizedBox(width: 6),
                for (var i = 0; i < visibleCount; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ThemeChip(
                      theme: themes[i],
                      selected: i == safeSelected,
                      accent: accent,
                      borderNormal: borderNormal,
                      onTap: () =>
                          onApply(draft.copyWith(themeIndex: i)),
                      onLongPress: i < configs.length
                          ? () => onOpenEdit(i, configs[i], configs)
                          : null,
                    ),
                  ),
                _MoreCell(
                  isDark: isDark,
                  borderNormal: borderNormal,
                  onTap: () => onOpenList(configs, safeSelected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCell extends StatelessWidget {
  final bool isDark;
  final Color borderNormal;
  final VoidCallback onTap;

  const _AddCell({
    required this.isDark,
    required this.borderNormal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.08)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final iconColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderNormal, width: 0.5),
        ),
        child: Icon(
          CupertinoIcons.add,
          color: iconColor,
          size: 20,
        ),
      ),
    );
  }
}

class _MoreCell extends StatelessWidget {
  final bool isDark;
  final Color borderNormal;
  final VoidCallback onTap;

  const _MoreCell({
    required this.isDark,
    required this.borderNormal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.08)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final iconColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderNormal, width: 0.5),
        ),
        child: Icon(
          CupertinoIcons.ellipsis,
          color: iconColor,
          size: 20,
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final ReadingThemeColors theme;
  final bool selected;
  final Color accent;
  final Color borderNormal;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ThemeChip({
    required this.theme,
    required this.selected,
    required this.accent,
    required this.borderNormal,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent : borderNormal,
            width: selected ? 2.0 : 0.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        padding: const EdgeInsets.all(6),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                theme.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.text.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark,
                    color: CupertinoColors.white,
                    size: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
