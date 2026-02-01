import 'package:flutter/material.dart';
import '../models/reading_settings.dart';
import 'page_delegate/page_delegate.dart';
import 'page_delegate/cover_delegate.dart';
import 'page_delegate/slide_delegate.dart';
import 'page_delegate/no_anim_delegate.dart';

/// 翻页阅读器组件
/// 支持覆盖、滑动、无动画等翻页模式
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
  });

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentPage;
  PageDelegate? _pageDelegate;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
    _pageController = PageController(initialPage: _currentPage);
    _initPageDelegate();
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageTurnMode != widget.pageTurnMode) {
      _initPageDelegate();
    }
    if (oldWidget.pages != widget.pages) {
      _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
      _pageController.jumpToPage(_currentPage);
    }
  }

  void _initPageDelegate() {
    _pageDelegate?.dispose();

    switch (widget.pageTurnMode) {
      case PageTurnMode.cover:
        _pageDelegate = CoverPageDelegate();
        break;
      case PageTurnMode.slide:
        _pageDelegate = SlidePageDelegate();
        break;
      case PageTurnMode.none:
        _pageDelegate = NoAnimPageDelegate();
        break;
      case PageTurnMode.simulation:
        // 仿真翻页暂未实现，使用覆盖翻页
        _pageDelegate = CoverPageDelegate();
        break;
      case PageTurnMode.scroll:
        // 滚动模式不使用PageDelegate
        _pageDelegate = null;
        break;
    }

    if (_pageDelegate != null) {
      _pageDelegate!.init(this, () {
        if (mounted) setState(() {});
      });

      // 设置翻页回调
      if (_pageDelegate is CoverPageDelegate) {
        (_pageDelegate as CoverPageDelegate).onPageTurn = _handlePageTurn;
      } else if (_pageDelegate is SlidePageDelegate) {
        (_pageDelegate as SlidePageDelegate).onPageTurn = _handlePageTurn;
      } else if (_pageDelegate is NoAnimPageDelegate) {
        (_pageDelegate as NoAnimPageDelegate).onPageTurn = _handlePageTurn;
      }
    }
  }

  Future<bool> _handlePageTurn(PageDirection direction) async {
    if (direction == PageDirection.next) {
      return _goToNextPage();
    } else if (direction == PageDirection.prev) {
      return _goToPrevPage();
    }
    return false;
  }

  bool _goToNextPage() {
    if (_currentPage < widget.pages.length - 1) {
      setState(() {
        _currentPage++;
      });
      widget.onPageChanged?.call(_currentPage);
      return true;
    } else {
      // 触发下一章
      widget.onNextChapter?.call();
      return false;
    }
  }

  bool _goToPrevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      widget.onPageChanged?.call(_currentPage);
      return true;
    } else {
      // 触发上一章
      widget.onPrevChapter?.call();
      return false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageDelegate?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return Container(
        color: widget.backgroundColor,
        child: const Center(child: Text('暂无内容')),
      );
    }

    // 如果使用PageDelegate
    if (_pageDelegate != null) {
      return _buildDelegateBasedReader();
    }

    // 默认使用PageView（滚动模式应该由外层处理，这里作为后备）
    return _buildPageViewReader();
  }

  Widget _buildDelegateBasedReader() {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onHorizontalDragStart: _pageDelegate?.onDragStart,
      onHorizontalDragUpdate: _pageDelegate?.onDragUpdate,
      onHorizontalDragEnd: _pageDelegate?.onDragEnd,
      onTapUp: (details) {
        final screenWidth = size.width;
        final tapX = details.globalPosition.dx;

        if (tapX < screenWidth / 3) {
          // 左侧点击：上一页
          _pageDelegate?.prevPage();
        } else if (tapX > screenWidth * 2 / 3) {
          // 右侧点击：下一页
          _pageDelegate?.nextPage();
        } else {
          // 中间点击：显示菜单
          widget.onTap?.call();
        }
      },
      child: Container(
        color: widget.backgroundColor,
        child: _pageDelegate!.buildPageTransition(
          currentPage: _buildPage(_currentPage),
          prevPage: _currentPage > 0
              ? _buildPage(_currentPage - 1)
              : Container(color: widget.backgroundColor),
          nextPage: _currentPage < widget.pages.length - 1
              ? _buildPage(_currentPage + 1)
              : _buildEndOfChapterPage(),
          size: size,
        ),
      ),
    );
  }

  Widget _buildPageViewReader() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.pages.length,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
        widget.onPageChanged?.call(index);
      },
      itemBuilder: (context, index) {
        return GestureDetector(
          onTapUp: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final tapX = details.globalPosition.dx;

            if (tapX < screenWidth / 3) {
              if (_currentPage > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                widget.onPrevChapter?.call();
              }
            } else if (tapX > screenWidth * 2 / 3) {
              if (_currentPage < widget.pages.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                widget.onNextChapter?.call();
              }
            } else {
              widget.onTap?.call();
            }
          },
          child: _buildPage(index),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return Container(color: widget.backgroundColor);
    }

    return Container(
      color: widget.backgroundColor,
      padding: widget.padding,
      child: Text(
        widget.pages[index],
        style: widget.textStyle,
      ),
    );
  }

  Widget _buildEndOfChapterPage() {
    return Container(
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '本章结束',
              style: widget.textStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '点击右侧进入下一章',
              style: widget.textStyle.copyWith(
                fontSize: 14,
                color: widget.textStyle.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
