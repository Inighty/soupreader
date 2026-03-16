/// Pure-function utilities for post-processing chapter content.
///
/// These transformations were previously private methods inside
/// `_SimpleReaderViewState`. Extracting them enables unit testing and
/// makes the processing pipeline explicit.
class ReaderContentProcessor {
  ReaderContentProcessor._();

  // ── Paragraph formatting (Legado-compatible) ──

  /// Normalizes chapter content into clean paragraphs.
  ///
  /// - Replaces HTML whitespace entities (`&nbsp;`, `&emsp;`, etc.).
  /// - Collapses multiple newlines into single paragraph breaks.
  /// - Trims each paragraph using [trimParagraph].
  static String formatContentLikeLegado(String content) {
    var text = content;

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ensp;', ' ')
        .replaceAll('&emsp;', ' ')
        .replaceAll('&thinsp;', '')
        .replaceAll('&zwnj;', '')
        .replaceAll('&zwj;', '')
        .replaceAll('\u2009', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '');

    text = text.replaceAll('\r\n', '\n');

    final rawParagraphs = text.split(RegExp(r'\s*\n+\s*'));
    final paragraphs = rawParagraphs
        .map(trimParagraph)
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    if (paragraphs.isEmpty) return '';
    return paragraphs.join('\n');
  }

  /// Trims leading/trailing ASCII control chars, spaces, and full-width
  /// spaces (U+3000) from a single paragraph.
  static String trimParagraph(String input) {
    if (input.isEmpty) return '';
    var start = 0;
    var end = input.length;
    while (start < end) {
      final code = input.codeUnitAt(start);
      if (code <= 0x20 || input[start] == '　') {
        start++;
      } else {
        break;
      }
    }
    while (end > start) {
      final code = input.codeUnitAt(end - 1);
      if (code <= 0x20 || input[end - 1] == '　') {
        end--;
      } else {
        break;
      }
    }
    return input.substring(start, end);
  }

  // ── Duplicate title removal ──

  /// Removes the chapter title from the first non-empty line of content
  /// if it matches or contains [title].
  static DuplicateTitleRemovalResult removeDuplicateTitle(
    String content,
    String title,
  ) {
    if (content.isEmpty) {
      return DuplicateTitleRemovalResult(content: content, removed: false);
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final trimmedTitle = title.trim();
    final index = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (index != -1) {
      final firstLine = lines[index].trim();
      if (firstLine == trimmedTitle || firstLine.contains(trimmedTitle)) {
        lines.removeAt(index);
        return DuplicateTitleRemovalResult(
          content: lines.join('\n'),
          removed: true,
        );
      }
    }
    return DuplicateTitleRemovalResult(
      content: lines.join('\n'),
      removed: false,
    );
  }

  // ── EPUB tag cleanup ──

  /// Removes `<rt>` and `<rp>` ruby pronunciation tags from EPUB content.
  static String removeRubyTags(String content) {
    return content
        .replaceAll(
          RegExp(r'<rt\b[^>]*>.*?</rt>', caseSensitive: false, dotAll: true),
          '',
        )
        .replaceAll(
          RegExp(r'<rp\b[^>]*>.*?</rp>', caseSensitive: false, dotAll: true),
          '',
        );
  }

  /// Removes `<h1>`–`<h6>` header tags from EPUB content.
  static String removeHtmlHeaderTags(String content) {
    final withoutBlocks = content.replaceAll(
      RegExp(
        r'<h[1-6]\b[^>]*>.*?</h[1-6]\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    return withoutBlocks.replaceAll(
      RegExp(r'<h[1-6]\b[^>]*/>', caseSensitive: false),
      '',
    );
  }

  // ── Content reversal ──

  /// Reverses the characters in content (used for RTL text handling).
  static String reverseContent(String content) {
    return String.fromCharCodes(content.runes.toList().reversed);
  }
}

/// Result of [ReaderContentProcessor.removeDuplicateTitle].
class DuplicateTitleRemovalResult {
  final String content;
  final bool removed;

  const DuplicateTitleRemovalResult({
    required this.content,
    required this.removed,
  });
}
