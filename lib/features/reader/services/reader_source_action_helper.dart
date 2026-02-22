class ReaderSourceActionHelper {
  const ReaderSourceActionHelper._();

  static const List<String> legacyActionOrder = <String>[
    '登录',
    '章节购买',
    '编辑书源',
    '禁用书源',
  ];

  static bool hasLoginUrl(String? loginUrl) {
    return (loginUrl ?? '').trim().isNotEmpty;
  }

  static bool shouldShowChapterPay({
    required bool hasLoginUrl,
    bool? currentChapterIsVip,
    bool? currentChapterIsPay,
  }) {
    if (!hasLoginUrl) return false;
    return currentChapterIsVip == true && currentChapterIsPay != true;
  }

  static bool isAbsoluteHttpUrl(String raw) {
    final text = raw.trim().toLowerCase();
    return text.startsWith('http://') || text.startsWith('https://');
  }

  static bool isLegadoTruthy(String? output) {
    final text = (output ?? '').trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return false;
    }
    return !RegExp(r'^(false|no|not|0)$', caseSensitive: false).hasMatch(text);
  }
}
