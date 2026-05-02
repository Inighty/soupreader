import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/book.dart';
import '../models/app_settings.dart';

import 'webdav_service_helpers.dart';
import 'webdav_service_models.dart';

export 'webdav_service_models.dart';

class WebDavService {
  WebDavService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 120),
                responseType: ResponseType.bytes,
                validateStatus: (_) => true,
              ),
            );

  final Dio _dio;

  static final RegExp _responseRegex = RegExp(
    r'<(?:\w+:)?response\b[\s\S]*?<\/(?:\w+:)?response>',
    caseSensitive: false,
  );

  static const String _propfindBody = '''<?xml version="1.0"?>
<a:propfind xmlns:a="DAV:">
  <a:prop>
    <a:displayname/>
    <a:resourcetype/>
    <a:getcontentlength/>
    <a:getlastmodified/>
    <a:creationdate/>
  </a:prop>
</a:propfind>''';

  bool hasValidConfig(AppSettings settings) {
    final account = settings.webDavAccount.trim();
    final password = settings.webDavPassword.trim();
    return account.isNotEmpty && password.isNotEmpty;
  }

  String buildRootUrl(AppSettings settings) {
    final rawUrl = settings.webDavUrl.trim().isEmpty
        ? AppSettings.defaultWebDavUrl
        : settings.webDavUrl.trim();
    var normalized = rawUrl;
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }

    var dir = settings.webDavDir.trim();
    if (dir.isEmpty) return normalized;
    dir = dir.replaceAll('\\', '/');
    dir = dir.replaceAll(RegExp(r'^/+'), '');
    dir = dir.replaceAll(RegExp(r'/+$'), '');
    if (dir.isEmpty) return normalized;
    return '$normalized$dir/';
  }

  String buildBooksRootUrl(AppSettings settings) {
    return '${buildRootUrl(settings)}books/';
  }

  String buildBookProgressRootUrl(AppSettings settings) {
    return '${buildRootUrl(settings)}bookProgress/';
  }

  String buildBookUploadUrl(
    AppSettings settings, {
    required String fileName,
  }) {
    final encodedName = Uri.encodeComponent(fileName.trim());
    return '${buildBooksRootUrl(settings)}$encodedName';
  }

  String buildBookProgressUrl(
    AppSettings settings, {
    required String bookTitle,
    required String bookAuthor,
  }) {
    final merged = '${bookTitle}_${bookAuthor}'.trim();
    final normalized =
        normalizeProgressFileNameSegment(merged.isEmpty ? 'unknown' : merged);
    final encodedName = Uri.encodeComponent(normalized);
    return '${buildBookProgressRootUrl(settings)}$encodedName.json';
  }

  Future<void> validateConfig(AppSettings settings) async {
    final rootUri = Uri.tryParse(buildRootUrl(settings));
    if (rootUri == null ||
        (rootUri.scheme != 'http' && rootUri.scheme != 'https')) {
      throw const WebDavOperationException('WebDav 地址无效，请使用 http/https');
    }
    if (!hasValidConfig(settings)) {
      throw const WebDavOperationException('请先配置 WebDav 账号和密码');
    }
  }

  Future<void> ensureUploadDirectories(AppSettings settings) async {
    await validateConfig(settings);
    final rootUri = Uri.parse(buildRootUrl(settings));
    final booksUri = Uri.parse(buildBooksRootUrl(settings));
    await _ensureDirectory(rootUri, settings);
    await _ensureDirectory(booksUri, settings);
  }

  Future<void> ensureProgressDirectories(AppSettings settings) async {
    await validateConfig(settings);
    final rootUri = Uri.parse(buildRootUrl(settings));
    final progressUri = Uri.parse(buildBookProgressRootUrl(settings));
    await _ensureDirectory(rootUri, settings);
    await _ensureDirectory(progressUri, settings);
  }

  Future<WebDavUploadResult> uploadLocalBook({
    required Book book,
    required AppSettings settings,
  }) async {
    if (!book.isLocal) {
      throw const WebDavOperationException('当前书籍不是本地书籍，无法上传');
    }

    final localPath = (book.localPath ?? '').trim();
    if (localPath.isEmpty) {
      throw const WebDavOperationException('本地文件路径缺失，无法上传');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw WebDavOperationException('本地文件不存在：$localPath');
    }

    await ensureUploadDirectories(settings);

    final fileName = p.basename(localPath);
    if (fileName.trim().isEmpty) {
      throw const WebDavOperationException('无法识别上传文件名');
    }

    final uploadUri = Uri.parse(
      buildBookUploadUrl(settings, fileName: fileName),
    );
    final bytes = await file.readAsBytes();
    final response = await _request(
      method: 'PUT',
      uri: uploadUri,
      settings: settings,
      data: bytes,
      extraHeaders: const <String, String>{
        'Content-Type': 'application/octet-stream',
      },
    );

    if (isSuccessStatus(response.statusCode)) {
      return WebDavUploadResult(remoteUrl: uploadUri.toString());
    }

    throw buildStatusException(
      action: '上传',
      uri: uploadUri,
      response: response,
    );
  }

  Future<void> uploadBookProgress({
    required WebDavBookProgress progress,
    required AppSettings settings,
  }) async {
    await ensureProgressDirectories(settings);
    final uploadUri = Uri.parse(
      buildBookProgressUrl(
        settings,
        bookTitle: progress.name,
        bookAuthor: progress.author,
      ),
    );
    final payload = utf8.encode(json.encode(progress.toJson()));
    final response = await _request(
      method: 'PUT',
      uri: uploadUri,
      settings: settings,
      data: payload,
      extraHeaders: const <String, String>{
        'Content-Type': 'application/json',
      },
    );
    if (isSuccessStatus(response.statusCode)) {
      return;
    }
    throw buildStatusException(
      action: '上传进度',
      uri: uploadUri,
      response: response,
    );
  }

  Future<WebDavBookProgress?> getBookProgress({
    required String bookTitle,
    required String bookAuthor,
    required AppSettings settings,
  }) async {
    await validateConfig(settings);
    final progressUri = Uri.parse(
      buildBookProgressUrl(
        settings,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
      ),
    );
    final response = await _request(
      method: 'GET',
      uri: progressUri,
      settings: settings,
    );
    final code = response.statusCode ?? 0;
    if (code == 404) {
      return null;
    }
    if (!isSuccessStatus(code)) {
      throw buildStatusException(
        action: '获取进度',
        uri: progressUri,
        response: response,
      );
    }
    final bytes = responseBytes(response.data);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final rawText = utf8.decode(bytes, allowMalformed: true).trim();
    if (rawText.isEmpty) {
      return null;
    }
    dynamic decoded;
    try {
      decoded = json.decode(rawText);
    } catch (_) {
      throw const WebDavOperationException('云端进度文件格式非法（非 JSON）');
    }
    if (decoded is! Map) {
      throw const WebDavOperationException('云端进度文件格式非法（非对象结构）');
    }
    final jsonMap = <String, dynamic>{};
    decoded.forEach((key, value) {
      jsonMap['$key'] = value;
    });
    return WebDavBookProgress.fromJson(jsonMap);
  }

  Future<List<WebDavRemoteEntry>> listDirectory({
    required AppSettings settings,
    String? directoryUrl,
  }) async {
    await validateConfig(settings);
    final requestedUrl = (directoryUrl ?? buildRootUrl(settings)).trim();
    final requestUri = Uri.tryParse(requestedUrl);
    if (requestUri == null ||
        (requestUri.scheme != 'http' && requestUri.scheme != 'https')) {
      throw const WebDavOperationException('WebDav 地址无效，请使用 http/https');
    }
    final response = await _request(
      method: 'PROPFIND',
      uri: requestUri,
      settings: settings,
      data: utf8.encode(_propfindBody),
      extraHeaders: const <String, String>{
        'Depth': '1',
        'Content-Type': 'text/xml; charset=utf-8',
      },
    );
    final code = response.statusCode ?? 0;
    if (!isSuccessStatus(code) && code != 207) {
      throw buildStatusException(
        action: '读取目录',
        uri: requestUri,
        response: response,
      );
    }
    final xml = utf8.decode(responseBytes(response.data) ?? const <int>[]);
    final entries = _parseDirectoryEntries(
      body: xml,
      requestUri: requestUri,
      currentDirectoryUrl: requestedUrl,
    );
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return b.lastModify.compareTo(a.lastModify);
    });
    return entries;
  }

  Future<List<WebDavRemoteEntry>> listBackupFiles({
    required AppSettings settings,
  }) async {
    final entries = await listDirectory(
      settings: settings,
      directoryUrl: buildRootUrl(settings),
    );
    final backups = entries.where((entry) {
      if (entry.isDirectory) return false;
      final name = entry.displayName.toLowerCase();
      return name.startsWith('backup') && name.endsWith('.json');
    }).toList(growable: false);
    backups.sort((a, b) => b.lastModify.compareTo(a.lastModify));
    return backups;
  }

  Future<String> uploadBackupBytes({
    required AppSettings settings,
    required String fileName,
    required List<int> bytes,
  }) async {
    await validateConfig(settings);
    final normalizedName = fileName.trim();
    if (normalizedName.isEmpty) {
      throw const WebDavOperationException('备份文件名为空');
    }
    final rootUri = Uri.parse(buildRootUrl(settings));
    await _ensureDirectory(rootUri, settings);
    final uploadUri = Uri.parse(
      '${buildRootUrl(settings)}${Uri.encodeComponent(normalizedName)}',
    );
    final response = await _request(
      method: 'PUT',
      uri: uploadUri,
      settings: settings,
      data: bytes,
      extraHeaders: const <String, String>{
        'Content-Type': 'application/json',
      },
    );
    if (isSuccessStatus(response.statusCode)) {
      return uploadUri.toString();
    }
    throw buildStatusException(
      action: '上传备份',
      uri: uploadUri,
      response: response,
    );
  }

  Future<List<int>> downloadFileBytes({
    required AppSettings settings,
    required String remoteUrl,
  }) async {
    await validateConfig(settings);
    final uri = Uri.tryParse(remoteUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const WebDavOperationException('备份文件地址无效');
    }
    final response = await _request(
      method: 'GET',
      uri: uri,
      settings: settings,
    );
    final code = response.statusCode ?? 0;
    if (!isSuccessStatus(code)) {
      throw buildStatusException(
        action: '下载备份',
        uri: uri,
        response: response,
      );
    }
    final bytes = responseBytes(response.data);
    if (bytes == null || bytes.isEmpty) {
      throw const WebDavOperationException('备份文件为空');
    }
    return bytes;
  }

  Future<void> _ensureDirectory(Uri uri, AppSettings settings) async {
    final response = await _request(
      method: 'MKCOL',
      uri: uri,
      settings: settings,
    );

    final code = response.statusCode ?? 0;
    if (code == 201 ||
        code == 200 ||
        code == 204 ||
        code == 301 ||
        code == 302 ||
        code == 405) {
      return;
    }

    throw buildStatusException(
      action: '创建远程目录',
      uri: uri,
      response: response,
    );
  }

  Future<Response<dynamic>> _request({
    required String method,
    required Uri uri,
    required AppSettings settings,
    Object? data,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      ...buildAuthHeaders(settings),
      if (extraHeaders != null) ...extraHeaders,
    };

    try {
      return await _dio.requestUri(
        uri,
        data: data,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );
    } on DioException catch (e) {
      throw WebDavOperationException(
          formatDioError(method: method, uri: uri, error: e));
    }
  }

  List<WebDavRemoteEntry> _parseDirectoryEntries({
    required String body,
    required Uri requestUri,
    required String currentDirectoryUrl,
  }) {
    final normalizedCurrent = normalizeUrl(currentDirectoryUrl);
    final entries = <WebDavRemoteEntry>[];
    for (final match in _responseRegex.allMatches(body)) {
      final responseXml = match.group(0) ?? '';
      if (responseXml.trim().isEmpty) continue;
      final href = extractTagText(responseXml, 'href');
      if (href.isEmpty) continue;
      final hrefDecoded = Uri.decodeFull(decodeXmlText(href));
      final fullUrl = resolveHref(requestUri, hrefDecoded);
      if (fullUrl == null) continue;
      final resourceType = extractTagInnerXml(responseXml, 'resourcetype');
      final contentType = extractTagText(responseXml, 'getcontenttype');
      final isDir = isDirectory(
        contentType: contentType,
        resourceTypeXml: resourceType,
      );
      final normalizedPath =
          isDir && !fullUrl.endsWith('/') ? '$fullUrl/' : fullUrl;
      if (normalizeUrl(normalizedPath) == normalizedCurrent) {
        continue;
      }
      final displayNameRaw = extractTagText(responseXml, 'displayname').trim();
      final fallbackName = extractFileName(hrefDecoded);
      final displayName = decodeXmlText(
        displayNameRaw.isEmpty ? fallbackName : displayNameRaw,
      );
      final size = int.tryParse(
            extractTagText(responseXml, 'getcontentlength').trim(),
          ) ??
          0;
      final lastModify =
          parseLastModify(extractTagText(responseXml, 'getlastmodified'));
      entries.add(
        WebDavRemoteEntry(
          displayName: displayName,
          path: normalizedPath,
          isDirectory: isDir,
          size: size,
          lastModify: lastModify,
        ),
      );
    }
    return entries;
  }

}
