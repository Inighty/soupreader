class ContentRule {
  final String? content;
  final String? title;
  final String? nextContentUrl;
  final String? webJs;
  final String? sourceRegex;
  final String? replaceRegex;
  final String? imageStyle;
  final String? imageDecode;
  final String? payAction;

  const ContentRule({
    this.content,
    this.title,
    this.nextContentUrl,
    this.webJs,
    this.sourceRegex,
    this.replaceRegex,
    this.imageStyle,
    this.imageDecode,
    this.payAction,
  });

  factory ContentRule.fromJson(Map<String, dynamic> json) {
    return ContentRule(
      content: json['content']?.toString(),
      title: json['title']?.toString(),
      nextContentUrl: json['nextContentUrl']?.toString(),
      webJs: json['webJs']?.toString(),
      sourceRegex: json['sourceRegex']?.toString(),
      replaceRegex: json['replaceRegex']?.toString(),
      imageStyle: json['imageStyle']?.toString(),
      imageDecode: json['imageDecode']?.toString(),
      payAction: json['payAction']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'title': title,
      'nextContentUrl': nextContentUrl,
      'webJs': webJs,
      'sourceRegex': sourceRegex,
      'replaceRegex': replaceRegex,
      'imageStyle': imageStyle,
      'imageDecode': imageDecode,
      'payAction': payAction,
    };
  }

  ContentRule copyWith({
    String? content,
    String? title,
    String? nextContentUrl,
    String? webJs,
    String? sourceRegex,
    String? replaceRegex,
    String? imageStyle,
    String? imageDecode,
    String? payAction,
  }) => ContentRule(
    content: content ?? this.content,
    title: title ?? this.title,
    nextContentUrl: nextContentUrl ?? this.nextContentUrl,
    webJs: webJs ?? this.webJs,
    sourceRegex: sourceRegex ?? this.sourceRegex,
    replaceRegex: replaceRegex ?? this.replaceRegex,
    imageStyle: imageStyle ?? this.imageStyle,
    imageDecode: imageDecode ?? this.imageDecode,
    payAction: payAction ?? this.payAction,
  );
}
