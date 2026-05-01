import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// 选文状态：记录选区的起止行和字符索引。
class PagedReaderTextSelection {
  final int startLineIndex;
  final int startCharIndex;
  final int endLineIndex;
  final int endCharIndex;
  final String selectedText;

  const PagedReaderTextSelection({
    required this.startLineIndex,
    required this.startCharIndex,
    required this.endLineIndex,
    required this.endCharIndex,
    required this.selectedText,
  });

  PagedReaderTextSelection copyWith({
    int? startLineIndex,
    int? startCharIndex,
    int? endLineIndex,
    int? endCharIndex,
    String? selectedText,
  }) {
    return PagedReaderTextSelection(
      startLineIndex: startLineIndex ?? this.startLineIndex,
      startCharIndex: startCharIndex ?? this.startCharIndex,
      endLineIndex: endLineIndex ?? this.endLineIndex,
      endCharIndex: endCharIndex ?? this.endCharIndex,
      selectedText: selectedText ?? this.selectedText,
    );
  }
}

class PagedRenderBlock {
  final String? text;
  final String? imageSrc;

  const PagedRenderBlock._({
    this.text,
    this.imageSrc,
  });

  const PagedRenderBlock.text(String value)
      : this._(
          text: value,
        );

  const PagedRenderBlock.image(String src)
      : this._(
          imageSrc: src,
        );

  bool get isImage => imageSrc != null;
}

class PagePicturePainter extends CustomPainter {
  final ui.Picture picture;

  const PagePicturePainter(this.picture);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant PagePicturePainter oldDelegate) {
    return oldDelegate.picture != picture;
  }
}

class CoverNextRevealClipper extends CustomClipper<Rect> {
  final double left;

  const CoverNextRevealClipper({required this.left});

  @override
  Rect getClip(Size size) {
    final safeLeft = left.clamp(0.0, size.width).toDouble();
    final width = (size.width - safeLeft).clamp(0.0, size.width).toDouble();
    return Rect.fromLTWH(safeLeft, 0, width, size.height);
  }

  @override
  bool shouldReclip(covariant CoverNextRevealClipper oldClipper) {
    return oldClipper.left != left;
  }
}

enum PagedReaderPageDirection { none, prev, next }
