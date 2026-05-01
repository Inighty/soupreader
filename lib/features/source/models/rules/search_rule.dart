import 'package:soupreader/features/source/models/rules/book_list_rule.dart';

class SearchRule implements BookListRule {
  final String? checkKeyWord;
  @override
  final String? bookList;
  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? intro;
  @override
  final String? kind;
  @override
  final String? lastChapter;
  @override
  final String? updateTime;
  @override
  final String? bookUrl;
  @override
  final String? coverUrl;
  @override
  final String? wordCount;

  const SearchRule({
    this.checkKeyWord,
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  factory SearchRule.fromJson(Map<String, dynamic> json) {
    return SearchRule(
      checkKeyWord: json['checkKeyWord']?.toString(),
      bookList: json['bookList']?.toString(),
      name: json['name']?.toString(),
      author: json['author']?.toString(),
      intro: json['intro']?.toString(),
      kind: json['kind']?.toString(),
      lastChapter: json['lastChapter']?.toString(),
      updateTime: json['updateTime']?.toString(),
      bookUrl: json['bookUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      wordCount: json['wordCount']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkKeyWord': checkKeyWord,
      'bookList': bookList,
      'name': name,
      'author': author,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'updateTime': updateTime,
      'bookUrl': bookUrl,
      'coverUrl': coverUrl,
      'wordCount': wordCount,
    };
  }

  SearchRule copyWith({
    String? checkKeyWord,
    String? bookList,
    String? name,
    String? author,
    String? intro,
    String? kind,
    String? lastChapter,
    String? updateTime,
    String? bookUrl,
    String? coverUrl,
    String? wordCount,
  }) => SearchRule(
    checkKeyWord: checkKeyWord ?? this.checkKeyWord,
    bookList: bookList ?? this.bookList,
    name: name ?? this.name,
    author: author ?? this.author,
    intro: intro ?? this.intro,
    kind: kind ?? this.kind,
    lastChapter: lastChapter ?? this.lastChapter,
    updateTime: updateTime ?? this.updateTime,
    bookUrl: bookUrl ?? this.bookUrl,
    coverUrl: coverUrl ?? this.coverUrl,
    wordCount: wordCount ?? this.wordCount,
  );
}
