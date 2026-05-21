part of 'search_book_info_view.dart';

extension _SearchBookInfoErrorHelpers on SearchBookInfoViewState {
  String _compactReason(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  String _resolveShareErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'ERROR';

    const exceptionPrefix = 'Exception:';
    if (raw.startsWith(exceptionPrefix)) {
      final message = raw.substring(exceptionPrefix.length).trim();
      return message.isEmpty ? 'ERROR' : _compactReason(message);
    }

    const platformPrefix = 'PlatformException(';
    if (raw.startsWith(platformPrefix) && raw.endsWith(')')) {
      final body = raw.substring(platformPrefix.length, raw.length - 1);
      final segments = body.split(',');
      if (segments.length >= 2) {
        final message = segments[1].trim();
        if (message.isNotEmpty) return _compactReason(message);
      }
    }
    return _compactReason(raw);
  }
}
