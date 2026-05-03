import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/build/build_info.dart';
import '../../../core/services/exception_log_service.dart';
import 'about_app_update_dialog.dart';

/// 远端发布的更新信息（解析自 GitHub Action 的 `latest` 接口）。
class AppUpdateInfo {
  final String tagName;
  final String updateBody;
  final String downloadUrl;
  final String fileName;

  const AppUpdateInfo({
    required this.tagName,
    required this.updateBody,
    required this.downloadUrl,
    required this.fileName,
  });
}

const String _latestEndpoint =
    'https://github-action-cf.mcshr.workers.dev/latest';

/// 检查更新并按情况展示对应 Dialog（已是最新 / 错误 / 弹出更新说明）。
Future<void> checkAppUpdateAndPrompt({
  required BuildContext context,
  required ExceptionLogService exceptionLogService,
  required String version,
  required Future<void> Function(String message) showMessage,
  required VoidCallback dismissLoading,
}) async {
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CupertinoActivityIndicator()),
  );

  AppUpdateInfo? updateInfo;
  String? errorMessage;
  var alreadyLatest = false;

  try {
    final response = await Dio().get(_latestEndpoint);
    if (response.statusCode != 200) {
      errorMessage = '检查更新失败：HTTP ${response.statusCode ?? '-'}';
    } else {
      final parsed = parseAppUpdateInfo(response.data);
      if (parsed == null) {
        errorMessage = '检查更新失败：响应解析失败';
      } else if (parsed.downloadUrl.trim().isEmpty) {
        errorMessage = '检查更新失败：未找到安装包';
      } else if (parsed.updateBody.trim().isEmpty) {
        errorMessage = '检查更新失败：更新说明为空';
      } else if (_isAlreadyLatest(parsed)) {
        alreadyLatest = true;
      } else {
        updateInfo = parsed;
      }
    }
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'app_update.check_update',
      message: '检查更新失败',
      error: error,
      stackTrace: stackTrace,
    );
    errorMessage = '检查更新失败：${summarizeError(error)}';
  }

  dismissLoading();
  if (!context.mounted) return;

  if (updateInfo != null) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AppUpdateDialog(
        updateInfo: updateInfo!,
        onDownload: () => handleAppUpdateDownload(
          context: context,
          updateInfo: updateInfo!,
          exceptionLogService: exceptionLogService,
          showMessage: showMessage,
        ),
      ),
    );
    return;
  }
  if (alreadyLatest) {
    await _showAlreadyLatestDialog(context: context, version: version);
    return;
  }
  await showMessage(errorMessage ?? '检查更新失败');
}

Future<void> _showAlreadyLatestDialog({
  required BuildContext context,
  required String version,
}) async {
  if (!context.mounted) return;
  final shaShort = BuildInfo.gitShaShort.trim();
  final showSha = shaShort.isNotEmpty && shaShort != 'unknown';
  final lines = <String>[
    '当前已是最新版本，无需下载安装。',
    '',
    '版本：$version',
    if (showSha) '构建：$shaShort',
  ];
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('已是最新版本'),
      content: Text('\n${lines.join('\n')}'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

bool _isAlreadyLatest(AppUpdateInfo info) {
  final currentSha = BuildInfo.gitSha.trim().toLowerCase();
  if (currentSha.isEmpty || currentSha == 'unknown') return false;
  final remoteSha = _extractRemoteSha(info)?.toLowerCase();
  if (remoteSha == null || remoteSha.isEmpty) return false;
  final shorter = currentSha.length < remoteSha.length
      ? currentSha.length
      : remoteSha.length;
  if (shorter < 7) return false;
  return currentSha.substring(0, shorter) == remoteSha.substring(0, shorter);
}

String? _extractRemoteSha(AppUpdateInfo info) {
  final shaPattern = RegExp(r'\b([0-9a-fA-F]{7,40})\b');
  final bodyMatch = shaPattern.firstMatch(info.updateBody);
  if (bodyMatch != null) return bodyMatch.group(1);
  return _extractShaFromFileName(info.fileName);
}

/// 把 GitHub Action `latest` 接口的响应解析成 [AppUpdateInfo]。
AppUpdateInfo? parseAppUpdateInfo(dynamic rawData) {
  Map<String, dynamic>? map;
  if (rawData is Map) {
    map = rawData.map((key, value) => MapEntry(key.toString(), value));
  } else if (rawData is String) {
    final rawText = rawData.trim();
    if (rawText.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is Map) {
        map = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
  }
  if (map == null) return null;

  final tagName = _firstNonEmpty([
        _readString(map, 'tag'),
        _readString(map, 'tagName'),
        _readString(map, 'version'),
      ]) ??
      'nightly';
  final name = _readString(map, 'name') ?? 'Nightly Build';
  final publishedAtText = _formatPublishedAt(_readString(map, 'publishedAt'));
  final downloadUrl = _firstNonEmpty([
        _readString(map, 'downloadUrl'),
        _readString(map, 'apkUrl'),
        _readString(map, 'url'),
        _readString(map, 'browser_download_url'),
      ]) ??
      '';
  final fileName = _firstNonEmpty([
        _readString(map, 'fileName'),
        _readString(map, 'name'),
      ]) ??
      _fallbackApkName(tagName);
  final remoteShaPrefix = _extractShaFromFileName(fileName) ??
      _firstNonEmpty([
        _readString(map, 'commit'),
        _readString(map, 'sha'),
        _readString(map, 'commitSha'),
      ]);
  final updateBody = _firstNonEmpty([
        _readString(map, 'updateLog'),
        _readString(map, 'body'),
        _readString(map, 'note'),
        _readString(map, 'description'),
        _readString(map, 'info'),
      ]) ??
      _buildFallbackBody(
        name: name,
        tagName: tagName,
        fileName: fileName,
        publishedAtText: publishedAtText,
        remoteSha: remoteShaPrefix,
        downloadUrl: downloadUrl,
      );
  return AppUpdateInfo(
    tagName: tagName,
    updateBody: updateBody,
    downloadUrl: downloadUrl,
    fileName: fileName,
  );
}

String _buildFallbackBody({
  required String name,
  required String tagName,
  required String fileName,
  required String? publishedAtText,
  required String? remoteSha,
  required String downloadUrl,
}) {
  final lines = <String>[];
  if (name.isNotEmpty) lines.add(name);
  if (tagName.isNotEmpty) lines.add('Tag：$tagName');
  if (fileName.isNotEmpty) lines.add('文件：$fileName');
  if (remoteSha != null && remoteSha.isNotEmpty) {
    final shortSha =
        remoteSha.length >= 7 ? remoteSha.substring(0, 7) : remoteSha;
    lines.add('Commit：$shortSha');
  }
  if (publishedAtText != null && publishedAtText.isNotEmpty) {
    lines.add('发布时间：$publishedAtText');
  }
  if (downloadUrl.isNotEmpty) {
    lines.add('');
    lines.add('下载地址：');
    lines.add(downloadUrl);
  }
  return lines.join('\n');
}

String? _extractShaFromFileName(String fileName) {
  final match = RegExp(r'-([0-9a-fA-F]{7,40})\.ipa$', caseSensitive: false)
      .firstMatch(fileName);
  return match?.group(1);
}

String? _readString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

String? _formatPublishedAt(String? publishedAt) {
  final text = publishedAt?.trim() ?? '';
  if (text.isEmpty) return null;
  try {
    final date = DateTime.parse(text).toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return text;
  }
}

String _fallbackApkName(String tagName) {
  final normalized = tagName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return 'soupreader_$normalized.apk';
}

/// 把任意错误转成简短文本（最多 120 字符 + 省略号）。
String summarizeError(Object error) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) return 'HTTP $statusCode';
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;
  }
  final text = error.toString().trim();
  if (text.isEmpty) return '未知错误';
  if (text.length <= 120) return text;
  return '${text.substring(0, 120)}...';
}

/// 处理「巨魔安装 / 浏览器下载」按钮点击。
Future<void> handleAppUpdateDownload({
  required BuildContext context,
  required AppUpdateInfo updateInfo,
  required ExceptionLogService exceptionLogService,
  required Future<void> Function(String message) showMessage,
}) async {
  final downloadUrl = updateInfo.downloadUrl.trim();
  final fileName = updateInfo.fileName.trim();
  if (downloadUrl.isEmpty || fileName.isEmpty) return;

  final uri = Uri.tryParse(downloadUrl);
  if (uri == null) {
    exceptionLogService.record(
      node: 'app_update.menu_download',
      message: '更新下载链接无效',
      context: {'downloadUrl': downloadUrl, 'fileName': fileName},
    );
    await showMessage('下载启动失败');
    return;
  }

  if (await _launchTrollStoreInstall(
    exceptionLogService: exceptionLogService,
    ipaUrl: downloadUrl,
    fileName: fileName,
  )) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop();
    showAppToast(context, message: '已交给巨魔下载安装');
    return;
  }

  try {
    final started = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!started) {
      exceptionLogService.record(
        node: 'app_update.menu_download',
        message: '更新下载未能启动',
        context: {'downloadUrl': downloadUrl, 'fileName': fileName},
      );
      await showMessage('未检测到巨魔，且浏览器下载也启动失败');
      return;
    }
    if (!context.mounted) return;
    await showMessage('未检测到巨魔，已用浏览器打开下载链接');
  } catch (error, stackTrace) {
    exceptionLogService.record(
      node: 'app_update.menu_download',
      message: '更新下载触发失败',
      error: error,
      stackTrace: stackTrace,
      context: {'downloadUrl': downloadUrl, 'fileName': fileName},
    );
    if (!context.mounted) return;
    await showMessage('下载启动失败');
  }
}

/// 优先尝试唤起巨魔（TrollStore）直接下载并安装 IPA。
///
/// TrollStore 注册了 `apple-magnifier://install?url=<ipa-url>` URL Scheme，
/// 由其自身完成下载与安装，无需我们写入沙盒。注意需要在 TrollStore
/// 设置中开启 “URL Scheme”（默认关闭，未开启时此 scheme 会被系统
/// 放大镜抢走）。
Future<bool> _launchTrollStoreInstall({
  required ExceptionLogService exceptionLogService,
  required String ipaUrl,
  required String fileName,
}) async {
  final encoded = Uri.encodeComponent(ipaUrl);
  final candidates = <Uri>[
    Uri.parse('apple-magnifier://install?url=$encoded'),
    Uri.parse('tsinstall://install?url=$encoded'),
  ];
  for (final uri in candidates) {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (error, stackTrace) {
      exceptionLogService.record(
        node: 'app_update.trollstore_launch',
        message: '巨魔安装跳转失败',
        error: error,
        stackTrace: stackTrace,
        context: {'scheme': uri.scheme, 'fileName': fileName},
      );
    }
  }
  return false;
}
