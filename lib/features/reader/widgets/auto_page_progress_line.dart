import 'package:flutter/cupertino.dart';

import 'auto_pager.dart';

/// 翻页模式自动阅读进度线，对标 legado AutoPager.onDraw 的彩色横线。
///
/// 随页面进度从顶部向底部移动，到达底部时触发翻页。
class AutoPageProgressLine extends StatefulWidget {
  final AutoPager autoPager;
  final Color color;

  const AutoPageProgressLine({
    super.key,
    required this.autoPager,
    required this.color,
  });

  @override
  State<AutoPageProgressLine> createState() => _AutoPageProgressLineState();
}

class _AutoPageProgressLineState extends State<AutoPageProgressLine> {
  @override
  void initState() {
    super.initState();
    widget.autoPager.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.autoPager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pager = widget.autoPager;
    if (!pager.isRunning ||
        pager.mode != AutoPagerMode.page ||
        pager.pageProgress <= 0) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final y = (pager.pageProgress * h).clamp(0.0, h);
        return Stack(
          children: [
            Positioned(
              top: y - 1,
              left: 0,
              right: 0,
              child: Container(
                height: 1.5,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}
