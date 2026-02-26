import 'rss_article.dart';

/// RSS 收藏模型（对齐 legado `RssStar` 关键字段）
class RssStar {
  final String origin;
  final String sort;
  final String title;
  final int starTime;
  final String link;
  final String? pubDate;
  final String? description;
  final String? content;
  final String? image;
  final String group;
  final String? variable;

  const RssStar({
    this.origin = '',
    this.sort = '',
    this.title = '',
    this.starTime = 0,
    this.link = '',
    this.pubDate,
    this.description,
    this.content,
    this.image,
    this.group = '默认分组',
    this.variable,
  });

  RssStar copyWith({
    String? origin,
    String? sort,
    String? title,
    int? starTime,
    String? link,
    String? pubDate,
    String? description,
    String? content,
    String? image,
    String? group,
    String? variable,
  }) {
    return RssStar(
      origin: origin ?? this.origin,
      sort: sort ?? this.sort,
      title: title ?? this.title,
      starTime: starTime ?? this.starTime,
      link: link ?? this.link,
      pubDate: pubDate ?? this.pubDate,
      description: description ?? this.description,
      content: content ?? this.content,
      image: image ?? this.image,
      group: group ?? this.group,
      variable: variable ?? this.variable,
    );
  }

  RssArticle toRssArticle() {
    return RssArticle(
      origin: origin,
      sort: sort,
      title: title,
      order: starTime,
      link: link,
      pubDate: pubDate,
      description: description,
      content: content,
      image: image,
      group: group,
      variable: variable,
    );
  }
}
