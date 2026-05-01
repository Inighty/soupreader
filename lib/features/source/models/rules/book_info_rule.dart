class BookInfoRule {
  final String? init;
  final String? name;
  final String? author;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? updateTime;
  final String? coverUrl;
  final String? tocUrl;
  final String? wordCount;
  final String? canReName;
  final String? downloadUrls;

  const BookInfoRule({
    this.init,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.coverUrl,
    this.tocUrl,
    this.wordCount,
    this.canReName,
    this.downloadUrls,
  });

  factory BookInfoRule.fromJson(Map<String, dynamic> json) {
    return BookInfoRule(
      init: json['init']?.toString(),
      name: json['name']?.toString(),
      author: json['author']?.toString(),
      intro: json['intro']?.toString(),
      kind: json['kind']?.toString(),
      lastChapter: json['lastChapter']?.toString(),
      updateTime: json['updateTime']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      tocUrl: json['tocUrl']?.toString(),
      wordCount: json['wordCount']?.toString(),
      canReName: json['canReName']?.toString(),
      downloadUrls: json['downloadUrls']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'init': init,
      'name': name,
      'author': author,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'updateTime': updateTime,
      'coverUrl': coverUrl,
      'tocUrl': tocUrl,
      'wordCount': wordCount,
      'canReName': canReName,
      'downloadUrls': downloadUrls,
    };
  }

  BookInfoRule copyWith({
    String? init,
    String? name,
    String? author,
    String? intro,
    String? kind,
    String? lastChapter,
    String? updateTime,
    String? coverUrl,
    String? tocUrl,
    String? wordCount,
    String? canReName,
    String? downloadUrls,
  }) => BookInfoRule(
    init: init ?? this.init,
    name: name ?? this.name,
    author: author ?? this.author,
    intro: intro ?? this.intro,
    kind: kind ?? this.kind,
    lastChapter: lastChapter ?? this.lastChapter,
    updateTime: updateTime ?? this.updateTime,
    coverUrl: coverUrl ?? this.coverUrl,
    tocUrl: tocUrl ?? this.tocUrl,
    wordCount: wordCount ?? this.wordCount,
    canReName: canReName ?? this.canReName,
    downloadUrls: downloadUrls ?? this.downloadUrls,
  );
}
