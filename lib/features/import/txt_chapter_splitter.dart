/// TXT 章节分割逻辑（按目录规则正则匹配，或回退到固定字数分章）。
library;

/// 章节信息（导入流水线内部结构）。
class TxtChapterInfo {
  final String title;
  final String content;

  const TxtChapterInfo({required this.title, required this.content});
}

/// 内置目录规则编译后的正则集合，按内置规则顺序排列。
///
/// 由 `txt_parser.dart` 通过编译 `defaultTocRuleOptions` 后传入，
/// 避免循环依赖。
typedef TxtTocPatternProvider = List<RegExp> Function();

/// 分割章节。
///
/// 优先级：
/// 1. 强制 [tocRuleRegex]：仅按该规则切分，无匹配则返回空。
/// 2. 候选规则集 [tocRuleRegexCandidates]：在集合内自动选优；无匹配则按
///    [splitLongChapter] 决定是否回退到固定字数分章。
/// 3. 内置默认规则：自动选优；不足 2 章时回退。
List<TxtChapterInfo> splitTxtChapters(
  String content, {
  required List<RegExp> defaultPatterns,
  bool splitLongChapter = true,
  String? tocRuleRegex,
  List<String>? tocRuleRegexCandidates,
}) {
  final normalizedRule = (tocRuleRegex ?? '').trim();
  if (normalizedRule.isNotEmpty) {
    final forcedPattern = _compileTocPattern(normalizedRule);
    if (forcedPattern == null) {
      return <TxtChapterInfo>[];
    }
    return _splitByMatches(
      content,
      _filterValidMatches(forcedPattern.allMatches(content)),
      splitLongChapter: splitLongChapter,
      allowFallback: false,
    );
  }

  if (tocRuleRegexCandidates != null) {
    final bestMatches = _selectBestMatchesByRuleCandidates(
      content,
      tocRuleRegexCandidates,
    );
    if (bestMatches.isNotEmpty) {
      return _splitByMatches(
        content,
        bestMatches,
        splitLongChapter: splitLongChapter,
        allowFallback: true,
      );
    }
    if (!splitLongChapter) {
      return _singleChapterFallback(content);
    }
    return _splitByLength(content);
  }

  var maxMatches = 0;
  List<RegExpMatch> bestMatches = <RegExpMatch>[];
  for (final pattern in defaultPatterns) {
    final validMatches = _filterValidMatches(pattern.allMatches(content));
    if (validMatches.length <= maxMatches) continue;
    maxMatches = validMatches.length;
    bestMatches = validMatches;
  }

  if (maxMatches < 2) {
    if (!splitLongChapter) {
      return _singleChapterFallback(content);
    }
    return _splitByLength(content);
  }

  return _splitByMatches(
    content,
    bestMatches,
    splitLongChapter: splitLongChapter,
    allowFallback: true,
  );
}

/// 从候选目录规则里选择“最佳匹配”。
///
/// 评分逻辑对齐 legado `TextFile.getTocRule`：
/// - 只统计彼此间隔较大的命中（>1000 字符）；
/// - 使用 `>=` 处理并列分值（配合 reversed 顺序，保证前置规则优先级更高）。
List<RegExpMatch> _selectBestMatchesByRuleCandidates(
  String content,
  List<String> tocRuleRegexCandidates,
) {
  var bestScore = 1;
  List<RegExpMatch> bestMatches = const <RegExpMatch>[];
  for (final rawRule in tocRuleRegexCandidates.reversed) {
    final normalized = rawRule.trim();
    if (normalized.isEmpty) continue;
    final pattern = _compileTocPattern(normalized);
    if (pattern == null) continue;
    final matches = _filterValidMatches(pattern.allMatches(content));
    final score = _countSpacedMatchesLikeLegado(matches);
    if (score >= bestScore) {
      bestScore = score;
      bestMatches = matches;
    }
  }
  return bestMatches;
}

int _countSpacedMatchesLikeLegado(List<RegExpMatch> matches) {
  var count = 0;
  var lastEnd = 0;
  var hasStart = false;
  for (final match in matches) {
    if (!hasStart || match.start - lastEnd > 1000) {
      count++;
      lastEnd = match.end;
      hasStart = true;
    }
  }
  return count;
}

RegExp? _compileTocPattern(String rawPattern) {
  try {
    return RegExp(rawPattern, multiLine: true);
  } catch (_) {
    return null;
  }
}

List<RegExpMatch> _filterValidMatches(Iterable<RegExpMatch> matches) {
  return matches.where((match) {
    final text = (match.group(0) ?? '').trim();
    return text.length >= 2 && text.length <= 120;
  }).toList(growable: false);
}

List<TxtChapterInfo> _splitByMatches(
  String content,
  List<RegExpMatch> matches, {
  required bool splitLongChapter,
  required bool allowFallback,
}) {
  if (matches.isEmpty) {
    if (!allowFallback) return <TxtChapterInfo>[];
    if (!splitLongChapter) {
      return _singleChapterFallback(content);
    }
    return _splitByLength(content);
  }

  final chapters = <TxtChapterInfo>[];

  if (matches.first.start > 200) {
    final preface = content.substring(0, matches.first.start).trim();
    if (preface.isNotEmpty && preface.length > 50) {
      chapters.add(TxtChapterInfo(title: '序言', content: preface));
    }
  }

  for (int i = 0; i < matches.length; i++) {
    final match = matches[i];
    final title = match.group(0)?.trim() ?? '第${i + 1}章';

    final startIndex = match.end;
    final endIndex =
        (i + 1 < matches.length) ? matches[i + 1].start : content.length;

    final chapterContent = content.substring(startIndex, endIndex).trim();

    if (chapterContent.isNotEmpty && chapterContent.length > 10) {
      chapters.add(TxtChapterInfo(title: title, content: chapterContent));
    }
  }

  if (chapters.isEmpty) {
    if (!allowFallback) return <TxtChapterInfo>[];
    if (!splitLongChapter) {
      return _singleChapterFallback(content);
    }
    return _splitByLength(content);
  }
  return chapters;
}

List<TxtChapterInfo> _singleChapterFallback(String content) {
  return [TxtChapterInfo(title: '正文', content: content.trim())];
}

/// 按固定长度分章（备选方案）
List<TxtChapterInfo> _splitByLength(String content) {
  const charsPerChapter = 5000;
  final chapters = <TxtChapterInfo>[];

  content = content.trim();
  if (content.isEmpty) {
    return [const TxtChapterInfo(title: '正文', content: '')];
  }

  if (content.length <= charsPerChapter) {
    return [TxtChapterInfo(title: '正文', content: content)];
  }

  int chapterIndex = 1;
  int start = 0;

  while (start < content.length) {
    int end = start + charsPerChapter;
    if (end >= content.length) {
      end = content.length;
    } else {
      final searchEnd = (end + 500).clamp(0, content.length);
      final newlinePos = content.indexOf('\n\n', end);
      if (newlinePos > 0 && newlinePos < searchEnd) {
        end = newlinePos;
      } else {
        final singleNewline = content.indexOf('\n', end);
        if (singleNewline > 0 && singleNewline < searchEnd) {
          end = singleNewline;
        }
      }
    }

    final chapterContent = content.substring(start, end).trim();
    if (chapterContent.isNotEmpty) {
      chapters.add(TxtChapterInfo(
        title: '第$chapterIndex章',
        content: chapterContent,
      ));
      chapterIndex++;
    }
    start = end;
  }

  return chapters.isEmpty
      ? [TxtChapterInfo(title: '正文', content: content)]
      : chapters;
}
