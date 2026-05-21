// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_display_engine.dart';
import 'bookshelf_navigation.dart';
import 'bookshelf_view.dart';

extension BookshelfGroupBarWidgets on BookshelfViewState {
  Widget buildStyle1GroupBar() {
    final groups = visibleGroupsForStyle1();
    if (groups.isEmpty) return const SizedBox.shrink();
    final selectedIndex = resolveStyle1SelectedTabIndex(groups);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final activeColor = CupertinoTheme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: separatorColor,
            width: AppDesignTokens.hairlineBorderWidth,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            return buildStyle1GroupChip(
              group: group,
              index: index,
              selected: index == selectedIndex,
              activeColor: activeColor,
              separatorColor: separatorColor,
            );
          },
        ),
      ),
    );
  }

  Widget buildStyle1GroupChip({
    required BookshelfBookGroup group,
    required int index,
    required bool selected,
    required Color activeColor,
    required Color separatorColor,
  }) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final bgColor = selected
        ? activeColor.withValues(alpha: 0.14)
        : CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onStyle1GroupTap(index, group),
      onLongPress: () => onStyle1GroupLongPress(group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.45)
                : separatorColor.withValues(alpha: 0.8),
            width: AppDesignTokens.hairlineBorderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          group.groupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.2,
            color: selected ? activeColor : textColor,
          ),
        ),
      ),
    );
  }
}
