/// TXT 段落归一化与“重新分段”逻辑（对标 legado `ContentHelp.reSegment`）。
///
/// 处理目标：
/// - 保留真正的段落分隔（空行）
/// - 对“硬换行”文本：合并连续非空行，避免每一行都被当成一个段落
///
/// 注意：启发式算法；如果文本本来就是诗歌/台词逐行排版，会尽量避免触发合并。
String normalizeTxtTypography(String content) {
  var text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.trim();
  if (text.isEmpty) return text;

  final lines = text.split('\n');
  final trimmedLines = _trimTrailingSpacesPerLine(lines);
  if (!_looksLikeHardWrappedText(trimmedLines)) {
    return trimmedLines.join('\n').trim();
  }

  return reSegmentLikeLegado(
    trimmedLines.join('\n'),
    chapterTitle: '',
  );
}

/// 对标 legado 的“重新分段”入口（简化版，可用于阅读器菜单）。
String reSegmentLikeLegado(
  String content, {
  required String chapterTitle,
}) {
  var text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty) return '';
  final lines = _trimTrailingSpacesPerLine(text.split('\n'));
  if (lines.isEmpty) return '';
  text = _reSegmentLikeLegado(lines).trim();

  final safeChapterTitle = chapterTitle.trim();
  if (safeChapterTitle.isEmpty) {
    return text;
  }
  final paragraphs = text.split('\n');
  if (paragraphs.isNotEmpty &&
      paragraphs.first.trim() == safeChapterTitle &&
      paragraphs.length > 1) {
    paragraphs.removeAt(0);
    return paragraphs.join('\n').trim();
  }
  return text;
}

List<String> _trimTrailingSpacesPerLine(List<String> lines) {
  return lines.map((l) => l.trimRight()).toList(growable: false);
}

bool _looksLikeHardWrappedText(List<String> lines) {
  int nonEmpty = 0;
  int blank = 0;
  int indentLike = 0;
  int lengthInRange = 0;
  int totalLen = 0;

  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty) {
      blank++;
      continue;
    }
    nonEmpty++;
    totalLen += t.length;

    if (line.startsWith('　　') ||
        line.startsWith('　') ||
        RegExp(r'^\s{2,}').hasMatch(line)) {
      indentLike++;
    }

    if (t.length >= 16 && t.length <= 120) {
      lengthInRange++;
    }
  }

  if (nonEmpty < 12) return false;

  final blankRatio = blank / (nonEmpty + blank);
  final indentRatio = indentLike / nonEmpty;
  final inRangeRatio = lengthInRange / nonEmpty;
  final avgLen = totalLen / nonEmpty;

  return totalLen >= 400 &&
      blankRatio <= 0.06 &&
      inRangeRatio >= 0.7 &&
      avgLen >= 18 &&
      indentRatio <= 0.25;
}

bool _isAsciiLetterOrDigit(int codeUnit) {
  return (codeUnit >= 48 && codeUnit <= 57) ||
      (codeUnit >= 65 && codeUnit <= 90) ||
      (codeUnit >= 97 && codeUnit <= 122);
}

bool _isSentenceEndChar(String ch) {
  return ch == '？' ||
      ch == '。' ||
      ch == '！' ||
      ch == '?' ||
      ch == '!' ||
      ch == '~';
}

bool _isRightQuote(String ch) => ch == '”' || ch == '"';

bool _isPredominantlyCjk(String text) {
  final maxScan = text.length.clamp(0, 2000);
  int cjk = 0;
  int asciiWord = 0;
  for (int i = 0; i < maxScan; i++) {
    final code = text.codeUnitAt(i);
    if ((code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF) ||
        (code >= 0xF900 && code <= 0xFAFF)) {
      cjk++;
    } else if (_isAsciiLetterOrDigit(code)) {
      asciiWord++;
    }
  }
  if (cjk < 50) return false;
  return cjk >= asciiWord * 2;
}

String _smartJoin(String left, String right) {
  final l = left.trimRight();
  final r = right.trimLeft();
  if (l.isEmpty) return r;
  if (r.isEmpty) return l;

  final last = l.codeUnitAt(l.length - 1);
  final first = r.codeUnitAt(0);
  if (_isAsciiLetterOrDigit(last) && _isAsciiLetterOrDigit(first)) {
    return '$l $r';
  }
  return '$l$r';
}

/// 对标 legado 的“重新分段”思路（简化版）。
///
/// legado 完整实现：`io.legado.app.help.book.ContentHelp.reSegment`
/// 这里保留最关键、最能解决 TXT 硬换行的部分：
/// - 合并错误的换行（硬换行）
/// - 保留真实空行作为段落分隔
/// - 在段落过长时，按句末标点插入换行，避免超长段落
String _reSegmentLikeLegado(List<String> lines) {
  final buffer = StringBuffer();
  var paragraph = '';

  final cjkPreferred = _isPredominantlyCjk(lines.take(80).join('\n'));
  final innerSpaceRegex = RegExp(r'[　\s]+', multiLine: true);

  void flushParagraph() {
    final p = paragraph.trim();
    if (p.isEmpty) {
      paragraph = '';
      return;
    }
    final segmented = _insertSoftNewlinesBySentenceEnd(p);
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(segmented);
    paragraph = '';
  }

  for (final raw in lines) {
    final trimmed = raw.trimRight();
    if (trimmed.trim().isEmpty) {
      flushParagraph();
      continue;
    }

    final line = cjkPreferred
        ? trimmed.replaceAll(innerSpaceRegex, '')
        : trimmed.trim();

    if (paragraph.isEmpty) {
      paragraph = line;
      continue;
    }

    final last = paragraph.substring(paragraph.length - 1);
    final prev = paragraph.length >= 2
        ? paragraph.substring(paragraph.length - 2, paragraph.length - 1)
        : '';
    final shouldNewParagraph = _isSentenceEndChar(last) ||
        (_isRightQuote(last) && _isSentenceEndChar(prev));
    if (shouldNewParagraph) {
      flushParagraph();
      paragraph = line;
      continue;
    }

    paragraph =
        cjkPreferred ? '$paragraph$line' : _smartJoin(paragraph, line);
  }

  flushParagraph();
  return buffer.toString();
}

/// 段落内部“软换行”：避免硬换行修复后出现一整段超长文本。
///
/// 规则（偏保守）：
/// - 段落较短则不处理
/// - 当距离上次换行超过一定阈值后，遇到句末标点才插入换行
String _insertSoftNewlinesBySentenceEnd(String paragraph) {
  if (paragraph.length <= 220) return paragraph;

  const minCharsBetweenBreaks = 60;
  final sb = StringBuffer();
  int sinceBreak = 0;
  for (int i = 0; i < paragraph.length; i++) {
    final ch = paragraph[i];
    sb.write(ch);
    sinceBreak++;

    if (sinceBreak < minCharsBetweenBreaks) continue;

    if (_isSentenceEndChar(ch)) {
      if (i + 1 < paragraph.length && paragraph[i + 1] != '\n') {
        sb.write('\n');
        sinceBreak = 0;
      }
      continue;
    }

    if (_isRightQuote(ch) && i >= 1 && _isSentenceEndChar(paragraph[i - 1])) {
      if (i + 1 < paragraph.length && paragraph[i + 1] != '\n') {
        sb.write('\n');
        sinceBreak = 0;
      }
    }
  }

  return sb.toString().replaceAll(RegExp(r'\n{2,}'), '\n').trim();
}
