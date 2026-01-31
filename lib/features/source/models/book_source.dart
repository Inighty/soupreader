/// 书源模型 - 兼容源阅(Legado)格式
class BookSource {
  final String bookSourceName;
  final String bookSourceUrl;
  final int bookSourceType; // 0:文字, 1:音频, 2:图片
  final String? bookSourceGroup;
  final String? bookSourceComment;
  final bool enabled;
  final int weight; // 权重，用于排序
  final String? header; // 自定义请求头
  final String? loginUrl;
  final DateTime? lastUpdateTime;

  // 搜索规则
  final SearchRule? ruleSearch;

  // 书籍详情规则
  final BookInfoRule? ruleBookInfo;

  // 目录规则
  final TocRule? ruleToc;

  // 正文规则
  final ContentRule? ruleContent;

  const BookSource({
    required this.bookSourceName,
    required this.bookSourceUrl,
    this.bookSourceType = 0,
    this.bookSourceGroup,
    this.bookSourceComment,
    this.enabled = true,
    this.weight = 0,
    this.header,
    this.loginUrl,
    this.lastUpdateTime,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
  });

  /// 从JSON创建（兼容源阅格式）
  factory BookSource.fromJson(Map<String, dynamic> json) {
    return BookSource(
      bookSourceName: json['bookSourceName'] as String? ?? '',
      bookSourceUrl: json['bookSourceUrl'] as String? ?? '',
      bookSourceType: json['bookSourceType'] as int? ?? 0,
      bookSourceGroup: json['bookSourceGroup'] as String?,
      bookSourceComment: json['bookSourceComment'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      weight: json['weight'] as int? ?? 0,
      header: json['header'] as String?,
      loginUrl: json['loginUrl'] as String?,
      lastUpdateTime: json['lastUpdateTime'] != null
          ? DateTime.tryParse(json['lastUpdateTime'].toString())
          : null,
      ruleSearch: json['ruleSearch'] != null
          ? SearchRule.fromJson(json['ruleSearch'] as Map<String, dynamic>)
          : null,
      ruleBookInfo: json['ruleBookInfo'] != null
          ? BookInfoRule.fromJson(json['ruleBookInfo'] as Map<String, dynamic>)
          : null,
      ruleToc: json['ruleToc'] != null
          ? TocRule.fromJson(json['ruleToc'] as Map<String, dynamic>)
          : null,
      ruleContent: json['ruleContent'] != null
          ? ContentRule.fromJson(json['ruleContent'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'bookSourceName': bookSourceName,
      'bookSourceUrl': bookSourceUrl,
      'bookSourceType': bookSourceType,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceComment': bookSourceComment,
      'enabled': enabled,
      'weight': weight,
      'header': header,
      'loginUrl': loginUrl,
      'lastUpdateTime': lastUpdateTime?.toIso8601String(),
      'ruleSearch': ruleSearch?.toJson(),
      'ruleBookInfo': ruleBookInfo?.toJson(),
      'ruleToc': ruleToc?.toJson(),
      'ruleContent': ruleContent?.toJson(),
    };
  }

  /// 获取唯一标识
  String get id => bookSourceUrl;

  /// 复制并修改
  BookSource copyWith({
    String? bookSourceName,
    String? bookSourceUrl,
    int? bookSourceType,
    String? bookSourceGroup,
    String? bookSourceComment,
    bool? enabled,
    int? weight,
    String? header,
    String? loginUrl,
    DateTime? lastUpdateTime,
    SearchRule? ruleSearch,
    BookInfoRule? ruleBookInfo,
    TocRule? ruleToc,
    ContentRule? ruleContent,
  }) {
    return BookSource(
      bookSourceName: bookSourceName ?? this.bookSourceName,
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
      bookSourceType: bookSourceType ?? this.bookSourceType,
      bookSourceGroup: bookSourceGroup ?? this.bookSourceGroup,
      bookSourceComment: bookSourceComment ?? this.bookSourceComment,
      enabled: enabled ?? this.enabled,
      weight: weight ?? this.weight,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      ruleSearch: ruleSearch ?? this.ruleSearch,
      ruleBookInfo: ruleBookInfo ?? this.ruleBookInfo,
      ruleToc: ruleToc ?? this.ruleToc,
      ruleContent: ruleContent ?? this.ruleContent,
    );
  }
}

/// 搜索规则
class SearchRule {
  final String? url;
  final String? bookList;
  final String? name;
  final String? author;
  final String? coverUrl;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? bookUrl;

  const SearchRule({
    this.url,
    this.bookList,
    this.name,
    this.author,
    this.coverUrl,
    this.intro,
    this.kind,
    this.lastChapter,
    this.bookUrl,
  });

  factory SearchRule.fromJson(Map<String, dynamic> json) {
    return SearchRule(
      url: json['url'] as String?,
      bookList: json['bookList'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      lastChapter: json['lastChapter'] as String?,
      bookUrl: json['bookUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'bookList': bookList,
      'name': name,
      'author': author,
      'coverUrl': coverUrl,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'bookUrl': bookUrl,
    };
  }
}

/// 书籍详情规则
class BookInfoRule {
  final String? init;
  final String? name;
  final String? author;
  final String? coverUrl;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? tocUrl;

  const BookInfoRule({
    this.init,
    this.name,
    this.author,
    this.coverUrl,
    this.intro,
    this.kind,
    this.lastChapter,
    this.tocUrl,
  });

  factory BookInfoRule.fromJson(Map<String, dynamic> json) {
    return BookInfoRule(
      init: json['init'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      lastChapter: json['lastChapter'] as String?,
      tocUrl: json['tocUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'init': init,
      'name': name,
      'author': author,
      'coverUrl': coverUrl,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'tocUrl': tocUrl,
    };
  }
}

/// 目录规则
class TocRule {
  final String? chapterList;
  final String? chapterName;
  final String? chapterUrl;
  final String? nextTocUrl;

  const TocRule({
    this.chapterList,
    this.chapterName,
    this.chapterUrl,
    this.nextTocUrl,
  });

  factory TocRule.fromJson(Map<String, dynamic> json) {
    return TocRule(
      chapterList: json['chapterList'] as String?,
      chapterName: json['chapterName'] as String?,
      chapterUrl: json['chapterUrl'] as String?,
      nextTocUrl: json['nextTocUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterList': chapterList,
      'chapterName': chapterName,
      'chapterUrl': chapterUrl,
      'nextTocUrl': nextTocUrl,
    };
  }
}

/// 正文规则
class ContentRule {
  final String? content;
  final String? nextContentUrl;
  final String? replaceRegex;

  const ContentRule({this.content, this.nextContentUrl, this.replaceRegex});

  factory ContentRule.fromJson(Map<String, dynamic> json) {
    return ContentRule(
      content: json['content'] as String?,
      nextContentUrl: json['nextContentUrl'] as String?,
      replaceRegex: json['replaceRegex'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'nextContentUrl': nextContentUrl,
      'replaceRegex': replaceRegex,
    };
  }
}
