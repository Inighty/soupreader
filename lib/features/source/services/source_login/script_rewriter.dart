class SourceLoginScriptRewriter {
  const SourceLoginScriptRewriter();

  String prepareScriptForAsyncNet(String script) {
    final connect = _awaitifyJavaCall(script, callToken: 'java.connect(');
    final ajax = _awaitifyJavaCall(connect.script, callToken: 'java.ajax(');
    if (!connect.changed && !ajax.changed) {
      return script;
    }
    return _markFunctionDeclarationsAsync(ajax.script);
  }

  _RewriteResult _awaitifyJavaCall(
    String script, {
    required String callToken,
  }) {
    final out = StringBuffer();
    var changed = false;
    var i = 0;
    var inSingle = false;
    var inDouble = false;
    var inTemplate = false;
    var inLineComment = false;
    var inBlockComment = false;

    while (i < script.length) {
      final char = script[i];
      final next = i + 1 < script.length ? script[i + 1] : '';

      if (inLineComment) {
        out.write(char);
        if (char == '\n') inLineComment = false;
        i += 1;
        continue;
      }
      if (inBlockComment) {
        out.write(char);
        if (char == '*' && next == '/') {
          out.write(next);
          i += 2;
          inBlockComment = false;
          continue;
        }
        i += 1;
        continue;
      }
      if (inSingle) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == "'") inSingle = false;
        i += 1;
        continue;
      }
      if (inDouble) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '"') inDouble = false;
        i += 1;
        continue;
      }
      if (inTemplate) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '`') inTemplate = false;
        i += 1;
        continue;
      }

      if (char == '/' && next == '/') {
        out.write(char);
        out.write(next);
        i += 2;
        inLineComment = true;
        continue;
      }
      if (char == '/' && next == '*') {
        out.write(char);
        out.write(next);
        i += 2;
        inBlockComment = true;
        continue;
      }
      if (char == "'") {
        out.write(char);
        inSingle = true;
        i += 1;
        continue;
      }
      if (char == '"') {
        out.write(char);
        inDouble = true;
        i += 1;
        continue;
      }
      if (char == '`') {
        out.write(char);
        inTemplate = true;
        i += 1;
        continue;
      }

      if (_startsWithToken(script, i, callToken) && !_hasAwaitBefore(script, i)) {
        final openParen = i + callToken.length - 1;
        final closeParen = _findMatchingParen(script, openParen);
        if (closeParen > openParen) {
          out.write('(await ');
          out.write(script.substring(i, closeParen + 1));
          out.write(')');
          changed = true;
          i = closeParen + 1;
          continue;
        }
      }

      out.write(char);
      i += 1;
    }

    return _RewriteResult(script: out.toString(), changed: changed);
  }

  String _markFunctionDeclarationsAsync(String script) {
    final out = StringBuffer();
    var i = 0;
    var inSingle = false;
    var inDouble = false;
    var inTemplate = false;
    var inLineComment = false;
    var inBlockComment = false;

    while (i < script.length) {
      final char = script[i];
      final next = i + 1 < script.length ? script[i + 1] : '';

      if (inLineComment) {
        out.write(char);
        if (char == '\n') inLineComment = false;
        i += 1;
        continue;
      }
      if (inBlockComment) {
        out.write(char);
        if (char == '*' && next == '/') {
          out.write(next);
          i += 2;
          inBlockComment = false;
          continue;
        }
        i += 1;
        continue;
      }
      if (inSingle) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == "'") inSingle = false;
        i += 1;
        continue;
      }
      if (inDouble) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '"') inDouble = false;
        i += 1;
        continue;
      }
      if (inTemplate) {
        out.write(char);
        if (char == '\\' && next.isNotEmpty) {
          out.write(next);
          i += 2;
          continue;
        }
        if (char == '`') inTemplate = false;
        i += 1;
        continue;
      }

      if (char == '/' && next == '/') {
        out.write(char);
        out.write(next);
        i += 2;
        inLineComment = true;
        continue;
      }
      if (char == '/' && next == '*') {
        out.write(char);
        out.write(next);
        i += 2;
        inBlockComment = true;
        continue;
      }
      if (char == "'") {
        out.write(char);
        inSingle = true;
        i += 1;
        continue;
      }
      if (char == '"') {
        out.write(char);
        inDouble = true;
        i += 1;
        continue;
      }
      if (char == '`') {
        out.write(char);
        inTemplate = true;
        i += 1;
        continue;
      }

      if (_startsWithToken(script, i, 'function') &&
          !_hasAsyncBefore(script, i) &&
          _isFunctionTail(script, i + 'function'.length)) {
        out.write('async ');
      }
      out.write(char);
      i += 1;
    }
    return out.toString();
  }

  int _findMatchingParen(String text, int openIndex) {
    if (openIndex < 0 || openIndex >= text.length || text[openIndex] != '(') {
      return -1;
    }
    var depth = 0;
    var inSingle = false;
    var inDouble = false;
    var inTemplate = false;
    var inLineComment = false;
    var inBlockComment = false;

    for (var i = openIndex; i < text.length; i += 1) {
      final char = text[i];
      final next = i + 1 < text.length ? text[i + 1] : '';

      if (inLineComment) {
        if (char == '\n') inLineComment = false;
        continue;
      }
      if (inBlockComment) {
        if (char == '*' && next == '/') {
          inBlockComment = false;
          i += 1;
        }
        continue;
      }
      if (inSingle) {
        if (char == '\\' && next.isNotEmpty) {
          i += 1;
          continue;
        }
        if (char == "'") inSingle = false;
        continue;
      }
      if (inDouble) {
        if (char == '\\' && next.isNotEmpty) {
          i += 1;
          continue;
        }
        if (char == '"') inDouble = false;
        continue;
      }
      if (inTemplate) {
        if (char == '\\' && next.isNotEmpty) {
          i += 1;
          continue;
        }
        if (char == '`') inTemplate = false;
        continue;
      }

      if (char == '/' && next == '/') {
        inLineComment = true;
        i += 1;
        continue;
      }
      if (char == '/' && next == '*') {
        inBlockComment = true;
        i += 1;
        continue;
      }
      if (char == "'") {
        inSingle = true;
        continue;
      }
      if (char == '"') {
        inDouble = true;
        continue;
      }
      if (char == '`') {
        inTemplate = true;
        continue;
      }

      if (char == '(') {
        depth += 1;
        continue;
      }
      if (char == ')') {
        depth -= 1;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  bool _startsWithToken(String text, int index, String token) {
    if (index < 0 || index + token.length > text.length) {
      return false;
    }
    if (text.substring(index, index + token.length) != token) {
      return false;
    }
    if (index > 0 && _isIdentifierChar(text.codeUnitAt(index - 1))) {
      return false;
    }
    return true;
  }

  bool _isFunctionTail(String text, int index) {
    if (index >= text.length) return true;
    final char = text[index];
    return char == '(' ||
        char == ' ' ||
        char == '\n' ||
        char == '\t' ||
        char == '\r';
  }

  bool _hasAsyncBefore(String text, int functionIndex) {
    var i = functionIndex - 1;
    while (i >= 0) {
      final char = text[i];
      if (char == ' ' || char == '\n' || char == '\t' || char == '\r') {
        i -= 1;
        continue;
      }
      break;
    }
    if (i < 4) return false;
    final start = i - 4;
    if (text.substring(start, i + 1) != 'async') {
      return false;
    }
    if (start > 0 && _isIdentifierChar(text.codeUnitAt(start - 1))) {
      return false;
    }
    return true;
  }

  bool _hasAwaitBefore(String text, int callIndex) {
    var i = callIndex - 1;
    while (i >= 0) {
      final char = text[i];
      if (char == ' ' || char == '\n' || char == '\t' || char == '\r') {
        i -= 1;
        continue;
      }
      break;
    }
    if (i < 4) return false;
    final start = i - 4;
    if (text.substring(start, i + 1) != 'await') {
      return false;
    }
    if (start > 0 && _isIdentifierChar(text.codeUnitAt(start - 1))) {
      return false;
    }
    return true;
  }

  bool _isIdentifierChar(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 95 ||
        codeUnit == 36;
  }
}

class _RewriteResult {
  const _RewriteResult({
    required this.script,
    required this.changed,
  });

  final String script;
  final bool changed;
}
