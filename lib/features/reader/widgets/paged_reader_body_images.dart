// ignore_for_file: invalid_use_of_protected_member

part of 'paged_reader_widget.dart';

extension _PagedReaderBodyImages on _PagedReaderWidgetState {
  Widget _buildPageWidget(
    PageData pageData, {
    required PageRenderSlot slot,
  }) {
    final content = pageData.text;
    if (content.isEmpty) {
      return Container(color: widget.backgroundColor);
    }

    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final bottomSafe = systemPadding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.padding.left,
                topSafe + _topOffset + widget.padding.top,
                widget.padding.right,
                bottomSafe + _bottomOffset + widget.padding.bottom,
              ),
              child: _buildPageBodyContent(pageData),
            ),
          ),
          if (_showAnyTipBar)
            _buildOverlay(
              topSafe,
              bottomSafe,
              slot: slot,
            ),
        ],
      ),
    );
  }

  Widget _buildPageBodyContent(PageData pageData) {
    final blocks = _parsePageRenderBlocks(pageData.text);
    if (!blocks.any((block) => block.isImage)) {
      return LegacyJustifiedTextBlock(
        content: pageData.text,
        style: widget.textStyle,
        titleStyle: _resolvedTitleStyle,
        justify: widget.settings.textFullJustify,
        bottomJustify: widget.settings.textBottomJustify,
        paragraphIndent: widget.settings.paragraphIndent,
        applyParagraphIndent: false,
        preserveEmptyLines: true,
        precomposedLines: pageData.precomposedLines,
        emptyLineHeight: widget.settings.paragraphSpacing > 0
            ? widget.settings.fontSize * widget.settings.paragraphSpacing / 10.0
            : null,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => _buildImageAwarePageBody(
        blocks: blocks,
        maxWidth: constraints.maxWidth,
        maxHeight: constraints.maxHeight,
      ),
    );
  }

  String _normalizeLegacyImageStyleValue(String style) {
    final normalized = style.trim().toUpperCase();
    if (normalized.isEmpty) {
      return _legacyImageStyleDefault;
    }
    return normalized;
  }

  List<_PagedRenderBlock> _parsePageRenderBlocks(String content) {
    if (!_contentHasImageMarker(content)) {
      return <_PagedRenderBlock>[_PagedRenderBlock.text(content)];
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_PagedRenderBlock>[];
    final textBuffer = StringBuffer();

    void flushText() {
      final value = textBuffer.toString();
      if (value.trim().isNotEmpty) {
        blocks.add(_PagedRenderBlock.text(value));
      }
      textBuffer.clear();
    }

    for (final line in lines) {
      final src = ReaderImageMarkerCodec.decodeLine(line);
      if (src != null) {
        flushText();
        blocks.add(_PagedRenderBlock.image(src));
      } else {
        textBuffer.writeln(line);
      }
    }
    flushText();

    if (blocks.isEmpty) {
      return <_PagedRenderBlock>[_PagedRenderBlock.text(content)];
    }
    return blocks;
  }

  Widget _buildImageAwarePageBody({
    required List<_PagedRenderBlock> blocks,
    required double maxWidth,
    required double maxHeight,
  }) {
    final style = _normalizeLegacyImageStyleValue(widget.legacyImageStyle);
    final spacing =
        widget.settings.paragraphSpacing.clamp(4.0, 24.0).toDouble();
    final children = <Widget>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.isImage) {
        children.add(
          _buildPagedImageBlock(
            src: block.imageSrc ?? '',
            imageStyle: style,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
        );
      } else if ((block.text ?? '').trim().isNotEmpty) {
        children.add(
          LegacyJustifiedTextBlock(
            content: block.text ?? '',
            style: widget.textStyle,
            justify: widget.settings.textFullJustify,
            bottomJustify: widget.settings.textBottomJustify,
            paragraphIndent: widget.settings.paragraphIndent,
            applyParagraphIndent: false,
            preserveEmptyLines: true,
          ),
        );
      }
      if (i != blocks.length - 1) {
        children.add(SizedBox(height: spacing));
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 标题行渲染样式（titleMode==2 时返回 null 表示不显示标题）。
  TextStyle? get _resolvedTitleStyle => widget.settings.titleMode == 2
      ? null
      : widget.textStyle.copyWith(
          fontSize:
              ((widget.textStyle.fontSize ?? 16.0) + widget.settings.titleSize)
                  .clamp(10.0, 72.0),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        );

  double _estimatePagedImageHeight({
    required String imageStyle,
    required double maxWidth,
    required double maxHeight,
  }) {
    final width = maxWidth <= 0 ? 320.0 : maxWidth;
    final base = (widget.textStyle.fontSize ?? 16) *
        ((widget.textStyle.height ?? 1.5).clamp(1.0, 2.8));
    final minHeight = base.clamp(14.0, maxHeight);
    switch (imageStyle) {
      case _legacyImageStyleSingle:
        return maxHeight.clamp(minHeight, maxHeight).toDouble();
      case _legacyImageStyleFull:
        final candidate = width * 0.75;
        return candidate.clamp(minHeight * 3, maxHeight).toDouble();
      default:
        final candidate = width * 0.62;
        return candidate.clamp(minHeight * 2, maxHeight * 0.72).toDouble();
    }
  }

  Widget _buildPagedImageBlock({
    required String src,
    required String imageStyle,
    required double maxWidth,
    required double maxHeight,
  }) {
    final request = ReaderImageRequestParser.parse(src);
    final displaySrc = request.url.trim().isEmpty ? src.trim() : request.url;
    final imageProvider = const ReaderImageResolver(isWeb: kIsWeb)
        .resolveProvider(request, headers: request.headers);
    if (imageProvider == null) {
      return _buildPagedImageFallback(displaySrc);
    }
    _trackPagedImageIntrinsicSize(
      src: src,
      imageProvider: imageProvider,
    );

    final constrainedHeight = _estimatePagedImageHeight(
      imageStyle: imageStyle,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final forceFullWidth = imageStyle == _legacyImageStyleFull ||
        imageStyle == _legacyImageStyleSingle;
    final image = Image(
      image: imageProvider,
      width: forceFullWidth ? maxWidth : null,
      fit: forceFullWidth ? BoxFit.fitWidth : BoxFit.contain,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildPagedImageFallback(displaySrc),
    );
    final imageBox = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: constrainedHeight,
      ),
      child: image,
    );
    final onImageTap = widget.onImageTap;
    Widget tappable(Widget child) {
      if (onImageTap == null) return child;
      return GestureDetector(
        onTap: () => onImageTap(src),
        child: child,
      );
    }

    if (imageStyle == _legacyImageStyleSingle) {
      return tappable(SizedBox(
        height: constrainedHeight,
        child: Center(child: imageBox),
      ));
    }
    return tappable(Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _spacingForImage(imageStyle)),
        child: imageBox,
      ),
    ));
  }

  double _spacingForImage(String imageStyle) {
    if (imageStyle == _legacyImageStyleSingle) {
      return 0;
    }
    return (widget.settings.paragraphSpacing / 2).clamp(6.0, 20.0).toDouble();
  }

  Widget _buildPagedImageFallback(String src) {
    final message = src.isEmpty ? '图片加载失败' : '图片加载失败：$src';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: widget.textStyle.copyWith(
          fontSize: ((widget.textStyle.fontSize ?? 16) - 2)
              .clamp(10.0, 22.0)
              .toDouble(),
          color: (widget.textStyle.color ?? const Color(0xFF8B7961))
              .withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
