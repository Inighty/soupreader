import '../../../core/database/database_service.dart';

class ReaderCharsetService {
  ReaderCharsetService({DatabaseService? database})
      : _database = database ?? DatabaseService();

  final DatabaseService _database;

  static const String defaultCharset = 'UTF-8';

  static const List<String> legacyCharsetOptions = <String>[
    'UTF-8',
    'GB2312',
    'GB18030',
    'GBK',
    'Unicode',
    'UTF-16',
    'UTF-16LE',
    'ASCII',
  ];

  static String? normalizeCharset(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final upper = value.toUpperCase().replaceAll('_', '-');
    switch (upper) {
      case 'UTF8':
      case 'UTF-8':
        return 'UTF-8';
      case 'GB2312':
        return 'GB2312';
      case 'GB18030':
        return 'GB18030';
      case 'GBK':
        return 'GBK';
      case 'UNICODE':
        return 'Unicode';
      case 'UTF16':
      case 'UTF-16':
        return 'UTF-16';
      case 'UTF16LE':
      case 'UTF-16LE':
        return 'UTF-16LE';
      case 'ASCII':
        return 'ASCII';
      default:
        return value;
    }
  }

  String? getBookCharset(String bookId) {
    final key = _buildSettingKey(bookId);
    final raw = _database.getSetting(key);
    return normalizeCharset(raw?.toString());
  }

  Future<void> setBookCharset(String bookId, String charset) async {
    final normalized = normalizeCharset(charset);
    final key = _buildSettingKey(bookId);
    if (normalized == null) {
      await _database.deleteSetting(key);
      return;
    }
    await _database.putSetting(key, normalized);
  }

  Future<void> clearBookCharset(String bookId) async {
    await _database.deleteSetting(_buildSettingKey(bookId));
  }

  String _buildSettingKey(String bookId) {
    return 'reader.book.charset.$bookId';
  }
}
