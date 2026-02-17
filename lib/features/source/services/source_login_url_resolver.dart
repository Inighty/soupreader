class SourceLoginUrlResolver {
  const SourceLoginUrlResolver._();

  static final RegExp _absUrlRegex = RegExp(
    r'^[a-z][a-z0-9+\-.]*://',
    caseSensitive: false,
  );

  static String resolve({
    required String baseUrl,
    required String loginUrl,
  }) {
    final relativePath = loginUrl.trim();
    if (relativePath.isEmpty) return '';
    final lower = relativePath.toLowerCase();
    if (_absUrlRegex.hasMatch(relativePath)) return relativePath;
    if (lower.startsWith('data:')) return relativePath;
    if (lower.startsWith('javascript')) return '';

    final baseTrimmed = baseUrl.trim();
    if (baseTrimmed.isEmpty) return relativePath;
    final baseCandidate = baseTrimmed.split(',').first.trim();
    if (baseCandidate.isEmpty) return relativePath;

    final baseUri = Uri.tryParse(baseCandidate);
    if (baseUri == null || !baseUri.hasScheme) return relativePath;
    try {
      return baseUri.resolve(relativePath).toString();
    } catch (_) {
      return relativePath;
    }
  }
}
