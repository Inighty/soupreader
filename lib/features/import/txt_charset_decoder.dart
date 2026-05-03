import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

/// TXT 解码后的内容与识别出的字符集。
class TxtDecodedContent {
  final String content;
  final String charset;

  const TxtDecodedContent({
    required this.content,
    required this.charset,
  });
}

/// 自动检测编码并解码 TXT 字节流。
///
/// 优先级：BOM → UTF-8 → GBK（中文 TXT 常见）→ UTF-8 容错。
TxtDecodedContent decodeTxtContent(
  Uint8List bytes, {
  String? forcedCharset,
}) {
  if (bytes.isEmpty) {
    return const TxtDecodedContent(
      content: '',
      charset: 'UTF-8',
    );
  }

  final normalizedForced = normalizeForcedCharset(forcedCharset);
  if (normalizedForced != null) {
    return decodeContentByCharset(bytes, normalizedForced);
  }

  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return TxtDecodedContent(
      content: utf8.decode(bytes.sublist(3), allowMalformed: true),
      charset: 'UTF-8',
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return TxtDecodedContent(
      content: decodeUtf16(bytes.sublist(2), littleEndian: true),
      charset: 'UTF-16LE',
    );
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return TxtDecodedContent(
      content: decodeUtf16(bytes.sublist(2), littleEndian: false),
      charset: 'UTF-16',
    );
  }

  // 优先 UTF-8（对标 legado）
  try {
    return TxtDecodedContent(
      content: utf8.decode(bytes, allowMalformed: false),
      charset: 'UTF-8',
    );
  } catch (_) {}

  // 非 UTF-8 时优先按 GBK 解码
  try {
    return TxtDecodedContent(
      content: gbk.decode(bytes, allowMalformed: true),
      charset: 'GBK',
    );
  } catch (_) {}

  return TxtDecodedContent(
    content: utf8.decode(bytes, allowMalformed: true),
    charset: 'UTF-8',
  );
}

String? normalizeForcedCharset(String? raw) {
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

TxtDecodedContent decodeContentByCharset(Uint8List bytes, String charset) {
  try {
    final upper = charset.toUpperCase();
    switch (upper) {
      case 'UTF-8':
        final noBom = _trimUtf8Bom(bytes);
        return TxtDecodedContent(
          content: utf8.decode(noBom, allowMalformed: true),
          charset: 'UTF-8',
        );
      case 'GB2312':
      case 'GB18030':
      case 'GBK':
        return TxtDecodedContent(
          content: gbk.decode(bytes, allowMalformed: true),
          charset: upper,
        );
      case 'UNICODE':
      case 'UTF-16':
        if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
          return TxtDecodedContent(
            content: decodeUtf16(bytes.sublist(2), littleEndian: true),
            charset: 'UTF-16LE',
          );
        }
        if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
          return TxtDecodedContent(
            content: decodeUtf16(bytes.sublist(2), littleEndian: false),
            charset: 'UTF-16',
          );
        }
        return TxtDecodedContent(
          content: decodeUtf16(bytes, littleEndian: true),
          charset: 'UTF-16',
        );
      case 'UTF-16LE':
        if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
          return TxtDecodedContent(
            content: decodeUtf16(bytes.sublist(2), littleEndian: true),
            charset: 'UTF-16LE',
          );
        }
        return TxtDecodedContent(
          content: decodeUtf16(bytes, littleEndian: true),
          charset: 'UTF-16LE',
        );
      case 'ASCII':
        return TxtDecodedContent(
          content: ascii.decode(bytes, allowInvalid: true),
          charset: 'ASCII',
        );
      default:
        return TxtDecodedContent(
          content: utf8.decode(bytes, allowMalformed: true),
          charset: charset,
        );
    }
  } catch (_) {
    return TxtDecodedContent(
      content: utf8.decode(bytes, allowMalformed: true),
      charset: charset,
    );
  }
}

Uint8List _trimUtf8Bom(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return bytes.sublist(3);
  }
  return bytes;
}

String decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final length = bytes.length;
  if (length < 2) return '';
  final evenLength = length - (length % 2);
  final data = ByteData.sublistView(bytes, 0, evenLength);
  final codeUnits = Uint16List(evenLength ~/ 2);
  final endian = littleEndian ? Endian.little : Endian.big;
  for (var i = 0; i < codeUnits.length; i++) {
    codeUnits[i] = data.getUint16(i * 2, endian);
  }
  return String.fromCharCodes(codeUnits);
}
