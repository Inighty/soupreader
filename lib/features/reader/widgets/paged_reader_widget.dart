import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';

/// 翻页阅读器组件（参考 Legado 实现）
/// 支持滑动跨章节翻页
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

  // 状态栏
  final bool showStatusBar;
  final String chapterTitle;

  // 章节信息（用于判断是否可以跨章节）
  final bool hasPrevChapter;
  final bool hasNextChapter;

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
    this.hasPrevChapter = true,
    this.hasNextChapter = true,
  });

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with SingleTickerProviderStateMixin {
  late int _currentPage;
  late AnimationController _animController;

  // 翻页状态
  double _dragOffset = 0;
  bool _isDragging = false;
  _PageDirection _direction = _PageDirection.none;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _maxPageIndex);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  int get _maxPageIndex => widget.pages.isEmpty ? 0 : widget.pages.length - 1;

  /// 对标 Legado hasNext: 有下一页或有下一章
  bool get _hasNext => _currentPage < _maxPageIndex || widget.hasNextChapter;

  /// 对标 Legado hasPrev: 有上一页或有上一章
  bool get _hasPrev => _currentPage > 0 || widget.hasPrevChapter;

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pages != widget.pages) {
      _currentPage = widget.initialPage.clamp(0, _maxPageIndex);
      _dragOffset = 0;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTap(Offset position) {
    if (_isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final xRate = position.dx / screenWidth;

    if (xRate > 0.33 && xRate < 0.66) {
      widget.onTap?.call();
    } else if (xRate >= 0.66) {
      _goNext();
    } else {
      _goPrev();
    }
  }

  /// 对标 Legado moveToNext
  void _goNext() {
    if (!_hasNext) return;

    if (_currentPage >= _maxPageIndex) {
      // 已是最后一页，切换到下一章
      widget.onNextChapter?.call();
    } else {
      _direction = _PageDirection.next;
      _animateToPage(_currentPage + 1);
    }
  }

  /// 对标 Legado moveToPrev
  void _goPrev() {
    if (!_hasPrev) return;

    if (_currentPage <= 0) {
      // 已是第一页，切换到上一章
      widget.onPrevChapter?.call();
    } else {
      _direction = _PageDirection.prev;
      _animateToPage(_currentPage - 1);
    }
  }

  void _animateToPage(int targetPage) {
    if (_isAnimating) return;
    _isAnimating = true;

    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        _direction == _PageDirection.next ? -screenWidth : screenWidth;

    final startOffset = _dragOffset;

    _animController.reset();
    _animController.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffset = startOffset +
              (targetOffset - startOffset) *
                  Curves.easeOutCubic.transform(_animController.value);
        });
      }
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentPage = targetPage;
          _dragOffset = 0;
          _direction = _PageDirection.none;
          _isAnimating = false;
        });
        widget.onPageChanged?.call(_currentPage);
        _animController.removeListener(() {});
      }
    });

    _animController.forward();
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

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildPageContent(),
          ),
          _buildOverlayer(topSafe, bottomSafe),
        ],
      ),
    );
  }

  Widget _buildOverlayer(double topSafe, double bottomSafe) {
    if (!widget.showStatusBar) return const SizedBox.shrink();

    final time = DateFormat('HH:mm').format(DateTime.now());
    final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
        const Color(0xff8B7961);

    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          10 + topSafe,
          widget.padding.right,
          10 + bottomSafe,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapterTitle,
              style:
                  widget.textStyle.copyWith(fontSize: 14, color: statusColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Expanded(child: SizedBox.shrink()),
            Row(
              children: [
                Text(time,
                    style: widget.textStyle
                        .copyWith(fontSize: 11, color: statusColor)),
                const Expanded(child: SizedBox.shrink()),
                Text(
                  '${_currentPage + 1}/${widget.pages.length}',
                  style: widget.textStyle
                      .copyWith(fontSize: 11, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    // slide 模式使用 PageView
    if (widget.pageTurnMode == PageTurnMode.slide) {
      return _buildSlidePageView();
    }
    // cover/simulation/none 使用自定义手势
    return _buildCustomPageView();
  }

  Widget _buildSlidePageView() {
    return PageView.builder(
      controller: PageController(initialPage: _currentPage),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.pages.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        widget.onPageChanged?.call(index);

        // 滑动到边界时自动切换章节
        if (index == 0 && _currentPage == 0) {
          // 可能需要上一章（由 PageView 边界处理）
        } else if (index == _maxPageIndex) {
          // 在最后一页继续滑动会触发下一章
        }
      },
      itemBuilder: (context, index) {
        return GestureDetector(
          onTapUp: (d) => _onTap(d.globalPosition),
          child: _buildPage(index),
        );
      },
    );
  }

  Widget _buildCustomPageView() {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.globalPosition),
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // 底层：目标页面
          if (_direction == _PageDirection.prev && _currentPage > 0)
            Positioned.fill(child: _buildPage(_currentPage - 1)),
          if (_direction == _PageDirection.next && _currentPage < _maxPageIndex)
            Positioned.fill(child: _buildPage(_currentPage + 1)),

          // 顶层：当前页面（带动画）
          _buildCurrentPageWithAnimation(screenWidth),
        ],
      ),
    );
  }

  Widget _buildCurrentPageWithAnimation(double screenWidth) {
    double offset = _dragOffset.clamp(-screenWidth, screenWidth);
    double shadowOpacity = 0;

    switch (widget.pageTurnMode) {
      case PageTurnMode.cover:
        // 覆盖效果：当前页滑出覆盖
        shadowOpacity = (offset.abs() / screenWidth * 0.3).clamp(0, 0.3);
        break;
      case PageTurnMode.simulation:
        // 仿真效果（简化版）
        shadowOpacity = (offset.abs() / screenWidth * 0.4).clamp(0, 0.4);
        break;
      case PageTurnMode.none:
        // 无动画：不显示中间状态
        if (!_isAnimating && offset.abs() > 20) {
          return const SizedBox.shrink();
        }
        offset = 0;
        break;
      default:
        break;
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
                    blurRadius: 15,
                    offset: Offset(offset > 0 ? -5 : 5, 0),
                  ),
                ]
              : null,
        ),
        child: _buildPage(_currentPage),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _isDragging = true;
    _direction = _PageDirection.none;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    setState(() {
      _dragOffset += details.delta.dx;

      // 确定方向
      if (_direction == _PageDirection.none && _dragOffset.abs() > 10) {
        _direction =
            _dragOffset > 0 ? _PageDirection.prev : _PageDirection.next;
      }

      // 边界检查和阻尼
      if (_direction == _PageDirection.prev && !_hasPrev) {
        _dragOffset = _dragOffset.clamp(-double.infinity, 50);
        _dragOffset *= 0.3;
      }
      if (_direction == _PageDirection.next && !_hasNext) {
        _dragOffset = _dragOffset.clamp(-50, double.infinity);
        _dragOffset *= 0.3;
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || _isAnimating) return;
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;

    // 判断是否完成翻页
    final shouldTurn =
        _dragOffset.abs() > screenWidth * 0.25 || velocity.abs() > 800;

    if (shouldTurn) {
      if (_direction == _PageDirection.prev) {
        if (_currentPage > 0) {
          _animateToPage(_currentPage - 1);
        } else if (widget.hasPrevChapter) {
          // 跨章节：上一章最后一页
          widget.onPrevChapter?.call();
          _resetDrag();
        } else {
          _cancelDrag();
        }
      } else if (_direction == _PageDirection.next) {
        if (_currentPage < _maxPageIndex) {
          _animateToPage(_currentPage + 1);
        } else if (widget.hasNextChapter) {
          // 跨章节：下一章第一页
          widget.onNextChapter?.call();
          _resetDrag();
        } else {
          _cancelDrag();
        }
      } else {
        _cancelDrag();
      }
    } else {
      _cancelDrag();
    }
  }

  void _cancelDrag() {
    _isAnimating = true;
    final startOffset = _dragOffset;

    _animController.reset();
    _animController.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffset = startOffset *
              (1 - Curves.easeOut.transform(_animController.value));
        });
      }
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _resetDrag();
      }
    });

    _animController.forward();
  }

  void _resetDrag() {
    setState(() {
      _dragOffset = 0;
      _direction = _PageDirection.none;
      _isAnimating = false;
    });
  }

  Widget _buildPage(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return Container(color: widget.backgroundColor);
    }

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      margin: EdgeInsets.fromLTRB(
        widget.padding.left,
        topSafe + PagedReaderWidget.topOffset,
        widget.padding.right,
        bottomSafe + PagedReaderWidget.bottomOffset,
      ),
      child: Text.rich(
        TextSpan(text: widget.pages[index], style: widget.textStyle),
        textAlign: TextAlign.justify,
      ),
    );
  }
}

enum _PageDirection { none, prev, next }
