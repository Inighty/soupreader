import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';

/// 翻页阅读器组件（完全对标 flutter_reader 架构）
/// 支持多种翻页模式：slide、cover、simulation、none
class PagedReaderWidget extends StatefulWidget {
  final List<String> pages;
  final int initialPage;
  final PageTurnMode pageTurnMode;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final Function(int pageIndex)? onPageChanged;
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;
  final VoidCallback? onTap;

  // 状态栏参数
  final bool showStatusBar;
  final String chapterTitle;

  // 边距常量（对标 flutter_reader ReaderUtils）
  static const double topOffset = 37;
  static const double bottomOffset = 37;

  const PagedReaderWidget({
    super.key,
    required this.pages,
    this.initialPage = 0,
    required this.pageTurnMode,
    required this.textStyle,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.onPageChanged,
    this.onPrevChapter,
    this.onNextChapter,
    this.onTap,
    this.showStatusBar = true,
    this.chapterTitle = '',
  });

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentPage;

  // 覆盖/仿真翻页动画
  late AnimationController _animController;
  double _dragOffset = 0;
  bool _isDragging = false;
  int _targetPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
    _targetPage = _currentPage;
    _pageController = PageController(
      initialPage: _currentPage,
      keepPage: false,
    );
    _pageController.addListener(_onScroll);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animController.addListener(() {
      setState(() {});
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pages != widget.pages) {
      _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
      _targetPage = _currentPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {}

  void _onAnimationComplete() {
    if (_targetPage != _currentPage) {
      setState(() {
        _currentPage = _targetPage;
        _dragOffset = 0;
      });
      widget.onPageChanged?.call(_currentPage);
    } else {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  void _onTap(Offset position) {
    final screenWidth = MediaQuery.of(context).size.width;
    final xRate = position.dx / screenWidth;

    if (xRate > 0.33 && xRate < 0.66) {
      widget.onTap?.call();
    } else if (xRate >= 0.66) {
      _goNextPage();
    } else {
      _goPreviousPage();
    }
  }

  void _goPreviousPage() {
    if (_currentPage == 0) {
      widget.onPrevChapter?.call();
      return;
    }

    if (_usesCustomAnimation) {
      _targetPage = _currentPage - 1;
      _animateToPreviousPage();
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _goNextPage() {
    if (_currentPage >= widget.pages.length - 1) {
      widget.onNextChapter?.call();
      return;
    }

    if (_usesCustomAnimation) {
      _targetPage = _currentPage + 1;
      _animateToNextPage();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _animateToNextPage() {
    _animController.reset();
    _animController.forward();
    _animController.addListener(_animateNextListener);
  }

  void _animateNextListener() {
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _dragOffset = -screenWidth * _animController.value;
    });
  }

  void _animateToPreviousPage() {
    _animController.reset();
    _animController.forward();
    _animController.addListener(_animatePrevListener);
  }

  void _animatePrevListener() {
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _dragOffset = screenWidth * _animController.value;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _targetPage = index;
    });
    widget.onPageChanged?.call(index);
  }

  bool get _usesCustomAnimation {
    return widget.pageTurnMode == PageTurnMode.cover ||
        widget.pageTurnMode == PageTurnMode.simulation ||
        widget.pageTurnMode == PageTurnMode.none;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return Container(
        color: widget.backgroundColor,
        child: Center(
          child: Text('暂无内容', style: widget.textStyle),
        ),
      );
    }

    final topSafeHeight = MediaQuery.of(context).padding.top;
    final bottomSafeHeight = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // 翻页内容
          Positioned.fill(
            child: _usesCustomAnimation
                ? _buildCustomPageView()
                : _buildSlidePageView(),
          ),
          // 覆盖层
          _buildOverlayer(topSafeHeight, bottomSafeHeight),
        ],
      ),
    );
  }

  Widget _buildOverlayer(double topSafeHeight, double bottomSafeHeight) {
    if (!widget.showStatusBar) return const SizedBox.shrink();

    final format = DateFormat('HH:mm');
    final time = format.format(DateTime.now());
    final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
        const Color(0xff8B7961);

    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          10 + topSafeHeight,
          widget.padding.right,
          10 + bottomSafeHeight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapterTitle,
              style: widget.textStyle.copyWith(
                fontSize: 14,
                color: statusColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Expanded(child: SizedBox.shrink()),
            Row(
              children: [
                Text(
                  time,
                  style: widget.textStyle.copyWith(
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                Text(
                  '第${_currentPage + 1}/${widget.pages.length}页',
                  style: widget.textStyle.copyWith(
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 滑动翻页（slide模式）
  Widget _buildSlidePageView() {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      itemCount: widget.pages.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTapUp: (details) => _onTap(details.globalPosition),
          child: _buildPage(index),
        );
      },
    );
  }

  /// 自定义翻页（cover/simulation/none模式）
  Widget _buildCustomPageView() {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTapUp: (details) => _onTap(details.globalPosition),
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // 底层页面
          if (_dragOffset > 0 && _currentPage > 0)
            Positioned.fill(child: _buildPage(_currentPage - 1)),
          if (_dragOffset < 0 && _currentPage < widget.pages.length - 1)
            Positioned.fill(child: _buildPage(_currentPage + 1)),

          // 当前页面
          _buildAnimatedCurrentPage(screenWidth),
        ],
      ),
    );
  }

  Widget _buildAnimatedCurrentPage(double screenWidth) {
    double offset = 0;
    double shadowOpacity = 0;

    switch (widget.pageTurnMode) {
      case PageTurnMode.cover:
        // 覆盖效果：当前页滑出，下一页在底层
        offset = _dragOffset.clamp(-screenWidth, screenWidth);
        shadowOpacity = (_dragOffset.abs() / screenWidth * 0.3).clamp(0, 0.3);
        break;
      case PageTurnMode.simulation:
        // 仿真效果：类似覆盖但带有卷曲感（简化实现）
        offset = _dragOffset.clamp(-screenWidth, screenWidth);
        shadowOpacity = (_dragOffset.abs() / screenWidth * 0.4).clamp(0, 0.4);
        break;
      case PageTurnMode.none:
        // 无动画：不显示拖拽效果
        if (_dragOffset.abs() > screenWidth * 0.3) {
          return const SizedBox.shrink();
        }
        offset = 0;
        break;
      default:
        offset = _dragOffset;
    }

    return Positioned(
      left: offset,
      top: 0,
      bottom: 0,
      width: screenWidth,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: shadowOpacity > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: shadowOpacity),
                    blurRadius: 10,
                    offset: const Offset(-5, 0),
                  ),
                ]
              : null,
        ),
        child: _buildPage(_currentPage),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _animController.stop();
    _animController.removeListener(_animateNextListener);
    _animController.removeListener(_animatePrevListener);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _dragOffset += details.delta.dx;

      // 限制边界
      if (_currentPage == 0 && _dragOffset > 0) {
        _dragOffset = _dragOffset * 0.3; // 阻尼
      }
      if (_currentPage >= widget.pages.length - 1 && _dragOffset < 0) {
        _dragOffset = _dragOffset * 0.3; // 阻尼
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;

    // 判断是否翻页
    bool shouldTurnPage =
        _dragOffset.abs() > screenWidth * 0.3 || velocity.abs() > 500;

    if (shouldTurnPage) {
      if (_dragOffset > 0 && _currentPage > 0) {
        // 翻到上一页
        _targetPage = _currentPage - 1;
        _animateToPosition(screenWidth);
      } else if (_dragOffset < 0 && _currentPage < widget.pages.length - 1) {
        // 翻到下一页
        _targetPage = _currentPage + 1;
        _animateToPosition(-screenWidth);
      } else {
        // 回弹
        _targetPage = _currentPage;
        _animateToPosition(0);
      }
    } else {
      // 回弹
      _targetPage = _currentPage;
      _animateToPosition(0);
    }
  }

  void _animateToPosition(double targetOffset) {
    final startOffset = _dragOffset;
    _animController.reset();

    _animController.addListener(() {
      setState(() {
        _dragOffset =
            startOffset + (targetOffset - startOffset) * _animController.value;
      });
    });

    _animController.forward();
  }

  Widget _buildPage(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return Container(color: widget.backgroundColor);
    }

    final topSafeHeight = MediaQuery.of(context).padding.top;
    final bottomSafeHeight = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      margin: EdgeInsets.fromLTRB(
        widget.padding.left,
        topSafeHeight + PagedReaderWidget.topOffset,
        widget.padding.right,
        bottomSafeHeight + PagedReaderWidget.bottomOffset,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: widget.pages[index],
              style: widget.textStyle,
            ),
          ],
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }
}
