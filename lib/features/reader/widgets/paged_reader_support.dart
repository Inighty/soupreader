part of 'paged_reader_widget.dart';

ui.FragmentProgram? _pageCurlProgram;

const double _doublePageGutter = 16.0;
const String _legacyImageStyleDefault = 'DEFAULT';
const String _legacyImageStyleFull = 'FULL';
const String _legacyImageStyleSingle = 'SINGLE';

/// 选文状态：记录选区的起止行和字符索引。
class _TextSelection {
  final int startLineIndex;
  final int startCharIndex;
  final int endLineIndex;
  final int endCharIndex;
  final String selectedText;

  const _TextSelection({
    required this.startLineIndex,
    required this.startCharIndex,
    required this.endLineIndex,
    required this.endCharIndex,
    required this.selectedText,
  });

  _TextSelection copyWith({
    int? startLineIndex,
    int? startCharIndex,
    int? endLineIndex,
    int? endCharIndex,
    String? selectedText,
  }) {
    return _TextSelection(
      startLineIndex: startLineIndex ?? this.startLineIndex,
      startCharIndex: startCharIndex ?? this.startCharIndex,
      endLineIndex: endLineIndex ?? this.endLineIndex,
      endCharIndex: endCharIndex ?? this.endCharIndex,
      selectedText: selectedText ?? this.selectedText,
    );
  }
}

class _PagedRenderBlock {
  final String? text;
  final String? imageSrc;

  const _PagedRenderBlock._({
    this.text,
    this.imageSrc,
  });

  const _PagedRenderBlock.text(String value)
      : this._(
          text: value,
        );

  const _PagedRenderBlock.image(String src)
      : this._(
          imageSrc: src,
        );

  bool get isImage => imageSrc != null;
}

class _PagePicturePainter extends CustomPainter {
  final ui.Picture picture;

  const _PagePicturePainter(this.picture);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant _PagePicturePainter oldDelegate) {
    return oldDelegate.picture != picture;
  }
}

class _CoverNextRevealClipper extends CustomClipper<Rect> {
  final double left;

  const _CoverNextRevealClipper({required this.left});

  @override
  Rect getClip(Size size) {
    final safeLeft = left.clamp(0.0, size.width).toDouble();
    final width = (size.width - safeLeft).clamp(0.0, size.width).toDouble();
    return Rect.fromLTWH(safeLeft, 0, width, size.height);
  }

  @override
  bool shouldReclip(covariant _CoverNextRevealClipper oldClipper) {
    return oldClipper.left != left;
  }
}

enum _PageDirection { none, prev, next }
