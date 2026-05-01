import 'package:soupreader/features/source/models/book_source.dart';

enum RuleParserDebugListMode { search, explore }

class SourceDebugEvent {
  final int state;
  final String message;
  final bool isRaw;

  const SourceDebugEvent({
    required this.state,
    required this.message,
    this.isRaw = false,
  });
}

enum DebugRequestType { search, explore, bookInfo, toc, content }

class ScriptHttpResponse {
  final String requestUrl;
  final String finalUrl;
  final int statusCode;
  final String statusMessage;
  final Map<String, String> headers;
  final String body;

  const ScriptHttpResponse({
    required this.requestUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.statusMessage,
    required this.headers,
    required this.body,
  });
}

class FetchDebugResult {
  final String requestUrl;
  final String? finalUrl;
  final int? statusCode;
  final int elapsedMs;
  final bool isRedirect;
  final String method;
  final String? requestBodySnippet;
  final String? responseCharset;
  final int responseLength;
  final String? responseSnippet;
  final Map<String, String> requestHeaders;
  final String? headersWarning;
  final Map<String, String> responseHeaders;
  final String? error;

  /// 实际重试次数（不含首发请求）。
  final int retryCount;

  /// method 的最终决策说明。
  final String methodDecision;

  /// retry 的配置与归一化决策说明。
  final String retryDecision;

  /// 请求参数编码决策（url query / form body）。
  final String requestCharsetDecision;

  /// 请求体编码类型：none/form/json/raw。
  final String bodyEncoding;

  /// 请求体编码策略说明。
  final String bodyDecision;

  /// 响应编码来源：urlOption.charset / header / meta / default。
  final String? responseCharsetSource;

  /// 响应编码判定与解码器决策说明。
  final String? responseCharsetDecision;

  /// 并发率限流累计等待时长（毫秒）。
  final int concurrentWaitMs;

  /// 并发率决策说明（对标 legado：间隔模式 / 窗口模式）。
  final String concurrentDecision;

  /// 原始响应体（仅用于编辑器调试；不要在普通 UI 中到处传递）
  final String? body;

  const FetchDebugResult({
    required this.requestUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.elapsedMs,
    this.isRedirect = false,
    this.method = 'GET',
    this.requestBodySnippet,
    this.responseCharset,
    required this.responseLength,
    required this.responseSnippet,
    required this.requestHeaders,
    required this.headersWarning,
    required this.responseHeaders,
    required this.error,
    this.retryCount = 0,
    this.methodDecision = '未解析',
    this.retryDecision = '未解析',
    this.requestCharsetDecision = '未解析',
    this.bodyEncoding = 'none',
    this.bodyDecision = '未解析',
    this.responseCharsetSource,
    this.responseCharsetDecision,
    this.concurrentWaitMs = 0,
    this.concurrentDecision = '未启用并发率限制',
    required this.body,
  });

  factory FetchDebugResult.empty() {
    return const FetchDebugResult(
      requestUrl: '',
      finalUrl: null,
      statusCode: null,
      elapsedMs: 0,
      isRedirect: false,
      method: 'GET',
      requestBodySnippet: null,
      responseCharset: null,
      responseLength: 0,
      responseSnippet: null,
      requestHeaders: {},
      headersWarning: null,
      responseHeaders: {},
      error: null,
      retryCount: 0,
      methodDecision: '未解析',
      retryDecision: '未解析',
      requestCharsetDecision: '未解析',
      bodyEncoding: 'none',
      bodyDecision: '未解析',
      responseCharsetSource: null,
      responseCharsetDecision: null,
      concurrentWaitMs: 0,
      concurrentDecision: '未启用并发率限制',
      body: null,
    );
  }
}

class ResolvedBookListRule {
  final BookListRule rule;
  final bool usedSearchRuleAsExploreFallback;

  const ResolvedBookListRule({
    required this.rule,
    required this.usedSearchRuleAsExploreFallback,
  });
}

class BookListAnalyzeOutcome {
  final List<SearchResult> results;
  final int listCount;
  final Map<String, String> fieldSample;
  final String? listRuleRaw;
  final bool usedInfoFallback;

  const BookListAnalyzeOutcome({
    required this.results,
    required this.listCount,
    required this.fieldSample,
    required this.listRuleRaw,
    required this.usedInfoFallback,
  });
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
  final String kind;
  final String lastChapter;
  final String updateTime;
  final String wordCount;
  final String bookUrl;
  final String sourceUrl;
  final String sourceName;

  const SearchResult({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    this.kind = '',
    required this.lastChapter,
    this.updateTime = '',
    this.wordCount = '',
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
  final String updateTime;
  final String wordCount;
  final String tocUrl;
  final String bookUrl;

  const BookDetail({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.kind,
    required this.lastChapter,
    this.updateTime = '',
    this.wordCount = '',
    required this.tocUrl,
    required this.bookUrl,
  });
}

/// 目录项
class TocItem {
  final int index;
  final String name;
  final String url;
  final bool isVolume;
  final bool isVip;
  final bool isPay;
  final String? tag;
  final String? wordCount;

  const TocItem({
    required this.index,
    required this.name,
    required this.url,
    this.isVolume = false,
    this.isVip = false,
    this.isPay = false,
    this.tag,
    this.wordCount,
  });
}
