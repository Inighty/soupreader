/// HTML 转纯文本格式化工具（对标 Legado `HtmlFormatter.format`）
///
/// 目的：
/// - 将书源/EPUB 中的正文 HTML 统一转为“可阅读”的纯文本
/// - 尽可能保留段落边界（将常见块级/换行标签转换为 `\n`）
/// - 清理常见不可见字符与空白实体，避免缩进/排版异常
///
/// 说明：
/// - 本工具仅负责 HTML -> 文本 + 换行规范化；段首缩进等排版策略由阅读器层统一处理
/// - 参考同级项目 legado：`io.legado.app.utils.HtmlFormatter`
class HtmlTextFormatter {
  static final RegExp _nbspRegex =
      RegExp(r'(&nbsp;)+', caseSensitive: false, multiLine: true);
  static final RegExp _espRegex =
      RegExp(r'(&ensp;|&emsp;)', caseSensitive: false, multiLine: true);
  static final RegExp _noPrintRegex = RegExp(
    r'(&thinsp;|&zwnj;|&zwj;|\u2009|\u200C|\u200D)',
    caseSensitive: false,
    multiLine: true,
  );

  /// 将常见“会导致换行/分段”的标签替换为换行符。
  ///
  /// 对标 legado 的 wrapHtmlRegex（div/p/br/hr/h\d/article/dd/dl）。
  static final RegExp _wrapHtmlRegex = RegExp(
    r'</?(?:div|p|br|hr|h\d|article|dd|dl|li|tr|table|section)[^>]*>',
    caseSensitive: false,
    multiLine: true,
  );

  /// HTML 注释（可能跨行）
  static final RegExp _commentRegex =
      RegExp(r'<!--[\s\S]*?-->', caseSensitive: false, multiLine: true);

  /// 剩余标签清理（不做复杂解析，保持和 legado 一样“实用主义”）
  static final RegExp _otherHtmlRegex = RegExp(
    r'</?[a-zA-Z]+(?=[ >])[^<>]*>',
    caseSensitive: false,
    multiLine: true,
  );

  /// 规范化段落：忽略多余空白与多换行（对标 legado 的 `\\s*\\n+\\s*`）
  static final RegExp _indent1Regex = RegExp(r'\s*\n+\s*', multiLine: true);

  /// 额外：去除首尾空白行
  static final RegExp _leadingNewlineRegex = RegExp(r'^[\n\s]+', multiLine: true);
  static final RegExp _trailingNewlineRegex = RegExp(r'[\n\s]+$', multiLine: true);

  /// 将 HTML 或混合文本转为“干净的纯文本”。
  static String formatToPlainText(String input) {
    if (input.isEmpty) return '';

    var text = input;

    // 统一换行符
    text = text.replaceAll('\r\n', '\n');

    // Android/部分源的 NBSP 字符
    text = text.replaceAll('\u00A0', ' ');

    // 实体/不可见字符（对标 legado noPrintRegex）
    text = text.replaceAll(_nbspRegex, ' ');
    text = text.replaceAll(_espRegex, ' ');
    text = text.replaceAll(_noPrintRegex, '');

    // 块级/换行标签 -> \n
    text = text.replaceAll(_wrapHtmlRegex, '\n');

    // 注释清理
    text = text.replaceAll(_commentRegex, '');

    // 剩余标签清理
    text = text.replaceAll(_otherHtmlRegex, '');

    // 常见实体解码（尽量“够用”，不引入额外依赖）
    text = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        // 常见空白数字实体
        .replaceAll(RegExp(r'&#(160|xa0);', caseSensitive: false), ' ');

    // 规范化段落：压缩多余空白与多换行
    text = text.replaceAll(_indent1Regex, '\n');
    text = text.replaceAll(_leadingNewlineRegex, '');
    text = text.replaceAll(_trailingNewlineRegex, '');

    return text.trim();
  }
}

