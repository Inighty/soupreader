class DirectLinkUploadRule {
  const DirectLinkUploadRule({
    required this.uploadUrl,
    required this.downloadUrlRule,
    required this.summary,
    required this.compress,
  });

  final String uploadUrl;
  final String downloadUrlRule;
  final String summary;
  final bool compress;

  factory DirectLinkUploadRule.empty() {
    return const DirectLinkUploadRule(
      uploadUrl: '',
      downloadUrlRule: '',
      summary: '',
      compress: false,
    );
  }

  factory DirectLinkUploadRule.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value, {required bool fallback}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
      return fallback;
    }

    return DirectLinkUploadRule(
      uploadUrl: (json['uploadUrl'] ?? '').toString(),
      downloadUrlRule: (json['downloadUrlRule'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      compress: parseBool(json['compress'], fallback: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uploadUrl': uploadUrl,
      'downloadUrlRule': downloadUrlRule,
      'summary': summary,
      'compress': compress,
    };
  }
}
