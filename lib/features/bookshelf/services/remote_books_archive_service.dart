import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';

/// 压缩包内部可导入候选条目。
class RemoteBooksArchiveCandidate {
  final String fileName;
  final int sizeInBytes;
  final String extension;

  const RemoteBooksArchiveCandidate({
    required this.fileName,
    required this.sizeInBytes,
    required this.extension,
  });
}

/// 下载 + 解析压缩包后的结果（用于 UI 决策：提示/选择/继续导入）。
class RemoteBooksArchiveOpenResult {
  final bool success;
  final bool fromCache;
  final String? localArchivePath;
  final List<RemoteBooksArchiveCandidate> candidates;
  final String? warning;
  final String? errorMessage;

  const RemoteBooksArchiveOpenResult({
    required this.success,
    required this.fromCache,
    required this.localArchivePath,
    required this.candidates,
    this.warning,
    this.errorMessage,
  });

  factory RemoteBooksArchiveOpenResult.ok({
    required bool fromCache,
    required String localArchivePath,
    required List<RemoteBooksArchiveCandidate> candidates,
    String? warning,
  }) {
    return RemoteBooksArchiveOpenResult(
      success: true,
      fromCache: fromCache,
      localArchivePath: localArchivePath,
      candidates: candidates,
      warning: warning,
    );
  }

  factory RemoteBooksArchiveOpenResult.error(String message) {
    return RemoteBooksArchiveOpenResult(
      success: false,
      fromCache: false,
      localArchivePath: null,
      candidates: const <RemoteBooksArchiveCandidate>[],
      errorMessage: message,
    );
  }
}

/// RemoteBooks 压缩包下载与解析服务：
/// - 对齐 legado `RemoteBookActivity.startRead` + `BaseImportBookActivity.onArchiveFileClick` 的核心语义；
/// - 负责：远程下载 -> 本地缓存 -> 枚举压缩包内可导入条目；
/// - 解析实现当前优先使用 `package:archive`（仅支持 zip）。
class RemoteBooksArchiveService {
  RemoteBooksArchiveService({
    Dio? dio,
    ExceptionLogService? exceptionLogService,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 90),
                sendTimeout: const Duration(seconds: 60),
                responseType: ResponseType.bytes,
                validateStatus: (_) => true,
              ),
            ),
        _exceptionLogService = exceptionLogService ?? ExceptionLogService();

  final Dio _dio;
  final ExceptionLogService _exceptionLogService;

  /// 当前 SoupReader 可导入的书籍格式（与 ImportService 对齐）。
  static const Set<String> supportedBookExtensions = <String>{
    'txt',
    'epub',
  };

  /// legado 压缩包内“书籍文件”候选格式（用于给出明确的“差异提示”）。
  static const Set<String> _legacyBookExtensions = <String>{
    'txt',
    'epub',
    'umd',
    'pdf',
    'mobi',
    'azw3',
    'azw',
  };

  static final RegExp _archiveFileRegex = RegExp(
    r'.*\.(zip|rar|7z)$',
    caseSensitive: false,
  );

  bool isArchiveFileName(String fileName) {
    return _archiveFileRegex.hasMatch(fileName.trim());
  }

  /// 解析/下载前：解析出“稳定缓存路径”，用于 UI 判断本地是否已有缓存文件。
  Future<String> resolveCachedArchivePath({
    required String remoteUrl,
    required String fileName,
  }) async {
    final directory = await _ensureArchiveDirectory();
    final safeName = _sanitizeFileName(fileName);
    final hash = _fnv1aHex(remoteUrl);
    final ext = p.extension(safeName);
    final base = p.basenameWithoutExtension(safeName);
    final cachedName = ext.isEmpty ? '${base}__$hash' : '${base}__$hash$ext';
    return p.join(directory.path, cachedName);
  }

  /// 打开远程压缩包：
  /// - 若本地已有缓存：直接解析；
  /// - 若本地无缓存：allowDownload=true 时会下载后解析；否则返回错误提示（用于 UI 先弹窗确认）。
  Future<RemoteBooksArchiveOpenResult> openRemoteArchive({
    required AppSettings settings,
    required String remoteUrl,
    required String fileName,
    bool allowDownload = true,
    Set<String> allowedBookExtensions = supportedBookExtensions,
  }) async {
    final uri = Uri.tryParse(remoteUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return RemoteBooksArchiveOpenResult.error('远程地址无效，请检查 WebDav 列表返回的链接');
    }

    final cachedPath = await resolveCachedArchivePath(
      remoteUrl: remoteUrl,
      fileName: fileName,
    );
    final cachedFile = File(cachedPath);
    final exists = await cachedFile.exists();
    if (!exists) {
      if (!allowDownload) {
        return RemoteBooksArchiveOpenResult.error(
          '本地未找到该压缩包缓存，请先下载后再打开',
        );
      }
      try {
        await downloadArchiveToCache(
          settings: settings,
          remoteUrl: remoteUrl,
          fileName: fileName,
          targetPath: cachedPath,
        );
      } catch (error, stackTrace) {
        _exceptionLogService.record(
          node: 'remote_books.archive.download.failed',
          message: '下载远程压缩包失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'remoteUrl': remoteUrl,
            'fileName': fileName,
            'targetPath': cachedPath,
          },
        );
        return RemoteBooksArchiveOpenResult.error(
          '下载失败：${_compactReason(error.toString())}',
        );
      }
    }

    final parsed = await parseLocalArchive(
      localArchivePath: cachedPath,
      allowedBookExtensions: allowedBookExtensions,
    );
    if (!parsed.success) return parsed;

    return RemoteBooksArchiveOpenResult.ok(
      fromCache: exists,
      localArchivePath: cachedPath,
      candidates: parsed.candidates,
      warning: parsed.warning,
    );
  }

  /// 仅解析本地压缩包文件，返回可导入条目列表（不会触发网络下载）。
  Future<RemoteBooksArchiveOpenResult> parseLocalArchive({
    required String localArchivePath,
    Set<String> allowedBookExtensions = supportedBookExtensions,
  }) async {
    final path = localArchivePath.trim();
    if (path.isEmpty) {
      return RemoteBooksArchiveOpenResult.error('压缩包路径为空');
    }
    final file = File(path);
    if (!await file.exists()) {
      return RemoteBooksArchiveOpenResult.error('压缩包文件不存在');
    }

    final ext = _normalizeExtension(p.extension(path));
    if (ext != 'zip') {
      // 说明：legado 支持 zip/rar/7z，但当前 Flutter 侧暂仅实现 zip 解析。
      if (ext == 'rar' || ext == '7z') {
        return RemoteBooksArchiveOpenResult.error(
          '当前版本暂不支持解析 .$ext 压缩包（仅支持 zip），请在电脑解压后导入其中的 txt/epub 文件',
        );
      }
      return RemoteBooksArchiveOpenResult.error('不支持的压缩格式：$ext');
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return RemoteBooksArchiveOpenResult.error('压缩包内容为空');
      }

      final archive = ZipDecoder().decodeBytes(bytes, verify: true);

      final candidatesByKey = <String, RemoteBooksArchiveCandidate>{};
      final unsupportedLegacyExts = <String>{};

      for (final archiveFile in archive.files) {
        if (!archiveFile.isFile) continue;
        final name = archiveFile.name.trim();
        if (name.isEmpty) continue;

        // 对齐 legado：使用“文件名”作为候选展示与导入锚点（不包含目录层级）。
        final baseName = p.basename(name);
        if (baseName.trim().isEmpty) continue;

        final entryExt = _normalizeExtension(p.extension(baseName));
        if (entryExt.isEmpty) continue;

        if (_legacyBookExtensions.contains(entryExt) &&
            !allowedBookExtensions.contains(entryExt)) {
          unsupportedLegacyExts.add(entryExt);
        }

        if (!allowedBookExtensions.contains(entryExt)) continue;

        final key = baseName.toLowerCase();
        candidatesByKey.putIfAbsent(
          key,
          () => RemoteBooksArchiveCandidate(
            fileName: baseName,
            sizeInBytes: archiveFile.size,
            extension: entryExt,
          ),
        );
      }

      final candidates = candidatesByKey.values.toList(growable: false)
        ..sort((a, b) => a.fileName.compareTo(b.fileName));

      String? warning;
      if (unsupportedLegacyExts.isNotEmpty) {
        final list = unsupportedLegacyExts.toList()..sort();
        warning = '压缩包内包含暂不支持的格式（${list.join('/')}），已忽略，仅展示可导入的 txt/epub。';
      }

      return RemoteBooksArchiveOpenResult.ok(
        fromCache: true,
        localArchivePath: path,
        candidates: candidates,
        warning: warning,
      );
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive.parse.failed',
        message: '解析压缩包失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'localArchivePath': path,
        },
      );
      return RemoteBooksArchiveOpenResult.error(
        '解析失败：${_compactReason(error.toString())}',
      );
    }
  }

  /// 下载压缩包到指定缓存路径（支持断点/重试由上层决定；此处保持最小语义）。
  Future<void> downloadArchiveToCache({
    required AppSettings settings,
    required String remoteUrl,
    required String fileName,
    required String targetPath,
  }) async {
    final uri = Uri.tryParse(remoteUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw Exception('远程地址无效，请检查 WebDav 列表返回的链接');
    }

    if (_sanitizeFileName(fileName).isEmpty) {
      throw Exception('无法识别下载文件名');
    }

    final targetFile = File(targetPath);
    final tempPath = '$targetPath.download';
    final parentDir = Directory(p.dirname(targetPath));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final response = await _dio.request<dynamic>(
      uri.toString(),
      options: Options(
        method: 'GET',
        headers: _buildAuthHeaders(settings),
        responseType: ResponseType.bytes,
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );

    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) {
      throw Exception(_formatDownloadHttpError(code));
    }

    final bytes = _responseBytes(response.data);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('下载内容为空');
    }

    await _atomicWriteBytes(
      targetFile: targetFile,
      tempPath: tempPath,
      bytes: bytes,
    );
  }

  /// 从 zip 压缩包中提取指定条目到本地文件，并返回提取后的路径。
  ///
  /// 注意：此处只负责“提取”，不做 ImportService 的导入；导入由上层服务协调，
  /// 以便复用现有导入聚合/错误提示逻辑。
  Future<String> extractZipEntryToLocalFile({
    required String localArchivePath,
    required String entryFileName,
  }) async {
    final archivePath = localArchivePath.trim();
    final name = entryFileName.trim();
    if (archivePath.isEmpty || name.isEmpty) {
      throw Exception('提取参数无效');
    }

    final file = File(archivePath);
    if (!await file.exists()) {
      throw Exception('压缩包文件不存在');
    }

    final ext = _normalizeExtension(p.extension(archivePath));
    if (ext != 'zip') {
      throw Exception('仅支持从 zip 提取条目');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final target = _findArchiveFileByBaseName(archive, name);
    if (target == null) {
      throw Exception('未找到压缩包条目：$name');
    }

    final payload = _archiveFileBytes(target);
    if (payload == null || payload.isEmpty) {
      throw Exception('压缩包条目内容为空：$name');
    }

    final outDir = await _ensureArchiveEntryDirectory(
      archiveKey: _fnv1aHex(archivePath),
    );
    final safeName = _sanitizeFileName(name);
    final outputPath = p.join(outDir.path, safeName);
    final tempPath = '$outputPath.extracting';
    await _atomicWriteBytes(
      targetFile: File(outputPath),
      tempPath: tempPath,
      bytes: payload,
    );
    return outputPath;
  }

  Future<Directory> _ensureArchiveDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(docs.path, '.remote_books', 'archives'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    if (!await target.exists()) {
      throw Exception('创建本地压缩包缓存目录失败');
    }
    return target;
  }

  Future<Directory> _ensureArchiveEntryDirectory({
    required String archiveKey,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final target = Directory(
      p.join(docs.path, '.remote_books', 'archive_entries', archiveKey),
    );
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    if (!await target.exists()) {
      throw Exception('创建本地压缩包条目缓存目录失败');
    }
    return target;
  }

  Map<String, String> _buildAuthHeaders(AppSettings settings) {
    final account = settings.webDavAccount.trim();
    final password = settings.webDavPassword.trim();
    final payload = base64Encode(utf8.encode('$account:$password'));
    return <String, String>{
      'Authorization': 'Basic $payload',
    };
  }

  String _formatDownloadHttpError(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return '无权限（HTTP $statusCode），请检查 WebDav 账号密码';
      case 404:
        return '文件不存在（HTTP 404）';
      default:
        return 'HTTP $statusCode';
    }
  }

  List<int>? _responseBytes(dynamic raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return raw;
    return null;
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final ext = p.extension(trimmed);
    final name = p.basenameWithoutExtension(trimmed);
    final normalizedName = name
        .replaceAll(RegExp(r'[\\\\/\\u0000-\\u001F]'), '_')
        .replaceAll(RegExp(r'[:*?\"<>|]'), '_')
        .trim();
    final normalizedExt = ext
        .replaceAll(RegExp(r'[\\\\/\\u0000-\\u001F]'), '')
        .replaceAll(RegExp(r'[:*?\"<>|]'), '')
        .trim();
    final safeName = normalizedName.isEmpty ? 'remote_archive' : normalizedName;
    final safeExt = normalizedExt.toLowerCase();
    return safeExt.isEmpty ? safeName : '$safeName$safeExt';
  }

  String _normalizeExtension(String rawExtension) {
    var ext = rawExtension.trim().toLowerCase();
    if (ext.startsWith('.')) ext = ext.substring(1);
    return ext;
  }

  Future<void> _atomicWriteBytes({
    required File targetFile,
    required String tempPath,
    required List<int> bytes,
  }) async {
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await _tryDeleteFile(tempFile);
    }

    await tempFile.writeAsBytes(bytes, flush: true);

    if (await targetFile.exists()) {
      await _tryDeleteFile(targetFile);
    }

    await tempFile.rename(targetFile.path);
  }

  Future<void> _tryDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'remote_books.archive.cleanup.failed',
        message: '清理远程书籍压缩包临时文件失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'filePath': file.path,
        },
      );
    }
  }

  ArchiveFile? _findArchiveFileByBaseName(Archive archive, String fileName) {
    final normalized = fileName.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final base = p.basename(file.name).trim().toLowerCase();
      if (base == normalized) return file;
    }
    return null;
  }

  Uint8List? _archiveFileBytes(ArchiveFile file) {
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    if (content is String) return Uint8List.fromList(utf8.encode(content));
    return null;
  }

  String _compactReason(String text, {int maxLength = 120}) {
    final normalized = text.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  /// 生成短 hash（用于避免不同目录同名压缩包缓存互相覆盖）。
  ///
  /// 使用 FNV-1a 32-bit，避免引入额外依赖。
  String _fnv1aHex(String input) {
    const int fnvOffsetBasis = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    var hash = fnvOffsetBasis;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
