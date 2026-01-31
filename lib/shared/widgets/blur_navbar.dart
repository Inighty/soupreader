import 'dart:ui';
import 'package:flutter/material.dart';

/// 支持毛玻璃效果的底部导航栏
class BlurNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;

  const BlurNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
  });

  @override
  Widget build(BuildContext context) {
    // 获取底部安全区域高度
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            color: (backgroundColor ??
                    Theme.of(context)
                        .bottomNavigationBarTheme
                        .backgroundColor ??
                    Colors.black)
                .withOpacity(0.75), // 增加透明度以显示模糊效果
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: onTap,
                items: items,
                backgroundColor: Colors.transparent, // 必须透明
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor:
                    selectedItemColor ?? Theme.of(context).colorScheme.primary,
                unselectedItemColor: unselectedItemColor ??
                    Theme.of(context).unselectedWidgetColor,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                // iOS风格图标大小
                iconSize: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
