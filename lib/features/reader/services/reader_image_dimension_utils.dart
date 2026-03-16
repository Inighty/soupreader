import 'dart:ui' show Size;

import 'reader_image_request_parser.dart';

/// Pure-function utilities for extracting image dimensions from HTML tags,
/// inline CSS styles, and image source URLs.
///
/// These were previously private methods inside `_SimpleReaderViewState`.
/// Extracting them enables unit testing and reuse.
class ReaderImageDimensionUtils {
  ReaderImageDimensionUtils._();

  static final RegExp _cssStyleAttrRegex = RegExp(
    r'''style\s*=\s*(?:"([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );

  // ── Query / URL keys for dimension extraction ──

  static const List<String> widthQueryKeys = [
    'w', 'width', 'imagewidth', 'image_width',
    'img_w', 'iw', 'resize_w', 'sw', 'swidth',
  ];

  static const List<String> heightQueryKeys = [
    'h', 'height', 'imageheight', 'image_height',
    'img_h', 'ih', 'resize_h', 'sh', 'sheight',
  ];

  static final List<RegExp> widthUrlPatterns = [
    RegExp(r'[/_](\d{2,5})x\d{2,5}(?=[._/])', caseSensitive: false),
    RegExp(r'[?&]w=(\d+)', caseSensitive: false),
  ];

  static final List<RegExp> heightUrlPatterns = [
    RegExp(r'[/_]\d{2,5}x(\d{2,5})(?=[._/])', caseSensitive: false),
    RegExp(r'[?&]h=(\d+)', caseSensitive: false),
  ];

  // ── Public API ──

  /// Extract width × height hints from an `<img>` tag's attributes and
  /// inline style.
  static Size? extractFromTag(String imgTag) {
    if (imgTag.isEmpty) return null;
    var width = _dimensionFromAttribute(imgTag, attribute: 'width') ??
        _dimensionFromInlineStyle(imgTag, property: 'width');
    var height = _dimensionFromAttribute(imgTag, attribute: 'height') ??
        _dimensionFromInlineStyle(imgTag, property: 'height');
    final aspectRatio = _aspectRatioFromInlineStyle(imgTag);
    if (aspectRatio != null) {
      if (width != null && height == null) {
        height = width / aspectRatio;
      } else if (height != null && width == null) {
        width = height * aspectRatio;
      }
    }
    if (width == null || height == null) return null;
    return Size(width, height);
  }

  /// Extract width × height hints from an image source URL's query
  /// parameters or path pattern.
  static Size? extractFromSrcUrl(String rawSrc) {
    final request = ReaderImageRequestParser.parse(rawSrc);
    final normalizedUrl = request.url.trim();
    if (normalizedUrl.isEmpty) return null;
    final uri = Uri.tryParse(normalizedUrl);
    final width = _dimensionFromUrl(
      uri: uri,
      url: normalizedUrl,
      queryKeys: widthQueryKeys,
      urlPatterns: widthUrlPatterns,
    );
    final height = _dimensionFromUrl(
      uri: uri,
      url: normalizedUrl,
      queryKeys: heightQueryKeys,
      urlPatterns: heightUrlPatterns,
    );
    if (width == null || height == null) return null;
    return Size(width, height);
  }

  /// Parse a CSS pixel value like `"300"`, `"300px"`.
  /// Returns `null` for percentages, empty strings, or invalid values.
  static double? parseCssPixelValue(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value.contains('%')) return null;
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)(px)?$').firstMatch(value);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }

  /// Parse a positive numeric dimension from arbitrary text.
  static double? parsePositiveDimension(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(raw.trim());
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }

  // ── Internals ──

  static double? _dimensionFromAttribute(
    String imgTag, {
    required String attribute,
  }) {
    final attrRegex = RegExp(
      '''$attribute\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))''',
      caseSensitive: false,
    );
    final match = attrRegex.firstMatch(imgTag);
    if (match == null) return null;
    final raw = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    return parseCssPixelValue(raw);
  }

  static double? _dimensionFromInlineStyle(
    String imgTag, {
    required String property,
  }) {
    final rawValue = _inlineStyleProperty(imgTag, property: property);
    if (rawValue == null) return null;
    return parseCssPixelValue(rawValue);
  }

  static double? _aspectRatioFromInlineStyle(String imgTag) {
    final rawValue = _inlineStyleProperty(imgTag, property: 'aspect-ratio');
    if (rawValue == null) return null;
    final value = rawValue.trim().toLowerCase();
    if (value.isEmpty || value == 'auto') return null;
    final ratioMatch =
        RegExp(r'^([0-9]+(?:\.[0-9]+)?)\s*/\s*([0-9]+(?:\.[0-9]+)?)$')
            .firstMatch(value);
    if (ratioMatch != null) {
      final num_ = double.tryParse(ratioMatch.group(1) ?? '');
      final den = double.tryParse(ratioMatch.group(2) ?? '');
      if (num_ == null ||
          den == null ||
          !num_.isFinite ||
          !den.isFinite ||
          num_ <= 0 ||
          den <= 0) {
        return null;
      }
      return num_ / den;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }

  static String? _inlineStyleProperty(
    String imgTag, {
    required String property,
  }) {
    final styleMatch = _cssStyleAttrRegex.firstMatch(imgTag);
    if (styleMatch == null) return null;
    final styleText =
        (styleMatch.group(1) ?? styleMatch.group(2) ?? '').trim();
    if (styleText.isEmpty) return null;
    final propertyRegex = RegExp(
      '''$property\\s*:\\s*([^;]+)''',
      caseSensitive: false,
    );
    final match = propertyRegex.firstMatch(styleText);
    return match?.group(1)?.trim();
  }

  static double? _dimensionFromUrl({
    required Uri? uri,
    required String url,
    required List<String> queryKeys,
    required List<RegExp> urlPatterns,
  }) {
    if (uri != null && uri.queryParameters.isNotEmpty) {
      final normalized = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        final k = key.trim().toLowerCase();
        final v = value.trim();
        if (k.isEmpty || v.isEmpty) return;
        normalized[k] = v;
      });
      for (final key in queryKeys) {
        final parsed = parsePositiveDimension(normalized[key.toLowerCase()]);
        if (parsed != null) return parsed;
      }
    }
    for (final pattern in urlPatterns) {
      final match = pattern.firstMatch(url);
      if (match == null) continue;
      final parsed = parsePositiveDimension(match.group(1));
      if (parsed != null) return parsed;
    }
    return null;
  }
}
