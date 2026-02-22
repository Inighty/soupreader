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
    bool hasPayAction = true,
    bool? currentChapterIsVip,
    bool? currentChapterIsPay,
  }) {
    if (!hasLoginUrl || !hasPayAction) return false;
    if (currentChapterIsVip == null && currentChapterIsPay == null) {
      return true;
    }
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

  static ReaderSourcePayActionResult resolvePayActionOutput(String? output) {
    final text = (output ?? '').trim();
    if (isAbsoluteHttpUrl(text)) {
      return ReaderSourcePayActionResult.url(text);
    }
    if (isLegadoTruthy(text)) {
      return const ReaderSourcePayActionResult.success();
    }
    return const ReaderSourcePayActionResult.noop();
  }
}

enum ReaderSourcePayActionResultType {
  url,
  success,
  noop,
}

class ReaderSourcePayActionResult {
  final ReaderSourcePayActionResultType type;
  final String? url;

  const ReaderSourcePayActionResult._({
    required this.type,
    this.url,
  });

  const ReaderSourcePayActionResult.url(String url)
      : this._(type: ReaderSourcePayActionResultType.url, url: url);

  const ReaderSourcePayActionResult.success()
      : this._(type: ReaderSourcePayActionResultType.success);

  const ReaderSourcePayActionResult.noop()
      : this._(type: ReaderSourcePayActionResultType.noop);
}
