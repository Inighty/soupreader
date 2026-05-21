// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderOverlay on _PagedReaderWidgetState {
  EdgeInsets _resolveTipHorizontalInsets(
    double maxWidth, {
    required double left,
    required double right,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return EdgeInsets.zero;
    }
    var safeLeft = left.isFinite ? left.clamp(0.0, maxWidth).toDouble() : 0.0;
    var safeRight =
        right.isFinite ? right.clamp(0.0, maxWidth).toDouble() : 0.0;
    final overflow = safeLeft + safeRight - maxWidth;
    if (overflow > 0) {
      final shrink = overflow / 2;
      safeLeft = (safeLeft - shrink).clamp(0.0, maxWidth).toDouble();
      safeRight = (safeRight - shrink).clamp(0.0, maxWidth).toDouble();
    }
    return EdgeInsets.only(left: safeLeft, right: safeRight);
  }

  Widget _buildOverlay(
    double topSafe,
    double bottomSafe, {
    required PageRenderSlot slot,
  }) {
    if (!_showAnyTipBar) {
      return const SizedBox.shrink();
    }
    final statusColor = _tipTextColor;
    final dividerColor = _tipDividerColor;
    final renderPosition = _factory.resolveRenderPosition(slot);
    final headerStyle = widget.textStyle.copyWith(
      fontSize: PagedReaderWidget._tipHeaderFontSize,
      height: 1.0,
      color: statusColor,
    );
    final footerStyle = widget.textStyle.copyWith(
      fontSize: PagedReaderWidget._tipFooterFontSize,
      height: 1.0,
      color: statusColor,
    );

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final headerInsets = _resolveTipHorizontalInsets(
            maxWidth,
            left: widget.settings.headerPaddingLeft,
            right: widget.settings.headerPaddingRight,
          );
          final footerInsets = _resolveTipHorizontalInsets(
            maxWidth,
            left: widget.settings.footerPaddingLeft,
            right: widget.settings.footerPaddingRight,
          );
          return Stack(
            children: [
              if (_showHeader)
                Positioned(
                  top: topSafe +
                      PagedReaderWidget._tipHeaderEdgeInset +
                      widget.settings.headerPaddingTop,
                  left: headerInsets.left,
                  right: headerInsets.right,
                  child: _buildTipRowWidget(
                    _tipTextForHeader(
                      widget.settings.headerLeftContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForHeader(
                      widget.settings.headerCenterContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForHeader(
                      widget.settings.headerRightContent,
                      renderPosition: renderPosition,
                    ),
                    headerStyle,
                  ),
                ),
              if (_showHeader && widget.settings.showHeaderLine)
                Positioned(
                  top: topSafe +
                      _headerSlotHeight -
                      PagedReaderWidget._tipDividerThickness,
                  left: headerInsets.left,
                  right: headerInsets.right,
                  child: Container(
                    height: PagedReaderWidget._tipDividerThickness,
                    color: dividerColor,
                  ),
                ),
              if (_showFooter && widget.settings.showFooterLine)
                Positioned(
                  bottom: bottomSafe +
                      _footerSlotHeight -
                      PagedReaderWidget._tipDividerThickness,
                  left: footerInsets.left,
                  right: footerInsets.right,
                  child: Container(
                    height: PagedReaderWidget._tipDividerThickness,
                    color: dividerColor,
                  ),
                ),
              if (_showFooter)
                Positioned(
                  bottom: bottomSafe +
                      PagedReaderWidget._tipFooterEdgeInset +
                      widget.settings.footerPaddingBottom,
                  left: footerInsets.left,
                  right: footerInsets.right,
                  child: _buildTipRowWidget(
                    _tipTextForFooter(
                      widget.settings.footerLeftContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForFooter(
                      widget.settings.footerCenterContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForFooter(
                      widget.settings.footerRightContent,
                      renderPosition: renderPosition,
                    ),
                    footerStyle,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTipRowWidget(
    String? left,
    String? center,
    String? right,
    TextStyle style,
  ) {
    return Row(
      children: [
        _tipTextWidget(left, style),
        const Expanded(child: SizedBox.shrink()),
        if (center != null && center.isNotEmpty)
          Expanded(
            flex: 2,
            child: Text(
              center,
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const Expanded(flex: 2, child: SizedBox.shrink()),
        const Expanded(child: SizedBox.shrink()),
        _tipTextWidget(right, style),
      ],
    );
  }

  Widget _tipTextWidget(String? text, TextStyle style) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: style);
  }
}
