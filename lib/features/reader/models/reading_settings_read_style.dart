/// 阅读样式（对标 legado ReadBookConfig.Config 的样式卡片核心可见字段）
class ReadStyleConfig {
  final String name;
  final int backgroundColor;
  final int textColor;
  final int bgType;
  final String bgStr;
  final int bgAlpha;

  /// legado 删除样式时保留最少数量阈值
  static const int minEditableCount = 5;
  static const int legacyDefaultBackgroundColor = 0xFFEEEEEE;
  static const int legacyDefaultTextColor = 0xFF3E3D3B;
  static const int legacyDefaultBgAlpha = 100;
  static const int bgTypeColor = 0;
  static const int bgTypeAsset = 1;
  static const int bgTypeFile = 2;

  const ReadStyleConfig({
    this.name = '',
    this.backgroundColor = legacyDefaultBackgroundColor,
    this.textColor = legacyDefaultTextColor,
    this.bgType = bgTypeColor,
    this.bgStr = '',
    this.bgAlpha = legacyDefaultBgAlpha,
  });

  factory ReadStyleConfig.fromJson(Map<String, dynamic> json) {
    final parsedBgType = _parseInt(json['bgType'], fallback: bgTypeColor)
        .clamp(bgTypeColor, bgTypeFile)
        .toInt();
    final rawBgStr = _stringOrEmpty(json['bgStr']);

    final parsedTextColor = _parseColor(
      json.containsKey('textColor')
          ? json['textColor']
          : (json['textColorInt'] ?? json['fgColor'] ?? json['text']),
      legacyDefaultTextColor,
    );

    int parsedBackgroundColor = _parseColor(
      json.containsKey('backgroundColor')
          ? json['backgroundColor']
          : (json['bgColor'] ?? json['bg']),
      legacyDefaultBackgroundColor,
    );
    if (!json.containsKey('backgroundColor') &&
        !json.containsKey('bgColor') &&
        parsedBgType == bgTypeColor) {
      parsedBackgroundColor = _parseColor(
        rawBgStr,
        legacyDefaultBackgroundColor,
      );
    }

    return ReadStyleConfig(
      name: _stringOrEmpty(json['name']).trim(),
      backgroundColor: parsedBackgroundColor,
      textColor: parsedTextColor,
      bgType: parsedBgType,
      bgStr: rawBgStr,
      bgAlpha: _parseInt(json['bgAlpha'], fallback: legacyDefaultBgAlpha),
    ).sanitize();
  }

  Map<String, dynamic> toJson() {
    final safe = sanitize();
    return <String, dynamic>{
      'name': safe.name,
      'backgroundColor': safe.backgroundColor,
      'textColor': safe.textColor,
      'bgType': safe.bgType,
      'bgStr': safe.bgStr,
      'bgAlpha': safe.bgAlpha,
    };
  }

  ReadStyleConfig sanitize() {
    final safeName = name.trim();
    final safeTextColor =
        _normalizeColor(textColor, fallback: legacyDefaultTextColor);
    final safeBgAlpha = _parseInt(bgAlpha, fallback: legacyDefaultBgAlpha)
        .clamp(0, 100)
        .toInt();
    final safeBgType = _parseInt(bgType, fallback: bgTypeColor)
        .clamp(bgTypeColor, bgTypeFile)
        .toInt();
    final safeRawBgStr = bgStr.trim();
    var safeBackgroundColor = _normalizeColor(
      backgroundColor,
      fallback: legacyDefaultBackgroundColor,
    );

    if (safeBgType == bgTypeColor) {
      safeBackgroundColor = _parseColor(
        safeRawBgStr,
        safeBackgroundColor,
      );
      return ReadStyleConfig(
        name: safeName,
        backgroundColor: safeBackgroundColor,
        textColor: safeTextColor,
        bgType: bgTypeColor,
        bgStr: '#${_hexRgb(safeBackgroundColor)}',
        bgAlpha: safeBgAlpha,
      );
    }

    // bgTypeFile 允许 bgStr 为空（用户尚未选图），不强制回退到 bgTypeColor。
    // bgTypeAsset 若 bgStr 为空则回退，因为内置图片必须有文件名。
    if (safeRawBgStr.isEmpty && safeBgType != bgTypeFile) {
      return ReadStyleConfig(
        name: safeName,
        backgroundColor: safeBackgroundColor,
        textColor: safeTextColor,
        bgType: bgTypeColor,
        bgStr: '#${_hexRgb(safeBackgroundColor)}',
        bgAlpha: safeBgAlpha,
      );
    }

    return ReadStyleConfig(
      name: safeName,
      backgroundColor: safeBackgroundColor,
      textColor: safeTextColor,
      bgType: safeBgType,
      bgStr: safeRawBgStr,
      bgAlpha: safeBgAlpha,
    );
  }

  ReadStyleConfig copyWith({
    String? name,
    int? backgroundColor,
    int? textColor,
    int? bgType,
    String? bgStr,
    int? bgAlpha,
  }) {
    return ReadStyleConfig(
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      bgType: bgType ?? this.bgType,
      bgStr: bgStr ?? this.bgStr,
      bgAlpha: bgAlpha ?? this.bgAlpha,
    ).sanitize();
  }

  static String _stringOrEmpty(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    return '$raw'.trim();
  }

  static int _parseInt(dynamic raw, {required int fallback}) {
    if (raw is int) return raw;
    if (raw is num && raw.isFinite) return raw.toInt();
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return fallback;
      final parsed = int.tryParse(text);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static int _parseColor(dynamic raw, int fallback) {
    if (raw is int) {
      return _normalizeColor(raw, fallback: fallback);
    }
    if (raw is num && raw.isFinite) {
      return _normalizeColor(raw.toInt(), fallback: fallback);
    }
    if (raw is! String) {
      return fallback;
    }
    var text = raw.trim();
    if (text.isEmpty) {
      return fallback;
    }
    if (text.startsWith('#')) {
      text = text.substring(1);
    }
    if (text.startsWith('0x') || text.startsWith('0X')) {
      text = text.substring(2);
    }
    if (text.length == 6 || text.length == 8) {
      final parsed = int.tryParse(text, radix: 16);
      if (parsed == null) {
        return fallback;
      }
      return _normalizeColor(parsed, fallback: fallback);
    }
    final parsedInt = int.tryParse(text);
    if (parsedInt == null) {
      return fallback;
    }
    return _normalizeColor(parsedInt, fallback: fallback);
  }

  static String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  static int _normalizeColor(
    int raw, {
    required int fallback,
  }) {
    var value = raw;
    if (value < 0) {
      value = value & 0xFFFFFFFF;
    }
    if (value < 0 || value > 0xFFFFFFFF) {
      return fallback;
    }
    if ((value & 0xFF000000) == 0) {
      value = value | 0xFF000000;
    }
    return value;
  }
}

/// 内置背景图片列表（assets/bg/ 目录下的文件名）
const List<String> kBundledBgAssets = <String>[
  '护眼漫绿.jpg',
  '清新时光.jpg',
  '山水墨影.jpg',
  '深宫魅影.jpg',
  '午后沙滩.jpg',
  '宁静夜色.jpg',
  '新羊皮纸.jpg',
  '羊皮纸1.jpg',
  '山水画.jpg',
  '明媚倾城.jpg',
  '羊皮纸4.jpg',
  '羊皮纸2.jpg',
  '羊皮纸3.jpg',
  '边彩画布.jpg',
];

/// 6 个预设阅读样式（对标 legado defaultData/readConfig.json）
const List<ReadStyleConfig> kDefaultReadStyleConfigs = <ReadStyleConfig>[
  ReadStyleConfig(
    name: '白色',
    backgroundColor: 0xFFFFFFFF,
    textColor: 0xFF333333,
    bgType: ReadStyleConfig.bgTypeColor,
    bgStr: '#FFFFFF',
    bgAlpha: 100,
  ),
  ReadStyleConfig(
    name: '羊皮纸',
    backgroundColor: 0xFFFDF6E3,
    textColor: 0xFF5C4B3C,
    bgType: ReadStyleConfig.bgTypeColor,
    bgStr: '#FDF6E3',
    bgAlpha: 100,
  ),
  ReadStyleConfig(
    name: '护眼绿',
    backgroundColor: 0xFFCCE8CF,
    textColor: 0xFF3C4033,
    bgType: ReadStyleConfig.bgTypeColor,
    bgStr: '#CCE8CF',
    bgAlpha: 100,
  ),
  ReadStyleConfig(
    name: '淡紫',
    backgroundColor: 0xFFE8E0F0,
    textColor: 0xFF3A3050,
    bgType: ReadStyleConfig.bgTypeColor,
    bgStr: '#E8E0F0',
    bgAlpha: 100,
  ),
  ReadStyleConfig(
    name: '深色',
    backgroundColor: 0xFF1C1C1E,
    textColor: 0xFFD0D0D0,
    bgType: ReadStyleConfig.bgTypeColor,
    bgStr: '#1C1C1E',
    bgAlpha: 100,
  ),
  ReadStyleConfig(
    name: '微信',
    backgroundColor: 0xFFEAE2D4,
    textColor: 0xFF3E3128,
    bgType: ReadStyleConfig.bgTypeColor,
    bgStr: '#EAE2D4',
    bgAlpha: 100,
  ),
];
