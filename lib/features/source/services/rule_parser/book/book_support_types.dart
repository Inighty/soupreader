import 'package:html/dom.dart';

import 'package:soupreader/features/source/services/rule_parser/core/selector_types.dart';

typedef RuleParserJsonDecoder = dynamic Function(String text);
typedef RuleParserValueOnNode = String Function(
  dynamic node,
  String? rule,
  String baseUrl,
);
typedef RuleParserStringListFromJson = List<String> Function({
  required dynamic json,
  required String rule,
  required String baseUrl,
  required bool isUrl,
});
typedef RuleParserStringListFromHtml = List<String> Function({
  required Element root,
  required String rule,
  required String baseUrl,
  required bool isUrl,
});
typedef RuleParserElementRule = String Function(
  Element element,
  String? rule,
  String baseUrl,
);
typedef RuleParserElementUrlRule = String Function(
  Element element,
  String? rule,
  String baseUrl,
);
typedef RuleParserElementUrlRawRule = String Function(
  Element element,
  String? rule,
  String baseUrl,
);
typedef RuleParserAbsoluteUrl = String Function(String baseUrl, String url);
typedef RuleParserSelectFirstElement = Element? Function(
  dynamic parent,
  String selectorRule,
);
typedef RuleParserLooksLikeJsonPath = bool Function(String rule);
typedef RuleParserSelectJsonList = List<dynamic> Function(
  dynamic json,
  String rawRule,
);
typedef RuleParserNormalizeListRule = NormalizedListRule Function(
  String? rawRule,
);
typedef RuleParserNormalizeRequestUrl = String Function(String requestUrl);
typedef RuleParserResolveTocUrl = String Function({
  required String rawValue,
  required String baseUrl,
});
typedef RuleParserSelectAllElementsByRule = List<Element> Function(
  dynamic parent,
  String selectorRule, {
  String? rawHtml,
});
typedef RuleParserSearchResultFilter = bool Function(String name, String author);
typedef RuleParserSearchResultShouldBreak = bool Function(int size);
typedef RuleParserDebugLogger = void Function(String msg);
