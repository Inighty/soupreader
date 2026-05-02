import 'package:flutter/widgets.dart';

import 'legacy_justify_composer.dart';

export 'legacy_justify_composer.dart';
export 'legacy_justify_painter.dart';


class LegacyJustifiedTextBlock extends StatelessWidget {
  final String content;
  final TextStyle style;
  /// 标题行样式（由分页器标记的 isTitle=true 行使用此样式渲染）。
  final TextStyle? titleStyle;
  final bool justify;
  final bool bottomJustify;
  final String paragraphIndent;
  final bool applyParagraphIndent;
  final bool preserveEmptyLines;
  /// 预排版行缓存（由分页器提供）。不为 null 时跳过重新排版，直接复用。
  final List<LegacyComposedLine>? precomposedLines;
  /// 空段落（段落间距占位行）的高度。为 null 时使用默认行高。
  final double? emptyLineHeight;

  const LegacyJustifiedTextBlock({
    super.key,
    required this.content,
    required this.style,
    this.titleStyle,
    required this.justify,
    this.bottomJustify = false,
    this.paragraphIndent = '　　',
    this.applyParagraphIndent = true,
    this.preserveEmptyLines = true,
    this.precomposedLines,
    this.emptyLineHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        final maxWidth = constraints.maxWidth;
        final lines = precomposedLines ??
            LegacyJustifyComposer.composeContentLines(
              content: content,
              style: style,
              maxWidth: maxWidth,
              justify: justify,
              paragraphIndent: paragraphIndent,
              applyParagraphIndent: applyParagraphIndent,
              preserveEmptyLines: preserveEmptyLines,
              emptyLineHeight: emptyLineHeight,
            );
        if (lines.isEmpty) {
          return const SizedBox.shrink();
        }
        final maxHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : null;
        final extraGap = LegacyJustifyComposer.computeBottomJustifyGap(
          bottomJustify: bottomJustify,
          lines: lines,
          maxHeight: maxHeight,
        );
        final children = <Widget>[];
        var usedHeight = 0.0;
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final lineExtraGap = (i > 0 && extraGap > 0.01) ? extraGap : 0.0;
          if (maxHeight != null &&
              usedHeight + lineExtraGap + line.renderHeight > maxHeight) break;
          if (lineExtraGap > 0.01) {
            children.add(SizedBox(height: lineExtraGap));
            usedHeight += lineExtraGap;
          }
          children.add(line.toWidget(
            style: style,
            titleStyle: titleStyle,
            maxWidth: maxWidth,
          ));
          usedHeight += line.height;
        }

        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }
}

class LegacyComposedParagraph {
  final List<LegacyComposedLine> lines;

  const LegacyComposedParagraph(this.lines);

  List<Widget> toWidgets({
    required TextStyle style,
    required double maxWidth,
  }) {
    return lines
        .map((line) => line.toWidget(style: style, maxWidth: maxWidth))
        .toList();
  }
}

class LegacyComposedLine {
  final String plainText;
  final List<LegacyComposedSegment> segments;
  final bool justified;
  /// 步进高度（含行距间隙），用于累加 currentY
  final double height;
  /// 渲染高度（字体基准高度，不含行距间隙），用于截断判断。
  /// 对标 legado: lineBottom - lineTop = textHeight（不含行距）
  final double renderHeight;
  /// 行在页面内容区的起始 y 坐标（相对于 bodyOriginY），由 composeContentLines 填入
  final double lineStartY;
  /// 是否为标题行（渲染时使用 titleStyle）
  final bool isTitle;
  /// 是否为标题间距占位行（topSpacing/bottomSpacing/paragraphSpacing）
  final bool isTitleSpacing;

  const LegacyComposedLine({
    required this.plainText,
    required this.segments,
    required this.justified,
    required this.height,
    double? renderHeight,
    this.lineStartY = 0.0,
    this.isTitle = false,
    this.isTitleSpacing = false,
  }) : renderHeight = renderHeight ?? height;

  factory LegacyComposedLine.empty({
    required double height,
    double? renderHeight,
    double lineStartY = 0.0,
    bool isTitleSpacing = false,
  }) {
    return LegacyComposedLine(
      plainText: '',
      segments: const <LegacyComposedSegment>[],
      justified: false,
      height: height,
      renderHeight: renderHeight ?? height,
      lineStartY: lineStartY,
      isTitleSpacing: isTitleSpacing,
    );
  }

  bool get isVisualEmpty {
    if (plainText.trim().isNotEmpty) return false;
    return segments.every((segment) => segment.text.trim().isEmpty);
  }

  Widget toWidget({
    required TextStyle style,
    TextStyle? titleStyle,
    required double maxWidth,
  }) {
    if (isVisualEmpty) {
      return SizedBox(
        width: maxWidth,
        height: height,
      );
    }
    final effectiveStyle = (isTitle && titleStyle != null) ? titleStyle : style;
    if (!justified || segments.length <= 1) {
      return SizedBox(
        width: maxWidth,
        child: Text(
          plainText,
          style: effectiveStyle,
          textAlign: TextAlign.left,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      );
    }

    final spans = <InlineSpan>[];
    for (final segment in segments) {
      if (segment.text.isNotEmpty) {
        spans.add(TextSpan(text: segment.text));
      }
      if (segment.extraAfter > 0.01) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SizedBox(width: segment.extraAfter),
          ),
        );
      }
    }

    return SizedBox(
      width: maxWidth,
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        text: TextSpan(style: effectiveStyle, children: spans),
      ),
    );
  }
}

class LegacyComposedSegment {
  final String text;
  final double extraAfter;

  const LegacyComposedSegment({
    required this.text,
    required this.extraAfter,
  });
}

