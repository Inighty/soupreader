const Set<String> kSupportedImportExtensions = <String>{
  'txt',
  'epub',
};

String normalizeImportExtension(String extension) {
  final normalized = extension.trim().toLowerCase();
  if (normalized.startsWith('.')) {
    return normalized.substring(1);
  }
  return normalized;
}
