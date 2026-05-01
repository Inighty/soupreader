class ReviewRule {
  final String? reviewUrl;
  final String? avatarRule;
  final String? contentRule;
  final String? postTimeRule;
  final String? reviewQuoteUrl;
  final String? voteUpUrl;
  final String? voteDownUrl;
  final String? postReviewUrl;
  final String? postQuoteUrl;
  final String? deleteUrl;

  const ReviewRule({
    this.reviewUrl,
    this.avatarRule,
    this.contentRule,
    this.postTimeRule,
    this.reviewQuoteUrl,
    this.voteUpUrl,
    this.voteDownUrl,
    this.postReviewUrl,
    this.postQuoteUrl,
    this.deleteUrl,
  });

  factory ReviewRule.fromJson(Map<String, dynamic> json) {
    return ReviewRule(
      reviewUrl: json['reviewUrl']?.toString(),
      avatarRule: json['avatarRule']?.toString(),
      contentRule: json['contentRule']?.toString(),
      postTimeRule: json['postTimeRule']?.toString(),
      reviewQuoteUrl: json['reviewQuoteUrl']?.toString(),
      voteUpUrl: json['voteUpUrl']?.toString(),
      voteDownUrl: json['voteDownUrl']?.toString(),
      postReviewUrl: json['postReviewUrl']?.toString(),
      postQuoteUrl: json['postQuoteUrl']?.toString(),
      deleteUrl: json['deleteUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewUrl': reviewUrl,
      'avatarRule': avatarRule,
      'contentRule': contentRule,
      'postTimeRule': postTimeRule,
      'reviewQuoteUrl': reviewQuoteUrl,
      'voteUpUrl': voteUpUrl,
      'voteDownUrl': voteDownUrl,
      'postReviewUrl': postReviewUrl,
      'postQuoteUrl': postQuoteUrl,
      'deleteUrl': deleteUrl,
    };
  }
}
