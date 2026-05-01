/// 列表型规则的公共契约：搜索 / 发现共用同一组解析字段。
abstract class BookListRule {
  String? get bookList;
  String? get name;
  String? get author;
  String? get intro;
  String? get kind;
  String? get lastChapter;
  String? get updateTime;
  String? get bookUrl;
  String? get coverUrl;
  String? get wordCount;
}
