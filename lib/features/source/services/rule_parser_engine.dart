import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/html_text_formatter.dart';

/// 书源规则解析引擎
/// 支持 CSS 选择器、XPath（简化版）和正则表达式
class RuleParserEngine {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    },
  ));

  /// 搜索书籍
  Future<List<SearchResult>> search(BookSource source, String keyword) async {
    final searchRule = source.ruleSearch;
    final searchUrlRule = source.searchUrl;
    if (searchRule == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return [];
    }

    try {
      // 构建搜索URL
      final searchUrl = _buildUrl(
        source.bookSourceUrl,
        searchUrlRule,
        {'key': keyword, 'searchKey': keyword},
      );

      // 发送请求
      final response = await _fetch(searchUrl, source.header);
      if (response == null) return [];

      // 解析结果
      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      // 获取书籍列表
      final bookListRule = searchRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        final result = SearchResult(
          name: _parseRule(element, searchRule.name, source.bookSourceUrl),
          author: _parseRule(element, searchRule.author, source.bookSourceUrl),
          coverUrl:
              _parseRule(element, searchRule.coverUrl, source.bookSourceUrl),
          intro: _parseRule(element, searchRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, searchRule.lastChapter, source.bookSourceUrl),
          bookUrl:
              _parseRule(element, searchRule.bookUrl, source.bookSourceUrl),
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return results;
    } catch (e) {
      debugPrint('搜索失败: $e');
      return [];
    }
  }

  /// 搜索调试：返回「请求/解析」过程的关键诊断信息
  Future<SearchDebugResult> searchDebug(BookSource source, String keyword) async {
    final searchRule = source.ruleSearch;
    final searchUrlRule = source.searchUrl;
    if (searchRule == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return SearchDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule?.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'searchUrl / ruleSearch 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      searchUrlRule,
      {'key': keyword, 'searchKey': keyword},
    );

    final fetch = await _fetchDebug(requestUrl, source.header);
    if (fetch.body == null) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final bookListRule = searchRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};

      for (final element in bookElements) {
        final name = _parseRule(element, searchRule.name, source.bookSourceUrl);
        final author =
            _parseRule(element, searchRule.author, source.bookSourceUrl);
        final coverUrl =
            _parseRule(element, searchRule.coverUrl, source.bookSourceUrl);
        final intro =
            _parseRule(element, searchRule.intro, source.bookSourceUrl);
        final lastChapter =
            _parseRule(element, searchRule.lastChapter, source.bookSourceUrl);
        final bookUrl =
            _parseRule(element, searchRule.bookUrl, source.bookSourceUrl);

        final result = SearchResult(
          name: name,
          author: author,
          coverUrl: coverUrl,
          intro: intro,
          lastChapter: lastChapter,
          bookUrl: bookUrl,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (results.isEmpty) {
          fieldSample = <String, String>{
            'name': name,
            'author': author,
            'coverUrl': coverUrl,
            'intro': intro,
            'lastChapter': lastChapter,
            'bookUrl': bookUrl,
          };
        }

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: bookListRule,
        listCount: bookElements.length,
        results: results,
        fieldSample: fieldSample,
        error: null,
      );
    } catch (e) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 发现书籍
  ///
  /// 对标 Legado：`exploreUrl` + `ruleExplore`
  Future<List<SearchResult>> explore(
    BookSource source, {
    String? exploreUrlOverride,
  }) async {
    final exploreRule = source.ruleExplore;
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (exploreRule == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return [];
    }

    try {
      final exploreUrl = _buildUrl(
        source.bookSourceUrl,
        exploreUrlRule,
        const {},
      );

      final response = await _fetch(exploreUrl, source.header);
      if (response == null) return [];

      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      final bookListRule = exploreRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        final result = SearchResult(
          name: _parseRule(element, exploreRule.name, source.bookSourceUrl),
          author: _parseRule(element, exploreRule.author, source.bookSourceUrl),
          coverUrl:
              _parseRule(element, exploreRule.coverUrl, source.bookSourceUrl),
          intro: _parseRule(element, exploreRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, exploreRule.lastChapter, source.bookSourceUrl),
          bookUrl:
              _parseRule(element, exploreRule.bookUrl, source.bookSourceUrl),
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return results;
    } catch (e) {
      debugPrint('发现失败: $e');
      return [];
    }
  }

  Future<ExploreDebugResult> exploreDebug(
    BookSource source, {
    String? exploreUrlOverride,
  }) async {
    final exploreRule = source.ruleExplore;
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (exploreRule == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return ExploreDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule?.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'exploreUrl / ruleExplore 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      exploreUrlRule,
      const {},
    );
    final fetch = await _fetchDebug(requestUrl, source.header);
    if (fetch.body == null) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final bookListRule = exploreRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};

      for (final element in bookElements) {
        final name = _parseRule(element, exploreRule.name, source.bookSourceUrl);
        final author =
            _parseRule(element, exploreRule.author, source.bookSourceUrl);
        final coverUrl =
            _parseRule(element, exploreRule.coverUrl, source.bookSourceUrl);
        final intro =
            _parseRule(element, exploreRule.intro, source.bookSourceUrl);
        final lastChapter = _parseRule(
          element,
          exploreRule.lastChapter,
          source.bookSourceUrl,
        );
        final bookUrl =
            _parseRule(element, exploreRule.bookUrl, source.bookSourceUrl);

        final result = SearchResult(
          name: name,
          author: author,
          coverUrl: coverUrl,
          intro: intro,
          lastChapter: lastChapter,
          bookUrl: bookUrl,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (results.isEmpty) {
          fieldSample = <String, String>{
            'name': name,
            'author': author,
            'coverUrl': coverUrl,
            'intro': intro,
            'lastChapter': lastChapter,
            'bookUrl': bookUrl,
          };
        }

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: bookListRule,
        listCount: bookElements.length,
        results: results,
        fieldSample: fieldSample,
        error: null,
      );
    } catch (e) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取书籍详情
  Future<BookDetail?> getBookInfo(BookSource source, String bookUrl) async {
    final bookInfoRule = source.ruleBookInfo;
    if (bookInfoRule == null) return null;

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
      final response = await _fetch(fullUrl, source.header);
      if (response == null) return null;

      final document = html_parser.parse(response);
      Element? root = document.documentElement;

      // 如果有 init 规则，先定位根元素
      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _querySelector(document, bookInfoRule.init!);
      }

      if (root == null) return null;

      return BookDetail(
        name: _parseRule(root, bookInfoRule.name, source.bookSourceUrl),
        author: _parseRule(root, bookInfoRule.author, source.bookSourceUrl),
        coverUrl: _parseRule(root, bookInfoRule.coverUrl, source.bookSourceUrl),
        intro: _parseRule(root, bookInfoRule.intro, source.bookSourceUrl),
        kind: _parseRule(root, bookInfoRule.kind, source.bookSourceUrl),
        lastChapter:
            _parseRule(root, bookInfoRule.lastChapter, source.bookSourceUrl),
        tocUrl: _parseRule(root, bookInfoRule.tocUrl, source.bookSourceUrl),
        bookUrl: fullUrl,
      );
    } catch (e) {
      debugPrint('获取书籍详情失败: $e');
      return null;
    }
  }

  Future<BookInfoDebugResult> getBookInfoDebug(
    BookSource source,
    String bookUrl,
  ) async {
    final bookInfoRule = source.ruleBookInfo;
    if (bookInfoRule == null) {
      return BookInfoDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: null,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: 'ruleBookInfo 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
    final fetch = await _fetchDebug(fullUrl, source.header);
    if (fetch.body == null) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      Element? root = document.documentElement;
      var initMatched = true;

      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _querySelector(document, bookInfoRule.init!);
        initMatched = root != null;
      }
      if (root == null) {
        return BookInfoDebugResult(
          fetch: fetch,
          requestType: DebugRequestType.bookInfo,
          requestUrlRule: bookUrl,
          initRule: bookInfoRule.init,
          initMatched: initMatched,
          detail: null,
          fieldSample: const {},
          error: 'init 定位失败或页面无 documentElement',
        );
      }

      final name = _parseRule(root, bookInfoRule.name, source.bookSourceUrl);
      final author =
          _parseRule(root, bookInfoRule.author, source.bookSourceUrl);
      final coverUrl =
          _parseRule(root, bookInfoRule.coverUrl, source.bookSourceUrl);
      final intro = _parseRule(root, bookInfoRule.intro, source.bookSourceUrl);
      final kind = _parseRule(root, bookInfoRule.kind, source.bookSourceUrl);
      final lastChapter =
          _parseRule(root, bookInfoRule.lastChapter, source.bookSourceUrl);
      final tocUrl =
          _parseRule(root, bookInfoRule.tocUrl, source.bookSourceUrl);

      final detail = BookDetail(
        name: name,
        author: author,
        coverUrl: coverUrl,
        intro: intro,
        kind: kind,
        lastChapter: lastChapter,
        tocUrl: tocUrl,
        bookUrl: fullUrl,
      );

      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: initMatched,
        detail: detail,
        fieldSample: <String, String>{
          'name': name,
          'author': author,
          'coverUrl': coverUrl,
          'intro': intro,
          'kind': kind,
          'lastChapter': lastChapter,
          'tocUrl': tocUrl,
        },
        error: null,
      );
    } catch (e) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取目录
  Future<List<TocItem>> getToc(BookSource source, String tocUrl) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) return [];

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
      final response = await _fetch(fullUrl, source.header);
      if (response == null) return [];

      final document = html_parser.parse(response);
      final chapters = <TocItem>[];

      // 获取章节列表
      final chapterListRule = tocRule.chapterList ?? '';
      final chapterElements = _querySelectorAll(document, chapterListRule);

      for (int i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final item = TocItem(
          index: i,
          name: _parseRule(element, tocRule.chapterName, source.bookSourceUrl),
          url: _parseRule(element, tocRule.chapterUrl, source.bookSourceUrl),
        );

        if (item.name.isNotEmpty && item.url.isNotEmpty) {
          chapters.add(item);
        }
      }

      return chapters;
    } catch (e) {
      debugPrint('获取目录失败: $e');
      return [];
    }
  }

  Future<TocDebugResult> getTocDebug(BookSource source, String tocUrl) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) {
      return TocDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: null,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: 'ruleToc 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    final fetch = await _fetchDebug(fullUrl, source.header);
    if (fetch.body == null) {
      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: tocRule.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final chapterListRule = tocRule.chapterList ?? '';
      final chapterElements = _querySelectorAll(document, chapterListRule);

      final chapters = <TocItem>[];
      Map<String, String> sample = const {};
      for (var i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final name =
            _parseRule(element, tocRule.chapterName, source.bookSourceUrl);
        final url =
            _parseRule(element, tocRule.chapterUrl, source.bookSourceUrl);
        if (chapters.isEmpty) {
          sample = <String, String>{'name': name, 'url': url};
        }
        if (name.isNotEmpty && url.isNotEmpty) {
          chapters.add(TocItem(index: i, name: name, url: url));
        }
      }

      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: chapterListRule,
        listCount: chapterElements.length,
        toc: chapters,
        fieldSample: sample,
        error: null,
      );
    } catch (e) {
      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: tocRule.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取正文
  Future<String> getContent(BookSource source, String chapterUrl) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) return '';

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
      final response = await _fetch(fullUrl, source.header);
      if (response == null) return '';

      final document = html_parser.parse(response);
      String content = _parseRule(
        document.documentElement!,
        contentRule.content,
        source.bookSourceUrl,
      );

      // 应用替换规则
      if (contentRule.replaceRegex != null &&
          contentRule.replaceRegex!.isNotEmpty) {
        content = _applyReplaceRegex(content, contentRule.replaceRegex!);
      }

      // 清理内容
      content = _cleanContent(content);

      return content;
    } catch (e) {
      debugPrint('获取正文失败: $e');
      return '';
    }
  }

  Future<ContentDebugResult> getContentDebug(
    BookSource source,
    String chapterUrl,
  ) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) {
      return ContentDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: 'ruleContent 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final fetch = await _fetchDebug(fullUrl, source.header);
    if (fetch.body == null) {
      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final extracted = _parseRule(
        document.documentElement!,
        contentRule.content,
        source.bookSourceUrl,
      );
      var text = extracted;
      if (contentRule.replaceRegex != null &&
          contentRule.replaceRegex!.isNotEmpty) {
        text = _applyReplaceRegex(text, contentRule.replaceRegex!);
      }
      final cleaned = _cleanContent(text);

      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: extracted.length,
        cleanedLength: cleaned.length,
        content: cleaned,
        error: null,
      );
    } catch (e) {
      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: '解析失败: $e',
      );
    }
  }

  /// 发送HTTP请求
  Future<String?> _fetch(String url, String? header) async {
    try {
      final options = Options();
      if (header != null && header.isNotEmpty) {
        try {
          // 尝试解析自定义 header
          final headers = <String, String>{};
          for (final line in header.split('\n')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              headers[parts[0].trim()] = parts.sublist(1).join(':').trim();
            }
          }
          options.headers = headers;
        } catch (_) {}
      }

      final response = await _dio.get(url, options: options);
      return response.data?.toString();
    } catch (e) {
      debugPrint('请求失败: $url - $e');
      return null;
    }
  }

  Future<FetchDebugResult> _fetchDebug(String url, String? header) async {
    final sw = Stopwatch()..start();
    try {
      final options = Options();
      final requestHeaders = <String, String>{};
      if (header != null && header.isNotEmpty) {
        for (final line in header.split('\n')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            requestHeaders[parts[0].trim()] = parts.sublist(1).join(':').trim();
          }
        }
      }
      if (requestHeaders.isNotEmpty) {
        options.headers = requestHeaders;
      }

      final response = await _dio.get(url, options: options);
      final body = response.data?.toString();
      sw.stop();
      return FetchDebugResult(
        requestUrl: url,
        finalUrl: response.realUri.toString(),
        statusCode: response.statusCode,
        elapsedMs: sw.elapsedMilliseconds,
        responseLength: body?.length ?? 0,
        responseSnippet: _snippet(body),
        requestHeaders: requestHeaders,
        error: null,
        body: body,
      );
    } catch (e) {
      sw.stop();
      return FetchDebugResult(
        requestUrl: url,
        finalUrl: null,
        statusCode: null,
        elapsedMs: sw.elapsedMilliseconds,
        responseLength: 0,
        responseSnippet: null,
        requestHeaders: const {},
        error: e.toString(),
        body: null,
      );
    }
  }

  String? _snippet(String? text) {
    if (text == null) return null;
    final t = text.replaceAll('\r\n', '\n');
    final max = 1200;
    if (t.length <= max) return t;
    return t.substring(0, max);
  }

  /// 构建URL
  String _buildUrl(String baseUrl, String rule, Map<String, String> params) {
    String url = rule;

    // 替换参数
    params.forEach((key, value) {
      url = url.replaceAll('{{$key}}', Uri.encodeComponent(value));
      url = url.replaceAll('{$key}', Uri.encodeComponent(value));
    });

    return _absoluteUrl(baseUrl, url);
  }

  /// 转换为绝对URL
  String _absoluteUrl(String baseUrl, String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$url';
    }
    return '$baseUrl/$url';
  }

  /// 解析规则
  String _parseRule(Element element, String? rule, String baseUrl) {
    if (rule == null || rule.isEmpty) return '';

    String result = '';

    // 处理多个规则（用 || 分隔，表示备选）
    final rules = rule.split('||');
    for (final r in rules) {
      result = _parseSingleRule(element, r.trim(), baseUrl);
      if (result.isNotEmpty) break;
    }

    return result.trim();
  }

  /// 解析单个规则
  String _parseSingleRule(Element element, String rule, String baseUrl) {
    if (rule.isEmpty) return '';

    // 提取属性规则 @attr 或 @text
    String? attrRule;
    String selectorRule = rule;

    if (rule.contains('@')) {
      final atIndex = rule.lastIndexOf('@');
      selectorRule = rule.substring(0, atIndex).trim();
      attrRule = rule.substring(atIndex + 1).trim();
    }

    // 如果选择器为空，使用当前元素
    Element? target = element;
    if (selectorRule.isNotEmpty) {
      target = _querySelector(element, selectorRule);
    }

    if (target == null) return '';

    // 获取内容
    String result;
    if (attrRule == null || attrRule == 'text') {
      result = target.text;
    } else if (attrRule == 'textNodes') {
      result = target.nodes.whereType<Text>().map((t) => t.text).join('');
    } else if (attrRule == 'ownText') {
      result = target.nodes.whereType<Text>().map((t) => t.text).join('');
    } else if (attrRule == 'html' || attrRule == 'innerHTML') {
      result = target.innerHtml;
    } else if (attrRule == 'outerHtml') {
      result = target.outerHtml;
    } else {
      result = target.attributes[attrRule] ?? '';
    }

    // 如果是URL属性，转换为绝对路径
    if (attrRule == 'href' || attrRule == 'src') {
      result = _absoluteUrl(baseUrl, result);
    }

    return result.trim();
  }

  /// CSS选择器查询单个元素
  Element? _querySelector(dynamic parent, String selector) {
    if (selector.isEmpty) return null;

    try {
      if (parent is Document) {
        return parent.querySelector(selector);
      } else if (parent is Element) {
        return parent.querySelector(selector);
      }
    } catch (e) {
      debugPrint('选择器解析失败: $selector - $e');
    }

    return null;
  }

  /// CSS选择器查询多个元素
  List<Element> _querySelectorAll(dynamic parent, String selector) {
    if (selector.isEmpty) return [];

    try {
      if (parent is Document) {
        return parent.querySelectorAll(selector);
      } else if (parent is Element) {
        return parent.querySelectorAll(selector);
      }
    } catch (e) {
      debugPrint('选择器解析失败: $selector - $e');
    }

    return [];
  }

  /// 应用替换正则
  String _applyReplaceRegex(String content, String replaceRegex) {
    try {
      // 源阅格式: regex##replacement##regex2##replacement2...
      final parts = replaceRegex.split('##');
      for (int i = 0; i < parts.length - 1; i += 2) {
        final regex = RegExp(parts[i]);
        final replacement = parts.length > i + 1 ? parts[i + 1] : '';
        content = content.replaceAll(regex, replacement);
      }
    } catch (e) {
      debugPrint('替换正则失败: $e');
    }
    return content;
  }

  /// 清理正文内容
  String _cleanContent(String content) {
    // 对齐 legado 的 HTML -> 文本清理策略（块级标签换行、不可见字符移除）
    return HtmlTextFormatter.formatToPlainText(content);
  }
}

enum DebugRequestType { search, explore, bookInfo, toc, content }

class FetchDebugResult {
  final String requestUrl;
  final String? finalUrl;
  final int? statusCode;
  final int elapsedMs;
  final int responseLength;
  final String? responseSnippet;
  final Map<String, String> requestHeaders;
  final String? error;

  /// 原始响应体（仅用于编辑器调试；不要在普通 UI 中到处传递）
  final String? body;

  const FetchDebugResult({
    required this.requestUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.elapsedMs,
    required this.responseLength,
    required this.responseSnippet,
    required this.requestHeaders,
    required this.error,
    required this.body,
  });

  factory FetchDebugResult.empty() {
    return const FetchDebugResult(
      requestUrl: '',
      finalUrl: null,
      statusCode: null,
      elapsedMs: 0,
      responseLength: 0,
      responseSnippet: null,
      requestHeaders: {},
      error: null,
      body: null,
    );
  }
}

class SearchDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<SearchResult> results;
  final Map<String, String> fieldSample;
  final String? error;

  const SearchDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.results,
    required this.fieldSample,
    required this.error,
  });
}

class ExploreDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<SearchResult> results;
  final Map<String, String> fieldSample;
  final String? error;

  const ExploreDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.results,
    required this.fieldSample,
    required this.error,
  });
}

class BookInfoDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? initRule;
  final bool initMatched;
  final BookDetail? detail;
  final Map<String, String> fieldSample;
  final String? error;

  const BookInfoDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.initRule,
    required this.initMatched,
    required this.detail,
    required this.fieldSample,
    required this.error,
  });
}

class TocDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<TocItem> toc;
  final Map<String, String> fieldSample;
  final String? error;

  const TocDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.toc,
    required this.fieldSample,
    required this.error,
  });
}

class ContentDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final int extractedLength;
  final int cleanedLength;
  final String content;
  final String? error;

  const ContentDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.extractedLength,
    required this.cleanedLength,
    required this.content,
    required this.error,
  });
}

/// 搜索结果
class SearchResult {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String lastChapter;
  final String bookUrl;
  final String sourceUrl;
  final String sourceName;

  const SearchResult({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.lastChapter,
    required this.bookUrl,
    required this.sourceUrl,
    required this.sourceName,
  });
}

/// 书籍详情
class BookDetail {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String tocUrl;
  final String bookUrl;

  const BookDetail({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.kind,
    required this.lastChapter,
    required this.tocUrl,
    required this.bookUrl,
  });
}

/// 目录项
class TocItem {
  final int index;
  final String name;
  final String url;

  const TocItem({
    required this.index,
    required this.name,
    required this.url,
  });
}
