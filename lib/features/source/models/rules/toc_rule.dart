class TocRule {
  final String? preUpdateJs;
  final String? chapterList;
  final String? chapterName;
  final String? chapterUrl;
  final String? formatJs;
  final String? isVolume;
  final String? isVip;
  final String? isPay;
  final String? updateTime;
  final String? nextTocUrl;

  const TocRule({
    this.preUpdateJs,
    this.chapterList,
    this.chapterName,
    this.chapterUrl,
    this.formatJs,
    this.isVolume,
    this.isVip,
    this.isPay,
    this.updateTime,
    this.nextTocUrl,
  });

  factory TocRule.fromJson(Map<String, dynamic> json) {
    return TocRule(
      preUpdateJs: json['preUpdateJs']?.toString(),
      chapterList: json['chapterList']?.toString(),
      chapterName: json['chapterName']?.toString(),
      chapterUrl: json['chapterUrl']?.toString(),
      formatJs: json['formatJs']?.toString(),
      isVolume: json['isVolume']?.toString(),
      isVip: json['isVip']?.toString(),
      isPay: json['isPay']?.toString(),
      updateTime: json['updateTime']?.toString(),
      nextTocUrl: json['nextTocUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preUpdateJs': preUpdateJs,
      'chapterList': chapterList,
      'chapterName': chapterName,
      'chapterUrl': chapterUrl,
      'formatJs': formatJs,
      'isVolume': isVolume,
      'isVip': isVip,
      'isPay': isPay,
      'updateTime': updateTime,
      'nextTocUrl': nextTocUrl,
    };
  }

  TocRule copyWith({
    String? preUpdateJs,
    String? chapterList,
    String? chapterName,
    String? chapterUrl,
    String? formatJs,
    String? nextTocUrl,
  }) => TocRule(
    preUpdateJs: preUpdateJs ?? this.preUpdateJs,
    chapterList: chapterList ?? this.chapterList,
    chapterName: chapterName ?? this.chapterName,
    chapterUrl: chapterUrl ?? this.chapterUrl,
    formatJs: formatJs ?? this.formatJs,
    nextTocUrl: nextTocUrl ?? this.nextTocUrl,
  );
}
