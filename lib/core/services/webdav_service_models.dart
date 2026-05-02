class WebDavOperationException implements Exception {
  final String message;

  const WebDavOperationException(this.message);

  @override
  String toString() => message;
}

class WebDavUploadResult {
  final String remoteUrl;

  const WebDavUploadResult({required this.remoteUrl});
}

class WebDavRemoteEntry {
  final String displayName;
  final String path;
  final bool isDirectory;
  final int size;
  final int lastModify;

  const WebDavRemoteEntry({
    required this.displayName,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.lastModify,
  });
}

/// 与 legado `BookProgress` 字段保持兼容，并补充 soupreader 侧进度字段。
class WebDavBookProgress {
  final String name;
  final String author;
  final int durChapterIndex;
  final int durChapterPos;
  final int durChapterTime;
  final String? durChapterTitle;
  final double? chapterProgress;
  final double? readProgress;
  final int? totalChapters;

  const WebDavBookProgress({
    required this.name,
    required this.author,
    required this.durChapterIndex,
    required this.durChapterPos,
    required this.durChapterTime,
    this.durChapterTitle,
    this.chapterProgress,
    this.readProgress,
    this.totalChapters,
  });

  factory WebDavBookProgress.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw, {int fallback = 0}) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      if (raw is double) return raw;
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw.trim());
      return null;
    }

    String parseString(dynamic raw, {String fallback = ''}) {
      if (raw == null) return fallback;
      return raw.toString().trim();
    }

    final normalizedChapterProgress =
        parseDouble(json['chapterProgress'])?.clamp(0.0, 1.0).toDouble();
    final normalizedReadProgress =
        parseDouble(json['readProgress'])?.clamp(0.0, 1.0).toDouble();

    return WebDavBookProgress(
      name: parseString(json['name']),
      author: parseString(json['author']),
      durChapterIndex: parseInt(json['durChapterIndex']),
      durChapterPos: parseInt(json['durChapterPos']),
      durChapterTime: parseInt(json['durChapterTime']),
      durChapterTitle: parseString(json['durChapterTitle']).isEmpty
          ? null
          : parseString(json['durChapterTitle']),
      chapterProgress: normalizedChapterProgress,
      readProgress: normalizedReadProgress,
      totalChapters: json.containsKey('totalChapters')
          ? parseInt(json['totalChapters'], fallback: 0)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'author': author,
      'durChapterIndex': durChapterIndex,
      'durChapterPos': durChapterPos,
      'durChapterTime': durChapterTime,
      'durChapterTitle': durChapterTitle,
      if (chapterProgress != null)
        'chapterProgress': chapterProgress!.clamp(0.0, 1.0).toDouble(),
      if (readProgress != null)
        'readProgress': readProgress!.clamp(0.0, 1.0).toDouble(),
      if (totalChapters != null) 'totalChapters': totalChapters,
    };
  }
}
