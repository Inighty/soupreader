import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/models/book.dart';
import 'txt_chapter_splitter.dart';
import 'txt_charset_decoder.dart';
import 'txt_paragraph_normalizer.dart';

/// TXT 目录规则（对齐 legado `TxtTocRule.rule` 语义）。
class TxtTocRuleOption {
  final String name;
  final String rule;
  final String example;

  const TxtTocRuleOption({
    required this.name,
    required this.rule,
    required this.example,
  });
}

/// TXT 文件解析器。
class TxtParser {
  static const _uuid = Uuid();

  /// 内置目录规则（顺序影响默认自动识别优先级）。
  static const List<TxtTocRuleOption> defaultTocRuleOptions =
      <TxtTocRuleOption>[
    TxtTocRuleOption(
      name: '第N章（数字）',
      rule: r'^\s*第\d+章\S.*$',
      example: '第1章 开始',
    ),
    TxtTocRuleOption(
      name: '第N章/节/回/卷',
      rule: r'^\s*第[零一二三四五六七八九十百千万\d]+[章节回卷].*$',
      example: '第十二章 夜雨',
    ),
    TxtTocRuleOption(
      name: '【第N章】',
      rule: r'^\s*【第[零一二三四五六七八九十百千万\d]+[章节回卷]】.*$',
      example: '【第3章】再会',
    ),
    TxtTocRuleOption(
      name: '第 N 章（带空格）',
      rule: r'^\s*第\s*\d+\s*章.*$',
      example: '第 10 章 转折',
    ),
    TxtTocRuleOption(
      name: 'Chapter N',
      rule: r'^\s*[Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+.*$',
      example: 'Chapter 8',
    ),
    TxtTocRuleOption(
      name: '卷N/第N章',
      rule: r'^\s*[卷第]\s*[零一二三四五六七八九十百千万\d]+\s*[章节卷].*$',
      example: '卷一 第三章',
    ),
    TxtTocRuleOption(
      name: '数字开头',
      rule: r'^\s*\d{1,4}[\.\、\s].*$',
      example: '001 初见',
    ),
    TxtTocRuleOption(
      name: '正文 第N章',
      rule: r'^\s*正文\s+第[零一二三四五六七八九十百千万\d]+[章节回卷].*$',
      example: '正文 第5章',
    ),
    TxtTocRuleOption(
      name: '序章/终章',
      rule: r'^\s*[序终]章.*$',
      example: '序章',
    ),
    TxtTocRuleOption(
      name: '楔子/引子',
      rule: r'^\s*[楔引]子.*$',
      example: '楔子',
    ),
    TxtTocRuleOption(
      name: '番外',
      rule: r'^\s*番外.*$',
      example: '番外·后日谈',
    ),
  ];

  static final List<RegExp> _chapterPatterns = defaultTocRuleOptions
      .map((option) => RegExp(option.rule, multiLine: true))
      .toList(growable: false);

  /// 从文件路径导入 TXT。
  static Future<TxtImportResult> importFromFile(
    String filePath, {
    String? forcedCharset,
    String? tocRuleRegex,
    List<String>? tocRuleRegexCandidates,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final bytes = await file.readAsBytes();
    final decoded = decodeTxtContent(bytes, forcedCharset: forcedCharset);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final bookName =
        fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');

    return _parseContent(
      decoded.content,
      bookName,
      filePath,
      charset: decoded.charset,
      tocRuleRegex: tocRuleRegex,
      tocRuleRegexCandidates: tocRuleRegexCandidates,
    );
  }

  /// 从字节数据导入（iOS 使用）。
  static TxtImportResult importFromBytes(
    Uint8List bytes,
    String fileName, {
    String? forcedCharset,
    String? tocRuleRegex,
    List<String>? tocRuleRegexCandidates,
  }) {
    final decoded = decodeTxtContent(bytes, forcedCharset: forcedCharset);
    final bookName =
        fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    return _parseContent(
      decoded.content,
      bookName,
      null,
      charset: decoded.charset,
      tocRuleRegex: tocRuleRegex,
      tocRuleRegexCandidates: tocRuleRegexCandidates,
    );
  }

  /// 以既有书籍 ID 重解析 TXT（用于阅读器设置编码后的重载）。
  static Future<TxtImportResult> reparseFromFile({
    required String filePath,
    required String bookId,
    required String bookName,
    String? forcedCharset,
    bool splitLongChapter = true,
    String? tocRuleRegex,
    List<String>? tocRuleRegexCandidates,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }
    final bytes = await file.readAsBytes();
    final decoded = decodeTxtContent(bytes, forcedCharset: forcedCharset);
    return _parseContent(
      decoded.content,
      bookName,
      filePath,
      charset: decoded.charset,
      forcedBookId: bookId,
      splitLongChapter: splitLongChapter,
      tocRuleRegex: tocRuleRegex,
      tocRuleRegexCandidates: tocRuleRegexCandidates,
    );
  }

  static TxtImportResult _parseContent(
    String content,
    String bookName,
    String? filePath, {
    required String charset,
    String? forcedBookId,
    bool splitLongChapter = true,
    String? tocRuleRegex,
    List<String>? tocRuleRegexCandidates,
  }) {
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final chapters = splitTxtChapters(
      content,
      defaultPatterns: _chapterPatterns,
      splitLongChapter: splitLongChapter,
      tocRuleRegex: tocRuleRegex,
      tocRuleRegexCandidates: tocRuleRegexCandidates,
    );

    final bookId = forcedBookId ?? _uuid.v4();
    final book = Book(
      id: bookId,
      title: bookName,
      author: '未知作者',
      totalChapters: chapters.length,
      isLocal: true,
      localPath: filePath,
      addedTime: DateTime.now(),
    );

    final chapterList = chapters.asMap().entries.map((entry) {
      return Chapter(
        id: '${bookId}_${entry.key}',
        bookId: bookId,
        title: entry.value.title,
        index: entry.key,
        isDownloaded: true,
        // TXT 的排版问题主要来自“硬换行”：每行固定宽度换行但段落不空行。
        // 阅读器把 `\n` 当成段落分隔，这里先做一次段落归一化。
        content: normalizeTxtTypography(entry.value.content),
      );
    }).toList();

    return TxtImportResult(
      book: book,
      chapters: chapterList,
      charset: charset,
    );
  }
}

/// TXT 导入结果。
class TxtImportResult {
  final Book book;
  final List<Chapter> chapters;
  final String charset;

  TxtImportResult({
    required this.book,
    required this.chapters,
    required this.charset,
  });
}
