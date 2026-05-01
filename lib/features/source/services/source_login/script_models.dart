import 'package:soupreader/features/source/services/rule_parser/rule_parser_engine.dart';
import 'package:soupreader/features/source/models/book_source.dart';

typedef SourceLoginScriptRequestExecutor = Future<ScriptHttpResponse> Function({
  required BookSource source,
  required String requestUrl,
  Map<String, String>? headerOverride,
});

class SourceLoginScriptResult {
  const SourceLoginScriptResult({
    required this.success,
    required this.executed,
    required this.message,
  });

  final bool success;
  final bool executed;
  final String message;
}
